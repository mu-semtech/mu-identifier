import assert from 'assert';
import { request, assertStatus, parseCookie } from '../helpers.js';

describe('Invalid session cookie (clear_mu_session_id strategy)', () => {
  it('returns 200 and issues a new session when the cookie cannot be decrypted', async () => {
    const response = await request('/test', {
      headers: { cookie: 'proxy_session=invalid-garbage' }
    });
    assertStatus(response, 200);
    assert.ok(parseCookie(response), 'expected a new session cookie to be set');
  });

  it('the new session can be used on subsequent requests', async () => {
    const response1 = await request('/test', {
      headers: { cookie: 'proxy_session=invalid-garbage' }
    });
    assertStatus(response1, 200);
    const cookie = parseCookie(response1);
    const firstSessionId = response1.headers.get('x-received-mu-session-id');

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 200);
    assert.equal(response2.headers.get('x-received-mu-session-id'), firstSessionId);
  });

  it('returns 200 when no session cookie is present', async () => {
    const response = await request('/test');
    assertStatus(response, 200);
  });
});
