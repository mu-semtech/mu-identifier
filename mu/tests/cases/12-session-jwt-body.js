import assert from 'assert';
import { request, assertStatus, assertNoHeader } from '../helpers.js';
import { backend } from '../mock-backend.js';

describe('JWT body session delivery', () => {
  it('returns the JWT as the response body', async () => {
    const response = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-body' }
    });
    assertStatus(response, 200);
    const body = await response.text();
    assert.equal(body.split('.').length, 3, 'expected a JWT (3 dot-separated parts)');
  });

  it('sets Content-Type to application/jwt', async () => {
    const response = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-body' }
    });
    assertStatus(response, 200);
    assert.ok(response.headers.get('content-type').startsWith('application/jwt'), 'expected content-type application/jwt');
    await response.text();
  });

  it('does not emit a Mu-Auth-Token header', async () => {
    const response = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-body' }
    });
    assertStatus(response, 200);
    assertNoHeader(response, 'mu-auth-token');
    await response.text();
  });

  it('works when the backend sends no body', async () => {
    const hit = backend.expect((_req, res) => {
      res.writeHead(200, {
        'content-type': 'application/json',
        'mu-session-delivery-mode': ':jwt-body'
      });
      res.end();
    });
    const response = await request('/test');
    hit.verify();
    assertStatus(response, 200);
    const body = await response.text();
    assert.equal(body.split('.').length, 3, 'expected a JWT (3 dot-separated parts)');
  });

  it('carries the session across requests when the client sends the JWT from the body', async () => {
    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-session-delivery-mode': ':jwt-body' }
    });
    assertStatus(response1, 200);
    const token = await response1.text();
    const firstSessionId = response1.headers.get('x-received-mu-session-id');
    assert.ok(token, 'expected JWT in response body');

    const response2 = await request('/test', {
      headers: { authorization: `Bearer ${token}` }
    });
    assertStatus(response2, 200);
    assert.equal(response2.headers.get('x-received-mu-session-id'), firstSessionId);
  });
});
