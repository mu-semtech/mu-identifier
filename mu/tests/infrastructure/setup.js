import { before } from 'mocha';

const MAX_WAIT_MS = 30_000;

async function waitFor(url, label) {
  const deadline = Date.now() + MAX_WAIT_MS;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(1000) });
      if (res.ok) return;
    } catch {
      // not yet up
    }
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error(`Timed out waiting for ${label} to start`);
}

before(async function waitForServices() {
  this.timeout(MAX_WAIT_MS * 2 + 5_000);
  await waitFor('http://dispatcher/', 'dispatcher');
  await waitFor('http://identifier/', 'identifier');
});
