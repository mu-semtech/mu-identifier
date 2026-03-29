import assert from 'assert';
import { createConnection } from 'net';

const STARTUP_WAIT_MS = 5_000;

function identifierAcceptsConnections() {
  return new Promise((resolve) => {
    const socket = createConnection({ host: 'identifier', port: 80 });
    socket.on('connect', () => { socket.destroy(); resolve(true); });
    socket.on('error', () => resolve(false));
    socket.setTimeout(1000, () => { socket.destroy(); resolve(false); });
  });
}

describe('invalid configuration', () => {
  before(async function() {
    this.timeout(STARTUP_WAIT_MS + 2_000);
    await new Promise(r => setTimeout(r, STARTUP_WAIT_MS));
  });

  it('refuses to start when INVALID_SESSION_STRATEGY is set to clear_allowed_groups', async () => {
    assert(!await identifierAcceptsConnections(), 'identifier should not accept connections with an invalid configuration');
  });
});
