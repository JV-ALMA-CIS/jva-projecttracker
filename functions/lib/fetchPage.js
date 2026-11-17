const https = require("node:https");
const http = require("node:http");

/**
 * Minimal fetch-like GET for web pages, built on node:https so the
 * response-header size limit can be raised. Some sites (e.g.
 * ke.usembassy.gov post pages) send headers larger than Node's built-in
 * fetch accepts (UND_ERR_HEADERS_OVERFLOW). Follows up to 5 redirects.
 * Returns `{ ok, status, url, text: async () => string }` — the subset of
 * the fetch Response API the page watchers use.
 */
function fetchPage(url, { headers = {}, timeoutMs = 20000, maxRedirects = 5 } = {}) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith("https:") ? https : http;
    const req = lib.get(url, { headers, maxHeaderSize: 256 * 1024, timeout: timeoutMs }, (res) => {
      const { statusCode = 0 } = res;
      if (statusCode >= 300 && statusCode < 400 && res.headers.location) {
        res.resume();
        if (maxRedirects <= 0) return reject(new Error("too many redirects"));
        const next = new URL(res.headers.location, url).toString();
        return resolve(fetchPage(next, { headers, timeoutMs, maxRedirects: maxRedirects - 1 }));
      }
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        const body = Buffer.concat(chunks).toString("utf8");
        resolve({ ok: statusCode >= 200 && statusCode < 300, status: statusCode, url, text: async () => body });
      });
      res.on("error", reject);
    });
    req.on("timeout", () => req.destroy(new Error("timeout")));
    req.on("error", reject);
  });
}

/** Adapter matching `fetchImpl(url, { headers })` as used by the watchers. */
const fetchPageImpl = (url, options = {}) => fetchPage(url, { headers: options.headers || {} });

module.exports = { fetchPage, fetchPageImpl };
