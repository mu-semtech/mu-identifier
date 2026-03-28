import assert from 'assert';
import { request, assertStatus, assertNoHeader } from '../helpers.js';
import { backend } from '../mock-backend.js';

describe('Invalid session cookie (unauthorized strategy)', () => {
  it('returns 401 when the session cookie cannot be decrypted', async () => {
    const response = await request('/test', {
      headers: { cookie: 'proxy_session=invalid-garbage' }
    });
    assertStatus(response, 401);
  });

  it('returns 200 when no session cookie is present', async () => {
    const response = await request('/test');
    assertStatus(response, 200);
  });

  it('sends mu-auth-unauthorized to the backend when the session cookie is invalid', async () => {
    const hit = backend.expect((req) => {
      assert.equal(req.headers['mu-auth-unauthorized'], 'true');
    });
    await request('/test', { headers: { cookie: 'proxy_session=invalid-garbage' } });
    hit.verify();
  });

  it('does not forward a mu-session-id to the backend when the session cookie is invalid', async () => {
    const response = await request('/test', {
      headers: { cookie: 'proxy_session=invalid-garbage' }
    });
    assertNoHeader(response, 'x-received-mu-session-id');
  });
});
