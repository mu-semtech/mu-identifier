const url = process.env.WAIT_URL;
const deadline = Date.now() + 30000;
while (Date.now() < deadline) {
  try {
    const r = await fetch(url, { signal: AbortSignal.timeout(1000) });
    if (r.ok) { process.exit(0); }
  } catch {
    // retry
  }
  await new Promise(r => setTimeout(r, 500));
}
process.stderr.write(`Timed out waiting for ${url}\n`);
process.exit(1);
