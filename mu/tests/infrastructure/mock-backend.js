import { createServer } from 'http';

function defaultHandler(req, res) {
  const headers = { 'content-type': 'application/json' };
  for (const [k, v] of Object.entries(req.headers)) {
    if (k.startsWith('mu-') || k.startsWith('previous-mu-')) headers['x-received-' + k] = v;
  }
  for (const [k, v] of Object.entries(req.headers)) {
    if (k.startsWith('x-test-response-')) headers[k.slice('x-test-response-'.length)] = v;
  }
  const isUnauthorized = req.headers['mu-auth-unauthorized'] === 'true';
  const status = isUnauthorized ? 401 : parseInt(req.headers['x-test-status'] || '200');
  res.writeHead(status, headers);
  res.end(JSON.stringify({ ok: true }));
}

let currentHandler = null;

const server = createServer(async (req, res) => {
  const handler = currentHandler ?? defaultHandler;
  currentHandler = null;
  try {
    await handler(req, res);
    if (!res.headersSent) defaultHandler(req, res);
  } catch (e) {
    if (!res.headersSent) { res.writeHead(500); res.end(e.message); }
  }
});

export const ready = new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(80, resolve);
});

export const backend = {
  expect(fn) {
    let called = false;
    let handlerError = null;

    currentHandler = async (req, res) => {
      called = true;
      try {
        await fn(req, res);
      } catch (e) {
        handlerError = e;
        if (!res.headersSent) { res.writeHead(500); res.end(e.message); }
      }
    };

    return {
      verify() {
        if (!called) throw new Error('Expected mock backend to be called but it was not');
        if (handlerError) throw handlerError;
      }
    };
  },

  reset() {
    currentHandler = null;
  }
};
