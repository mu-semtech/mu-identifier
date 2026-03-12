import { ready } from './mock-backend.js';

await ready;

const groups = process.env.GROUPS;
const headers = {};
if (groups) {
  headers['x-test-response-mu-auth-allowed-groups'] = groups;
}

const deadline = Date.now() + 30_000;
let r;
while (Date.now() < deadline) {
  try {
    r = await fetch('http://identifier/test', { headers, signal: AbortSignal.timeout(2000) });
    break;
  } catch {
    await new Promise(res => setTimeout(res, 500));
  }
}
if (!r) { process.stderr.write('Timed out waiting for identifier\n'); process.exit(1); }

const cookie = r.headers.get('set-cookie').split(';')[0];
const sessionId = r.headers.get('x-received-mu-session-id') || '';

process.stdout.write(cookie + '\n' + sessionId + '\n');
process.exit(0);
