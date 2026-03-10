import { request, assertStatus } from '../helpers.js';

const PAST_TIMESTAMP = '1000';

describe('Session max age (unauthorized strategy)', () => {
  it('returns 401 when the session max age is exceeded', async () => {
    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    assertStatus(r1, 200);
    const cookie = r1.headers.get('set-cookie').split(';')[0];

    const r2 = await request('/test', { headers: { cookie } });
    assertStatus(r2, 401);
  });

  it('continues to return 401 on repeated requests with the same expired session', async () => {
    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    const cookie = r1.headers.get('set-cookie').split(';')[0];

    await request('/test', { headers: { cookie } }); // first 401
    const r3 = await request('/test', { headers: { cookie } });
    assertStatus(r3, 401);
  });
});
