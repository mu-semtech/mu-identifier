import { before, afterEach } from 'mocha';
import { createConnection } from 'net';
import { ready, backend } from './mock-backend.js';

await ready;

const MAX_WAIT_MS = 30_000;

function identifierAcceptsConnections() {
  return new Promise((resolve) => {
    const socket = createConnection({ host: 'identifier', port: 80 });
    socket.on('connect', () => { socket.destroy(); resolve(true); });
    socket.on('error', () => resolve(false));
    socket.setTimeout(1000, () => { socket.destroy(); resolve(false); });
  });
}

before(async function waitForIdentifier() {
  if (process.env.SKIP_IDENTIFIER_WAIT) return;
  this.timeout(MAX_WAIT_MS + 5_000);
  const deadline = Date.now() + MAX_WAIT_MS;
  while (Date.now() < deadline) {
    if (await identifierAcceptsConnections()) return;
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error('Timed out waiting for identifier to start');
});

afterEach(() => {
  backend.reset();
});
