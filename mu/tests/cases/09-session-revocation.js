// These tests are driven by the run-tests.sh script, which:
//   1. Creates sessions via HTTP (capturing cookies and session IDs)
//   2. Calls mu-cli revocation from the host
//   3. Re-runs this file with the relevant env vars set
//
// If those env vars are absent the tests are skipped.

import assert from 'assert';
import { request, assertStatus, assertNoHeader } from '../helpers.js';

const CLEAR_GROUPS_COOKIE = process.env.CLEAR_GROUPS_COOKIE;
const CLEAR_SESSION_COOKIE = process.env.CLEAR_SESSION_COOKIE;
const CLEAR_SESSION_ID = process.env.CLEAR_SESSION_ID;
const REVOKED_GROUPS_COOKIE = process.env.REVOKED_GROUPS_COOKIE;

describe('Session revocation', function() {
  describe('revoke session URI with clear_allowed_groups', function() {
    before(function() {
      if (!CLEAR_GROUPS_COOKIE) this.skip();
    });

    it('clears cached allowed groups on the next request', async () => {
      const res = await request('/test', { headers: { cookie: CLEAR_GROUPS_COOKIE } });
      assertStatus(res, 200);
      assertNoHeader(res, 'x-received-mu-auth-allowed-groups');
    });
  });

  describe('revoke session URI with clear_session', function() {
    before(function() {
      if (!CLEAR_SESSION_COOKIE || !CLEAR_SESSION_ID) this.skip();
    });

    it('issues a new session id and forwards the cleared one to the backend', async () => {
      const res = await request('/test', { headers: { cookie: CLEAR_SESSION_COOKIE } });
      assertStatus(res, 200);
      assert.notEqual(res.headers.get('x-received-mu-session-id'), CLEAR_SESSION_ID);
      assert.equal(res.headers.get('x-received-cleared-mu-session-id'), CLEAR_SESSION_ID);
    });
  });

  describe('revoke allowed-groups string', function() {
    before(function() {
      if (!REVOKED_GROUPS_COOKIE) this.skip();
    });

    it('clears cached groups for any session holding the revoked groups string', async () => {
      const res = await request('/test', { headers: { cookie: REVOKED_GROUPS_COOKIE } });
      assertStatus(res, 200);
      assertNoHeader(res, 'x-received-mu-auth-allowed-groups');
    });
  });
});
