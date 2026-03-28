import assert from 'assert';
import { request, assertStatus, parseCookie } from '../helpers.js';

describe('Invalid JWT (clear_session strategy)', () => {
  it('returns 200 and issues a new session when the JWT is invalid', async () => {
    const response = await request('/test', {
      headers: { authorization: 'Bearer bad-token' }
    });
    assertStatus(response, 200);
    assert.ok(parseCookie(response), 'expected a session cookie to be set');
  });

  it('the new session can be used on subsequent requests', async () => {
    const response1 = await request('/test', {
      headers: { authorization: 'Bearer bad-token' }
    });
    assertStatus(response1, 200);
    const cookie = parseCookie(response1);
    const firstSessionId = response1.headers.get('x-received-mu-session-id');

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 200);
    assert.equal(response2.headers.get('x-received-mu-session-id'), firstSessionId);
  });

  it('returns 200 when no Authorization header is present', async () => {
    const response = await request('/test');
    assertStatus(response, 200);
  });
});
