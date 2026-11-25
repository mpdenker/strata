// Offline support. Every request goes to the network first so edits show up right away; if the
// network is unavailable (or slow), the last saved copy is used. The page asks this worker to save
// every file it loaded, so after one online visit the whole app and all lessons work offline.
const CACHE = 'strata-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('message', e => {
  if (e.data?.type !== 'cache') return;
  e.waitUntil(caches.open(CACHE).then(cache => Promise.all(
    e.data.urls.map(url => fetch(url, { cache: 'no-cache' }).then(r => r.ok && cache.put(url, r)).catch(() => {}))
  )));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const res = await Promise.race([
        fetch(req),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 4000)),
      ]);
      if (res.ok) cache.put(req, res.clone());
      return res;
    } catch (err) {
      const hit = await cache.match(req, { ignoreSearch: true }) ?? (req.mode === 'navigate' ? await cache.match('./') : null);
      if (hit) return hit;
      throw err;
    }
  })());
});
