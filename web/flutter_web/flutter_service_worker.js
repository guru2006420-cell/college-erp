self.addEventListener('install', function (event) { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    try { const keys = await caches.keys(); await Promise.all(keys.map(function (k) { return caches.delete(k); })); } catch (e) {}
    try { await self.registration.unregister(); } catch (e) {}
    try { const clients = await self.clients.matchAll({ type: 'window' }); clients.forEach(function (client) { client.navigate(client.url); }); } catch (e) {}
  })());
});
self.addEventListener('fetch', function (event) {});
