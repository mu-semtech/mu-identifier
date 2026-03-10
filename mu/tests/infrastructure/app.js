import { app } from 'mu';

app.all('/*', (req, res) => {
  for (const [key, value] of Object.entries(req.headers)) {
    if (key.startsWith('mu-')) {
      res.set('x-received-' + key, value);
    }
  }
  for (const [key, value] of Object.entries(req.headers)) {
    if (key.startsWith('x-test-response-')) {
      res.set(key.slice('x-test-response-'.length), value);
    }
  }
  const status = parseInt(req.headers['x-test-status'] || '200');
  res.status(status).json({ ok: true });
});
