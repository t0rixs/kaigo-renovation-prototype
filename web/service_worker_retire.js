self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const cacheNames = await caches.keys();
      await Promise.all(cacheNames.map((name) => caches.delete(name)));
      await self.clients.claim();
      const windowClients = await self.clients.matchAll({ type: 'window' });
      await self.registration.unregister();
      await Promise.all(
        windowClients.map((client) => client.navigate(client.url)),
      );
    })(),
  );
});
