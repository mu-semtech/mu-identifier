import assert from 'assert';
import { request, assertStatus } from '../helpers.js';

const PAST_TIMESTAMP = '1000';

describe('Client-enforced session clearing', () => {
  it('issues a new session id when Mu-Session-Clear is sent', async () => {
    const response1 = await request('/test');
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = response1.headers.get('x-received-mu-session-id');

    const response2 = await request('/test', {
      headers: { cookie, 'mu-session-clear': 'true' }
    });
    assertStatus(response2, 200);
    assert.notEqual(response2.headers.get('x-received-mu-session-id'), firstSessionId);
  });

  it('allows recovery from a 401 by sending Mu-Session-Clear', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 401);

    const response3 = await request('/test', {
      headers: { cookie, 'mu-session-clear': 'true' }
    });
    assertStatus(response3, 200);
  });
});
