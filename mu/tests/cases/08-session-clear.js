import assert from 'assert';
import { request, assertStatus } from '../helpers.js';

const PAST_TIMESTAMP = '1000';

describe('Client-enforced session clearing', () => {
  it('issues a new session id when Mu-Session-Clear is sent', async () => {
    const r1 = await request('/test');
    assertStatus(r1, 200);
    const cookie = r1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = r1.headers.get('x-received-mu-session-id');

    const r2 = await request('/test', {
      headers: { cookie, 'mu-session-clear': 'true' }
    });
    assertStatus(r2, 200);
    assert.notEqual(r2.headers.get('x-received-mu-session-id'), firstSessionId);
  });

  it('allows recovery from a 401 by sending Mu-Session-Clear', async () => {
    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    assertStatus(r1, 200);
    const cookie = r1.headers.get('set-cookie').split(';')[0];

    const r2 = await request('/test', { headers: { cookie } });
    assertStatus(r2, 401);

    const r3 = await request('/test', {
      headers: { cookie, 'mu-session-clear': 'true' }
    });
    assertStatus(r3, 200);
  });
});
