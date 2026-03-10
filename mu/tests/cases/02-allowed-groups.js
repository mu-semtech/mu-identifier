import assert from 'assert';
import { request, assertStatus, assertHeaderEquals, assertNoHeader } from '../helpers.js';

const DEFAULT_GROUPS = '[{"name":"public","variables":[]}]';

describe('Allowed groups', () => {
  it('sends the default allowed groups when no groups are cached', async () => {
    const res = await request('/test');
    assertStatus(res, 200);
    assertHeaderEquals(res, 'x-received-mu-auth-allowed-groups', DEFAULT_GROUPS);
  });

  it('caches allowed groups from the backend and forwards them on the next request', async () => {
    const groups = '[{"name":"admin","variables":[]}]';

    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-auth-allowed-groups': groups }
    });
    assertStatus(r1, 200);
    const cookie = r1.headers.get('set-cookie').split(';')[0];

    const r2 = await request('/test', { headers: { cookie } });
    assertStatus(r2, 200);
    assertHeaderEquals(r2, 'x-received-mu-auth-allowed-groups', groups);
  });

  it('clears cached groups when the backend responds with CLEAR', async () => {
    const groups = '[{"name":"admin","variables":[]}]';

    const r1 = await request('/test', {
      headers: { 'x-test-response-mu-auth-allowed-groups': groups }
    });
    const cookie1 = r1.headers.get('set-cookie').split(';')[0];

    const r2 = await request('/test', {
      headers: {
        cookie: cookie1,
        'x-test-response-mu-auth-allowed-groups': 'CLEAR'
      }
    });
    assertStatus(r2, 200);
    const cookie2 = r2.headers.get('set-cookie').split(';')[0];

    // After CLEAR the next request sends no allowed-groups header; the backend recalculates
    const r3 = await request('/test', { headers: { cookie: cookie2 } });
    assertNoHeader(r3, 'x-received-mu-auth-allowed-groups');
  });
});
