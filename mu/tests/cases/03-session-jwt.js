import assert from 'assert';
import { request, assertStatus, assertHasHeader, assertNoHeader } from '../helpers.js';

describe('JWT session delivery', () => {
  it('issues a Mu-Auth-Token when the backend requests jwt-header delivery mode', async () => {
    const response = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-header' }
    });
    assertStatus(response, 200);
    assertHasHeader(response, 'mu-auth-token');
  });

  it('does not issue a Mu-Auth-Token in cookie mode', async () => {
    const response = await request('/test');
    assertStatus(response, 200);
    assertNoHeader(response, 'mu-auth-token');
  });

  it('carries the session across requests when the client sends the JWT', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-header' }
    });
    assertStatus(response1, 200);
    const token = response1.headers.get('mu-auth-token');
    const firstSessionId = response1.headers.get('x-received-mu-session-id');
    assert.ok(token, 'expected Mu-Auth-Token in first response');

    const response2 = await request('/test', {
      headers: { authorization: `Bearer ${token}` }
    });
    assertStatus(response2, 200);
    assert.equal(response2.headers.get('x-received-mu-session-id'), firstSessionId);
  });
});
