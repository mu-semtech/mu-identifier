import { request, assertStatus, assertHeaderEquals } from '../helpers.js';

describe('CORS headers', () => {
  it('adds Access-Control-Allow-Origin from the environment variable', async () => {
    const res = await request('/test');
    assertStatus(res, 200);
    assertHeaderEquals(res, 'access-control-allow-origin', '*');
  });

  it('does not override Access-Control-Allow-Origin when the backend sets it', async () => {
    const res = await request('/test', {
      headers: { 'x-test-response-access-control-allow-origin': 'https://example.com' }
    });
    assertStatus(res, 200);
    assertHeaderEquals(res, 'access-control-allow-origin', 'https://example.com');
  });
});
