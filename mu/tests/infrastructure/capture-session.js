const groups = process.env.GROUPS;

const headers = {};
if (groups) {
  headers['x-test-response-mu-auth-allowed-groups'] = groups;
}

const r = await fetch('http://identifier/test', { headers });
const cookie = r.headers.get('set-cookie').split(';')[0];
const sessionId = r.headers.get('x-received-mu-session-id') || '';

process.stdout.write(cookie + '\n' + sessionId + '\n');
