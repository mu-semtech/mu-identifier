import { request, assertStatus, assertHeaderEquals, assertNoHeader } from '../helpers.js';
import { backend } from '../mock-backend.js';

describe('Response headers', () => {
  it('passes custom backend headers through to the client', async () => {
    const hit = backend.expect((_req, res) => {
      res.writeHead(200, {
        'content-type': 'application/json',
        'x-api-version': '2.1',
        'x-powered-by': 'test-backend',
      });
      res.end(JSON.stringify({ ok: true }));
    });
    const response = await request('/test');
    hit.verify();
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-api-version', '2.1');
    assertHeaderEquals(response, 'x-powered-by', 'test-backend');
  });

  it('strips mu-auth-allowed-groups from the response', async () => {
    const hit = backend.expect((_req, res) => {
      res.writeHead(200, {
        'content-type': 'application/json',
        'mu-auth-allowed-groups': '[{"name":"public","variables":[]}]',
      });
      res.end(JSON.stringify({ ok: true }));
    });
    const response = await request('/test');
    hit.verify();
    assertStatus(response, 200);
    assertNoHeader(response, 'mu-auth-allowed-groups');
  });

  it('strips other internal mu-* headers from the response', async () => {
    const hit = backend.expect((_req, res) => {
      res.writeHead(200, {
        'content-type': 'application/json',
        'mu-auth-used-groups': '[{"name":"public","variables":[]}]',
        'mu-auth-scope': 'write',
        'mu-auth-sudo': 'true',
        'mu-session-delivery-mode': ':jwt-header',
        'mu-session-valid-until': String(Date.parse('2099-01-01T00:00:00Z') / 1000),
      });
      res.end(JSON.stringify({ ok: true }));
    });
    const response = await request('/test');
    hit.verify();
    assertStatus(response, 200);
    assertNoHeader(response, 'mu-auth-used-groups');
    assertNoHeader(response, 'mu-auth-scope');
    assertNoHeader(response, 'mu-auth-sudo');
    assertNoHeader(response, 'mu-session-delivery-mode');
    assertNoHeader(response, 'mu-session-valid-until');
  });

  it('prevents the backend from setting cookies directly', async () => {
    const hit = backend.expect((_req, res) => {
      res.writeHead(200, {
        'content-type': 'application/json',
        'set-cookie': 'injected=value; Path=/',
      });
      res.end(JSON.stringify({ ok: true }));
    });
    const response = await request('/test');
    hit.verify();
    assertStatus(response, 200);
    // set-cookie from the backend is stripped; the identifier manages its own session cookie
    const cookies = response.headers.get('set-cookie') ?? '';
    if (cookies.includes('injected=value'))
      throw new Error('backend must not be able to set cookies on the client');
  });
});
