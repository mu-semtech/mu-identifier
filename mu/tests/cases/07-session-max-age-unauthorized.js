import { request, assertStatus } from '../helpers.js';

const PAST_TIMESTAMP = '1000';

describe('Session max age (unauthorized strategy)', () => {
  it('returns 401 when the session max age is exceeded', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 401);
  });

  it('continues to return 401 on repeated requests with the same expired session', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    const cookie = response1.headers.get('set-cookie').split(';')[0];

    await request('/test', { headers: { cookie } }); // first 401
    const response3 = await request('/test', { headers: { cookie } });
    assertStatus(response3, 401);
  });
});
