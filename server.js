const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

const METADATA_BASE = 'http://169.254.169.254/latest';
const TIMEOUT_MS = 1000;

function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  return fetch(url, { ...options, signal: controller.signal }).finally(() => clearTimeout(timer));
}

async function getInstanceMetadata() {
  const fallback = {
    instanceId: 'N/A (not running on EC2)',
    instanceType: 'N/A',
    availabilityZone: 'N/A',
    privateIp: 'N/A',
    publicIp: 'N/A',
    hostname: 'N/A',
  };

  try {
    const tokenRes = await fetchWithTimeout(`${METADATA_BASE}/api/token`, {
      method: 'PUT',
      headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '21600' },
    });
    if (!tokenRes.ok) return fallback;
    const token = await tokenRes.text();
    const headers = { 'X-aws-ec2-metadata-token': token };

    const paths = {
      instanceId: 'meta-data/instance-id',
      instanceType: 'meta-data/instance-type',
      availabilityZone: 'meta-data/placement/availability-zone',
      privateIp: 'meta-data/local-ipv4',
      publicIp: 'meta-data/public-ipv4',
      hostname: 'meta-data/hostname',
    };

    const entries = await Promise.all(
      Object.entries(paths).map(async ([key, p]) => {
        try {
          const r = await fetchWithTimeout(`${METADATA_BASE}/${p}`, { headers });
          return [key, r.ok ? await r.text() : 'N/A'];
        } catch {
          return [key, 'N/A'];
        }
      })
    );

    return Object.fromEntries(entries);
  } catch {
    return fallback;
  }
}

app.use(express.static(path.join(__dirname, 'public')));

// ALB target group health check
app.get('/health', (req, res) => res.status(200).send('OK'));

app.get('/api/info', async (req, res) => {
  const metadata = await getInstanceMetadata();
  res.json({
    ...metadata,
    serverTime: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
