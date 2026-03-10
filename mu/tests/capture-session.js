import { writeFileSync, mkdirSync } from 'fs';
import { dirname } from 'path';

const outputFile = process.env.OUTPUT_FILE || '/tests/.tmp/output.txt';
const groupsFile = process.env.GROUPS_FILE;

const headers = {};
if (groupsFile) {
  const { readFileSync } = await import('fs');
  headers['x-test-response-mu-auth-allowed-groups'] = readFileSync(groupsFile, 'utf8').trim();
}

const r = await fetch('http://identifier/test', { headers });
const cookie = r.headers.get('set-cookie').split(';')[0];
const sessionId = r.headers.get('x-received-mu-session-id') || '';

mkdirSync(dirname(outputFile), { recursive: true });
writeFileSync(outputFile, cookie + '\n' + sessionId + '\n');
