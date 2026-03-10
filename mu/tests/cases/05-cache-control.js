import { request, assertStatus, assertHeaderEquals, assertNoHeader } from '../helpers.js';

describe('Cache-Control headers', () => {
  it('adds no-cache headers when the backend sends no Cache-Control', async () => {
    const res = await request('/test');
    assertStatus(res, 200);
    assertHeaderEquals(res, 'cache-control', 'no-cache');
    assertHeaderEquals(res, 'pragma', 'no-cache');
    assertHeaderEquals(res, 'expires', '-1');
  });

  it('does not override Cache-Control when the backend sets it', async () => {
    const res = await request('/test', {
      headers: { 'x-test-response-cache-control': 'max-age=3600' }
    });
    assertStatus(res, 200);
    assertHeaderEquals(res, 'cache-control', 'max-age=3600');
  });
});
