import assert from 'assert';
import { request, assertStatus, parseCookie } from '../helpers.js';
import { backend } from '../mock-backend.js';

const PAST_TIMESTAMP = '1000';

describe('Session max age (unauthorized strategy)', () => {
  it('returns 401 when the session max age is exceeded', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    assertStatus(response1, 200);
    const cookie = parseCookie(response1);

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 401);
  });

  it('continues to return 401 on repeated requests with the same expired session', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    const cookie = parseCookie(response1);

    await request('/test', { headers: { cookie } }); // first 401
    const response3 = await request('/test', { headers: { cookie } });
    assertStatus(response3, 401);
  });

  it('sends mu-auth-unauthorized header to the backend on unauthorized request', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    const cookie = parseCookie(response1);

    const hit = backend.expect((req) => {
      assert.equal(req.headers['mu-auth-unauthorized'], 'true');
    });
    const response2 = await request('/test', { headers: { cookie } });
    hit.verify();
    assertStatus(response2, 401);
  });

  it('sends revoked-mu-session-id instead of mu-session-id on unauthorized request', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    const sessionId = response1.headers.get('x-received-mu-session-id');
    const cookie = parseCookie(response1);

    const hit = backend.expect((req) => {
      assert.equal(req.headers['revoked-mu-session-id'], sessionId, 'session id forwarded as revoked');
      assert.ok(!req.headers['mu-session-id'], 'mu-session-id must not be sent when unauthorized');
    });
    await request('/test', { headers: { cookie } });
    hit.verify();
  });

  it('sends revoked-mu-auth-allowed-groups instead of mu-auth-allowed-groups when groups are cached', async () => {
    const groups = '[{"name":"admin","variables":[]}]';
    const response1 = await request('/test', {
      headers: {
        'x-test-response-mu-session-valid-until': PAST_TIMESTAMP,
        'x-test-response-mu-auth-allowed-groups': groups
      }
    });
    const cookie = parseCookie(response1);

    const hit = backend.expect((req) => {
      assert.equal(req.headers['revoked-mu-auth-allowed-groups'], groups);
      assert.ok(!req.headers['mu-auth-allowed-groups'], 'mu-auth-allowed-groups must not be sent when unauthorized');
    });
    await request('/test', { headers: { cookie } });
    hit.verify();
  });
});
