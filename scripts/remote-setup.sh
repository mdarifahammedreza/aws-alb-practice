
#!/usr/bin/env bash
# Runs ON each EC2 instance (invoked by deploy.sh over ssh).
# Installs Node.js + pm2 if missing, pulls the app, and (re)starts it under pm2.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/mdarifahammedreza/aws-alb-practice.git}"
APP_DIR="${APP_DIR:-aws-alb-practice}"
NODE_MAJOR=20

echo "---- apt-get update ----"
sudo apt-get update -y

if ! command -v node >/dev/null 2>&1; then
  echo "---- Installing Node.js ${NODE_MAJOR}.x via NodeSource ----"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "---- Node.js already installed: $(node -v) ----"
fi
echo "node: $(node -v), npm: $(npm -v)"

if ! command -v git >/dev/null 2>&1; then
  sudo apt-get install -y git
fi

if ! command -v pm2 >/dev/null 2>&1; then
  echo "---- Installing pm2 globally ----"
  sudo npm install -g pm2
else
  echo "---- pm2 already installed: $(pm2 -v) ----"
fi

cd "$HOME"
if [[ -d "$APP_DIR/.git" ]]; then
  echo "---- Repo exists, pulling latest main ----"
  cd "$APP_DIR"
  git fetch --all
  git reset --hard origin/main
else
  echo "---- Cloning repo ----"
  git clone "$REPO_URL" "$APP_DIR"
  cd "$APP_DIR"
fi

echo "---- Installing dependencies ----"
npm install --omit=dev

echo "---- Starting/reloading app with pm2 ----"
if [[ -f ecosystem.config.js ]]; then
  pm2 startOrRestart ecosystem.config.js --update-env
else
  pm2 startOrRestart server.js --name alb-demo --update-env
fi

pm2 save

echo "---- Ensuring pm2 resurrects the app on reboot ----"
STARTUP_CMD=$(pm2 startup systemd -u "$USER" --hp "$HOME" 2>/dev/null | tail -n 1)
if [[ "$STARTUP_CMD" == sudo* ]]; then
  eval "$STARTUP_CMD"
fi

echo "---- pm2 status ----"
pm2 status
echo "---- Done on $(hostname) ----"
