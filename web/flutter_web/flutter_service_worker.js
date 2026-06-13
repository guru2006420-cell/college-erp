self.addEventListener('install', function (e) { self.skipWaiting(); });
self.addEventListener('activate', function (e) {
  e.waitUntil((async function () {
    try { const k = await caches.keys(); await Promise.all(k.map(function(c){return caches.delete(c);})); } catch(e){}
    try { await self.registration.unregister(); } catch(e){}
    try { const cl = await self.clients.matchAll({type:'window'}); cl.forEach(function(c){c.navigate(c.url);}); } catch(e){}
  })());
});
self.addEventListener('fetch', function (e) {});
