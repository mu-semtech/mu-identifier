import assert from 'assert';
import { request, assertStatus, assertHasHeader } from '../helpers.js';

describe('Session identification', () => {
  it('forwards mu-session-id to the backend on every request', async () => {
    const res = await request('/test');
    assertStatus(res, 200);
    assertHasHeader(res, 'x-received-mu-session-id');
  });

  it('session id is a URI', async () => {
    const res = await request('/test');
    const sessionId = res.headers.get('x-received-mu-session-id');
    assert.ok(sessionId.startsWith('http'), `expected URI, got: ${sessionId}`);
  });

  it('reuses the same session on subsequent requests', async () => {
    const r1 = await request('/test');
    assertStatus(r1, 200);
    const cookie = r1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = r1.headers.get('x-received-mu-session-id');

    const r2 = await request('/test', { headers: { cookie } });
    assertStatus(r2, 200);
    assert.equal(r2.headers.get('x-received-mu-session-id'), firstSessionId);
  });

  it('assigns a different session to a different client', async () => {
    const r1 = await request('/test');
    const r2 = await request('/test');
    assert.notEqual(
      r1.headers.get('x-received-mu-session-id'),
      r2.headers.get('x-received-mu-session-id')
    );
  });
});
