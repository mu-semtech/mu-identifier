import assert from 'assert';
import { request, assertStatus, assertHeaderEquals, assertNoHeader, parseCookie } from '../helpers.js';

const CUSTOM_SESSION_ID = 'http://mu.semte.ch/sessions/custom-test-session';
const CUSTOM_ALLOWED_GROUPS = '[{"name":"admin","variables":[]}]';

describe('Custom session reader', () => {
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

  it('returns 200 despite a bad JWT when the custom header is present', async () => {
    const response = await request('/test', {
      headers: {
        'x-custom-session-id': CUSTOM_SESSION_ID,
        authorization: 'Bearer bad-token'
      }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-received-mu-session-id', CUSTOM_SESSION_ID);
  });

  it('overrides an existing cookie session with the custom session ID', async () => {
    const cookieResponse = await request('/test');
    assertStatus(cookieResponse, 200);
    const cookie = parseCookie(cookieResponse);
    const cookieSessionId = cookieResponse.headers.get('x-received-mu-session-id');
    assert.ok(cookie, 'expected a session cookie from first request');

    const response = await request('/test', {
      headers: {
        'x-custom-session-id': CUSTOM_SESSION_ID,
        cookie
      }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-received-mu-session-id', CUSTOM_SESSION_ID);
    assert.notEqual(response.headers.get('x-received-mu-session-id'), cookieSessionId,
      'expected the custom session ID to replace the cookie session ID');
  });
});

describe('Custom session writer', () => {
  it('echoes the session ID in a custom response header', async () => {
    const response = await request('/test', {
      headers: { 'x-custom-session-id': CUSTOM_SESSION_ID }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-custom-session-id-echo', CUSTOM_SESSION_ID);
  });

  it('echoes the allowed groups in a custom response header', async () => {
    const response = await request('/test', {
      headers: {
        'x-custom-session-id': CUSTOM_SESSION_ID,
        'x-custom-allowed-groups': CUSTOM_ALLOWED_GROUPS
      }
    });
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-custom-allowed-groups-echo', CUSTOM_ALLOWED_GROUPS);
  });

  it('does not echo when no custom session header is sent', async () => {
    const response = await request('/test');
    assertStatus(response, 200);
    assertNoHeader(response, 'x-custom-session-id-echo');
    assertNoHeader(response, 'x-custom-allowed-groups-echo');
  });
});
