// Protocol-only example for a per-browser website BFF session.
export class AppQRLogin {
  #session;
  #browserToken;
  constructor({ fetchImpl = fetch, baseURL = 'https://bojian.kelance.cn/api/v1', deviceID, version = '1.0.0', userAgent = '' }) {
    const url = new URL(baseURL);
    if (url.protocol !== 'https:' || url.pathname !== '/api/v1' || url.search || url.hash || url.username || url.password) throw new Error('Invalid API URL');
    if (!/^web:[A-Za-z0-9_-]{16,96}$/.test(deviceID) || !version || version.length > 32) throw new Error('Invalid browser metadata');
    this.fetchImpl = fetchImpl;
    this.baseURL = baseURL;
    this.headers = { 'content-type': 'application/json', 'x-device-id': deviceID, 'x-platform': 'WEB', 'x-app-version': version, ...(userAgent ? { 'user-agent': userAgent } : {}) };
  }
  async #post(path, body) {
    const response = await this.fetchImpl(`${this.baseURL}${path}`, { method: 'POST', headers: this.headers, body: JSON.stringify(body), cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) });
    const envelope = await response.json();
    if (!response.ok || envelope.error) throw Object.assign(new Error(envelope.error?.message || 'Request failed'), { code: envelope.error?.code, status: response.status });
    return envelope.data;
  }
  async create(agreementVersions) {
    this.#session = undefined;
    this.#browserToken = undefined;
    const result = await this.#post('/auth/app-qr-sessions', { agreement_versions: agreementVersions });
    if (!/^[A-Za-z0-9_-]{43}$/.test(result.session_id) || !/^[A-Za-z0-9_-]{43}$/.test(result.browser_token)) throw new Error('Invalid login response');
    this.#session = result.session_id;
    this.#browserToken = result.browser_token;
    return { sessionID: result.session_id, qrContent: result.qr_content, expiresAt: result.expires_at };
  }
  async status() { return this.#action('status'); }
  // Call only after status() returns CONFIRMED; persist tokens in the BFF's own
  // authenticated session, then discard this temporary helper instance.
  async exchange() { return this.#action('exchange'); }
  async #action(action) {
    if (!this.#session || !this.#browserToken) throw new Error('Create a QR session first');
    return this.#post(`/auth/app-qr-sessions/${this.#session}/${action}`, { browser_token: this.#browserToken });
  }
}
