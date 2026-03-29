import assert from 'assert';
import { request, assertStatus, assertHasHeader } from '../helpers.js';

const PAST_TIMESTAMP = '1000';
const FUTURE_TIMESTAMP = String(Math.floor(Date.now() / 1000) + 3600);

describe('Session max age (clear_session strategy)', () => {
  it('includes Mu-Session-Max-Expires-In when a session valid-until is set', async () => {
    const response = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': FUTURE_TIMESTAMP }
    });
    assertStatus(response, 200);
    assertHasHeader(response, 'mu-session-max-expires-in');
  });

  it('starts a fresh session when the max age is exceeded', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = response1.headers.get('x-received-mu-session-id');

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 200);
    assert.notEqual(response2.headers.get('x-received-mu-session-id'), firstSessionId);
  });

  it('forwards the previous session id to the backend after a session reset', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-valid-until': PAST_TIMESTAMP }
    });
    const cookie = response1.headers.get('set-cookie').split(';')[0];
    const firstSessionId = response1.headers.get('x-received-mu-session-id');

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 200);
    assert.equal(response2.headers.get('x-received-previous-mu-session-id'), firstSessionId);
  });
});
