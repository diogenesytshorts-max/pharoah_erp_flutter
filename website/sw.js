const CACHE_NAME = "pharoah-web-v1";
const ASSETS_TO_CACHE = [
  "./",
  "./index.html",
  "./style.css",
  "./app.js",
  "./drive_sync.js",
  "./manifest.json"
];

// Install Service Worker
self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log("⚡ PWA: Caching ERP static assets");
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
  self.skipWaiting();
});

// Activate & Remove Old Caches
self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((k) => {
          if (k !== CACHE_NAME) {
            return caches.delete(k);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch Assets from Cache first, fallback to network
self.addEventListener("fetch", (e) => {
  // Only cache GET requests for local assets
  if (e.request.method !== "GET" || e.request.url.includes("script.google.com")) {
    return;
  }

  e.respondWith(
    caches.match(e.request).then((cachedResponse) => {
      return (
        cachedResponse ||
        fetch(e.request).then((networkResponse) => {
          return caches.open(CACHE_NAME).then((cache) => {
            cache.put(e.request, networkResponse.clone());
            return networkResponse;
          });
        })
      );
    }).catch(() => caches.match("./index.html"))
  );
});
