import assert from 'assert';
import { request, assertStatus, assertHasHeader, assertNoHeader } from '../helpers.js';

describe('JWT session delivery', () => {
  it('issues a Mu-Auth-Token when the backend requests jwt-header delivery mode', async () => {
    const res = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-header' }
    });
    assertStatus(res, 200);
    assertHasHeader(res, 'mu-auth-token');
  });

  it('does not issue a Mu-Auth-Token in cookie mode', async () => {
    const res = await request('/test');
    assertStatus(res, 200);
    assertNoHeader(res, 'mu-auth-token');
  });

  it('carries the session across requests when the client sends the JWT', async () => {
    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-header' }
    });
    assertStatus(r1, 200);
    const token = r1.headers.get('mu-auth-token');
    const firstSessionId = r1.headers.get('x-received-mu-session-id');
    assert.ok(token, 'expected Mu-Auth-Token in first response');

    const r2 = await request('/test', {
      headers: { authorization: `Bearer ${token}` }
    });
    assertStatus(r2, 200);
    assert.equal(r2.headers.get('x-received-mu-session-id'), firstSessionId);
  });
});
