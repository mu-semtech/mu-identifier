import assert from 'assert';
import { request, assertStatus, assertHasHeader } from '../helpers.js';

const PAST_TIMESTAMP = '1000';
const FUTURE_TIMESTAMP = String(Math.floor(Date.now() / 1000) + 3600);

describe('Session max age (clear_session strategy)', () => {
  it('includes Mu-Session-Expires-In when a session valid-until is set', async () => {
    const res = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': FUTURE_TIMESTAMP }
    });
    assertStatus(res, 200);
    assertHasHeader(res, 'mu-session-expires-in');
  });

  it('starts a fresh session when the max age is exceeded', async () => {
    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    assertStatus(r1, 200);
    const cookie = r1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = r1.headers.get('x-received-mu-session-id');

    const r2 = await request('/test', { headers: { cookie } });
    assertStatus(r2, 200);
    assert.notEqual(r2.headers.get('x-received-mu-session-id'), firstSessionId);
  });

  it('forwards the previous session id to the backend after a session reset', async () => {
    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    const cookie = r1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = r1.headers.get('x-received-mu-session-id');

    const r2 = await request('/test', { headers: { cookie } });
    assertStatus(r2, 200);
    assert.equal(r2.headers.get('x-received-mu-previous-session-id'), firstSessionId);
  });
});
