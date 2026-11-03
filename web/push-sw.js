self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};
  event.waitUntil(self.registration.showNotification(data.title || 'InkFlow', {
    body: data.body || 'Você recebeu uma atualização.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { route: data.route || '/notifications' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification.data?.route || '/notifications';
  const target = `/#${route}`;
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then((windows) => {
      for (const client of windows) {
        if ('navigate' in client) client.navigate(target);
        if ('focus' in client) return client.focus();
      }
      return clients.openWindow(target);
    }));
});
