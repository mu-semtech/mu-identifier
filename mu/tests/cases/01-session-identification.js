import assert from 'assert';
import { request, assertStatus } from '../helpers.js';
import { backend } from '../mock-backend.js';

describe('Session identification', () => {
  it('forwards mu-session-id to the backend on every request', async () => {
    const hit = backend.expect((req) => {
      assert.ok(req.headers['mu-session-id'], 'mu-session-id must be forwarded');
    });
    const response = await request('/test');
    hit.verify();
    assertStatus(response, 200);
  });

  it('session id is a URI', async () => {
    const hit = backend.expect((req) => {
      assert.match(req.headers['mu-session-id'], /^http/, `expected URI, got: ${req.headers['mu-session-id']}`);
    });
    await request('/test');
    hit.verify();
  });

  it('reuses the same session on subsequent requests', async () => {
    const response1 = await request('/test');
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = response1.headers.get('x-received-mu-session-id');

    const hit = backend.expect((req) => {
      assert.equal(req.headers['mu-session-id'], firstSessionId, 'session ID must be stable across requests');
    });
    const response2 = await request('/test', { headers: { cookie } });
    hit.verify();
    assertStatus(response2, 200);
  });

  it('assigns a different session to a different client', async () => {
    const response1 = await request('/test');
    const response2 = await request('/test');
    assert.notEqual(
      response1.headers.get('x-received-mu-session-id'),
      response2.headers.get('x-received-mu-session-id')
    );
  });
});
