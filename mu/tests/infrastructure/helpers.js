export async function request(path, opts = {}) {
  return fetch('http://identifier' + path, { redirect: 'manual', ...opts });
}

export function assertStatus(res, expected) {
  if (res.status !== expected)
    throw new Error(`expected status ${expected}, got ${res.status}`);
}

export function assertHasHeader(res, name) {
  if (!res.headers.get(name))
    throw new Error(`expected response header '${name}' to be present`);
}

export function assertHeaderEquals(res, name, value) {
  const actual = res.headers.get(name);
  if (actual !== value)
    throw new Error(`header '${name}': expected '${value}', got '${actual}'`);
}

export function assertNoHeader(res, name) {
  if (res.headers.get(name))
    throw new Error(`expected header '${name}' to be absent, got '${res.headers.get(name)}'`);
}

export function parseCookie(res) {
  const raw = res.headers.get('set-cookie');
  return raw ? raw.split(';')[0] : null;
}
