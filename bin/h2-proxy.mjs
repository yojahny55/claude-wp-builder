#!/usr/bin/env node
/**
 * h2-proxy.mjs: a local HTTP/2 + TLS proxy with brotli/gzip in front of a plain-HTTP local
 * site, so Lighthouse measures a clone under conditions that resemble production.
 *
 * A local Apache or nginx that serves HTTP/1.1 with no compression makes "Modern HTTP",
 * "Minify", "Enable text compression" and most render-blocking findings environment artifacts,
 * and doubles the simulated LCP. This proxy changes only the serving layer: it does not touch
 * the web server or WordPress.
 *
 *   node bin/h2-proxy.mjs --target http://example.local [--port 8443] [--no-cache]
 *     -> https://example.local:8443/
 *
 *   --target URL   plain-HTTP origin to front (required). Its host name must resolve locally
 *                  (an /etc/hosts line); the Host header sent upstream is that name.
 *   --upstream H:P where to connect when it is not the target host on the target's port
 *                  (default: the target host, port 80 or the one in --target)
 *   --port N       HTTPS listen port (default 8443)
 *   --no-cache     do not cache HTML. By default anonymous GET HTML (no WordPress login or
 *                  cart cookie) is cached in memory, like a page cache/CDN would serve it.
 *   GET /__purge   empties that cache
 *
 * The certificate is self-signed and generated at runtime with `openssl` into a temp dir;
 * nothing is committed or kept. Or pass --cert/--key (PEM) to use your own.
 * Lighthouse: --chrome-flags="--headless=new --ignore-certificate-errors"
 * Stop it with `kill <pid>` (not `pkill -f`, which also matches the shell that launched it).
 * Brotli/gzip applies to text responses only; images pass through untouched.
 */
import http2 from 'node:http2';
import http from 'node:http';
import zlib from 'node:zlib';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf('--' + n); return i < 0 ? d : argv[i + 1]; };
const target = opt('target');
if (!target) { console.error('usage: h2-proxy.mjs --target http://host [--port 8443] [--no-cache] [--upstream host:port] [--cert f --key f]'); process.exit(2); }
const t = new URL(target);
if (t.protocol !== 'http:') { console.error('--target must be a plain http:// origin'); process.exit(2); }
const HOST = t.hostname;
const PORT = Number(opt('port', 8443));
const [UP_HOST, UP_PORT] = opt('upstream') ? opt('upstream').split(':') : [HOST, t.port || '80'];
const FROM = `http://${HOST}${t.port ? ':' + t.port : ''}`;
const TO = `https://${HOST}:${PORT}`;
const useCache = !argv.includes('--no-cache');

let cert = opt('cert'), key = opt('key');
if (!cert || !key) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'h2-proxy-'));
    cert = path.join(dir, 'cert.pem'); key = path.join(dir, 'key.pem');
    try {
        execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2', '-keyout', key, '-out', cert,
            '-subj', `/CN=${HOST}`, '-addext', `subjectAltName=DNS:${HOST}`], { stdio: 'ignore' });
    } catch { console.error('openssl is needed to generate the throwaway certificate (or pass --cert and --key)'); process.exit(1); }
    process.on('exit', () => fs.rmSync(dir, { recursive: true, force: true }));
    for (const s of ['SIGINT', 'SIGTERM']) process.on(s, () => process.exit(0));
}

const cache = new Map();
const text = /text\/|javascript|json|xml|svg/;
const esc = (s) => s.replace(/\//g, '\\/');
const rewrite = (s) => s.split(FROM).join(TO).split(esc(FROM)).join(esc(TO));

function upstream(req, body) {
    return new Promise((resolve, reject) => {
        const headers = {};
        for (const [k, v] of Object.entries(req.headers)) {
            if (!k.startsWith(':') && !['connection', 'accept-encoding', 'host'].includes(k)) headers[k] = v;
        }
        headers.host = t.host;
        headers['accept-encoding'] = 'identity';
        const r = http.request({ host: UP_HOST, port: UP_PORT, method: req.method, path: req.url, headers }, (res) => {
            const chunks = [];
            res.on('data', (c) => chunks.push(c));
            res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
        });
        r.on('error', reject);
        r.end(body);
    });
}

const server = http2.createSecureServer({ key: fs.readFileSync(key), cert: fs.readFileSync(cert), allowHTTP1: true }, async (req, res) => {
    if (req.url === '/__purge') { cache.clear(); res.writeHead(200); return res.end('purged\n'); }
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const anon = req.method === 'GET' && !/wordpress_logged_in|woocommerce_items_in_cart/.test(req.headers.cookie || '');
    const key = req.url + '|' + (req.headers['x-exp'] || ''); // x-exp: free-form experiment label, part of the cache key
    let out = useCache && anon && cache.get(key);
    if (!out) {
        const up = await upstream(req, Buffer.concat(chunks)).catch((e) => ({ status: 502, headers: {}, body: Buffer.from(String(e)) }));
        const type = up.headers['content-type'] || '';
        let body = up.body;
        if (text.test(type)) body = Buffer.from(rewrite(body.toString('utf8')));
        const headers = {};
        for (const [k, v] of Object.entries(up.headers)) {
            if (!['connection', 'keep-alive', 'transfer-encoding', 'content-length', 'content-encoding', 'upgrade'].includes(k)) headers[k] = v;
        }
        if (headers.location) headers.location = rewrite(headers.location);
        out = { status: up.status, headers, body, type };
        if (anon && up.status === 200 && /text\/html/.test(type)) cache.set(key, out);
    }
    const headers = { ...out.headers };
    let body = out.body;
    const ae = req.headers['accept-encoding'] || '';
    if (text.test(out.type) && body.length > 1024) {
        if (/\bbr\b/.test(ae)) { body = zlib.brotliCompressSync(body, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 5 } }); headers['content-encoding'] = 'br'; }
        else if (/gzip/.test(ae)) { body = zlib.gzipSync(body); headers['content-encoding'] = 'gzip'; }
    }
    headers['content-length'] = body.length;
    res.writeHead(out.status, headers);
    res.end(body);
});
server.listen(PORT, () => console.log(`h2 proxy ${TO} -> ${FROM} cache=${useCache ? 'on' : 'off'}`));
