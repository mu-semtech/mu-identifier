import assert from 'assert';
import { request, assertStatus } from '../helpers.js';
import { backend } from '../mock-backend.js';

const PAST_TIMESTAMP = '1000';
const groups = '[{"name":"admin","variables":[]}]';

describe('Session max age (clear_mu_auth_allowed_groups strategy)', () => {
  it('preserves the session id when the max age is exceeded', async () => {
    const response1 = await request('/test', {
      headers: {
        'x-test-response-mu-auth-allowed-groups': groups,
        'x-test-response-mu-session-valid-until': PAST_TIMESTAMP,
      }
    });
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = response1.headers.get('x-received-mu-session-id');

    const hit = backend.expect((req) => {
      assert.equal(req.headers['mu-session-id'], firstSessionId, 'session id must be preserved after max age');
    });
    await request('/test', { headers: { cookie } });
    hit.verify();
  });

  it('clears cached allowed groups when the max age is exceeded', async () => {
    const response1 = await request('/test', {
      headers: {
        'x-test-response-mu-auth-allowed-groups': groups,
        'x-test-response-mu-session-valid-until': PAST_TIMESTAMP,
      }
    });
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];

    const hit = backend.expect((req) => {
      assert.ok(!req.headers['mu-auth-allowed-groups'], 'cached allowed groups must be cleared after max age');
    });
    await request('/test', { headers: { cookie } });
    hit.verify();
  });
});
