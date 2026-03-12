import assert from 'assert';
import { request, assertStatus, assertHeaderEquals, assertNoHeader } from '../helpers.js';

const DEFAULT_GROUPS = '[{"name":"public","variables":[]}]';

describe('Allowed groups', () => {
  it('sends the default allowed groups when no groups are cached', async () => {
    const response = await request('/test');
    assertStatus(response, 200);
    assertHeaderEquals(response, 'x-received-mu-auth-allowed-groups', DEFAULT_GROUPS);
  });

  it('caches allowed groups from the backend and forwards them on the next request', async () => {
    const groups = '[{"name":"admin","variables":[]}]';

    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-auth-allowed-groups': groups }
    });
    assertStatus(response1, 200);
    const cookie = response1.headers.get('set-cookie').split(';')[0];

    const response2 = await request('/test', { headers: { cookie } });
    assertStatus(response2, 200);
    assertHeaderEquals(response2, 'x-received-mu-auth-allowed-groups', groups);
  });

  it('clears cached groups when the backend responds with CLEAR', async () => {
    const groups = '[{"name":"admin","variables":[]}]';

    const response1 = await request('/test', {
      headers: { 'x-test-response-mu-auth-allowed-groups': groups }
    });
    const cookie1 = response1.headers.get('set-cookie').split(';')[0];

    const response2 = await request('/test', {
      headers: {
        cookie: cookie1,
        'x-test-response-mu-auth-allowed-groups': 'CLEAR'
      }
    });
    assertStatus(response2, 200);
    const cookie2 = response2.headers.get('set-cookie').split(';')[0];

    // After CLEAR the next request sends no allowed-groups header; the backend recalculates
    const response3 = await request('/test', { headers: { cookie: cookie2 } });
    assertNoHeader(response3, 'x-received-mu-auth-allowed-groups');
  });
});
