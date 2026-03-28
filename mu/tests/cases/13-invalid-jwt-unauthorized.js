import assert from 'assert';
import { request, assertStatus, assertNoHeader } from '../helpers.js';
import { backend } from '../mock-backend.js';

describe('Invalid JWT (unauthorized strategy)', () => {
  it('returns 401 when the Authorization header contains an invalid JWT', async () => {
    const response = await request('/test', {
      headers: { authorization: 'Bearer bad-token' }
    });
    assertStatus(response, 401);
  });

  it('returns 200 when no Authorization header is present', async () => {
    const response = await request('/test');
    assertStatus(response, 200);
  });

  it('sends mu-auth-unauthorized to the backend when the JWT is invalid', async () => {
    const hit = backend.expect((req) => {
      assert.equal(req.headers['mu-auth-unauthorized'], 'true');
    });
    await request('/test', { headers: { authorization: 'Bearer bad-token' } });
    hit.verify();
  });

  it('does not forward a mu-session-id to the backend when the JWT is invalid', async () => {
    const response = await request('/test', {
      headers: { authorization: 'Bearer bad-token' }
    });
    assertNoHeader(response, 'x-received-mu-session-id');
  });
});
