import assert from 'assert';
import { request, assertStatus, assertHeaderEquals, assertNoHeader, parseCookie } from '../helpers.js';
import { backend } from '../mock-backend.js';

const CUSTOM_SESSION_ID = 'http://mu.semte.ch/sessions/skip-processors-test-session';
const CUSTOM_ALLOWED_GROUPS = '[{"name":"admin","variables":[]}]';

describe('Custom session reader skipping default readers', () => {
  it('forwards the custom session ID to the backend as mu-session-id', async () => {
    const response = await request('/test', {
      headers: { 'x-custom-session-id': CUSTOM_SESSION_ID }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-received-mu-session-id', CUSTOM_SESSION_ID);
  });

  it('forwards custom allowed groups to the backend as mu-auth-allowed-groups', async () => {
    const response = await request('/test', {
      headers: {
        'x-custom-session-id': CUSTOM_SESSION_ID,
        'x-custom-allowed-groups': CUSTOM_ALLOWED_GROUPS
      }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-received-mu-auth-allowed-groups', CUSTOM_ALLOWED_GROUPS);
  });

  it('skips ReadSessionFromJwt: returns 200 despite a bad JWT when the custom header is present', async () => {
    const response = await request('/test', {
      headers: {
        'x-custom-session-id': CUSTOM_SESSION_ID,
        authorization: 'Bearer bad-token'
      }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-received-mu-session-id', CUSTOM_SESSION_ID);
  });

  it('skips ReadSessionFromJwt: does not send mu-unauthorized to the backend for a bad JWT', async () => {
    const hit = backend.expect((req) => {
      assert.equal(req.headers['mu-unauthorized'], undefined,
        'expected mu-unauthorized to be absent when the custom reader skips JWT reading');
    });
    await request('/test', {
      headers: {
        'x-custom-session-id': CUSTOM_SESSION_ID,
        authorization: 'Bearer bad-token'
      }
    });
    hit.verify();
  });

  it('skips ReadSessionFromCookie: overrides an existing cookie session with the custom session ID', async () => {
    // First request without the custom header: obtains a cookie-backed session id.
    const cookieResponse = await request('/test');
    assertStatus(cookieResponse, 200);
    const cookie = parseCookie(cookieResponse);
    const cookieSessionId = cookieResponse.headers.get('x-received-mu-session-id');
    assert.ok(cookie, 'expected a session cookie from first request');

    // Second request sends both the cookie and the custom header. Because
    // ReadSessionFromCookie is skipped, the cookie's session id must not
    // overwrite the custom session id.
    const response = await request('/test', {
      headers: {
        'x-custom-session-id': CUSTOM_SESSION_ID,
        cookie
      }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-received-mu-session-id', CUSTOM_SESSION_ID);
    assert.notEqual(response.headers.get('x-received-mu-session-id'), cookieSessionId,
      'expected the custom session ID to take precedence over the cookie session ID');
  });

  it('does not skip the default readers when the custom header is absent', async () => {
    // Sanity check: without the custom header the default readers run as normal,
    // so a bad JWT still triggers the unauthorized strategy (default) -> 401.
    const response = await request('/test', {
      headers: { authorization: 'Bearer bad-token' }
    });
    assertStatus(response, 401);
  });
});
