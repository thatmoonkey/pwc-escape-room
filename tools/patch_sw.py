# Post-export patch for the Godot-generated service worker.
#
# Godot's web_pwa template serves navigation requests cache-first, so an
# installed PWA can keep launching an old build indefinitely. This patch
# flips navigation requests to network-first (cache is the offline
# fallback), so every launch picks up the newest deploy.
import sys

path = sys.argv[1]
src = open(path).read()

if "PWC PATCH" in src:
    print("patch_sw: already patched")
    sys.exit(0)

anchor = "const cache = await caches.open(CACHE_NAME)"
inject = anchor + """

			// PWC PATCH: navigation requests go network-first so an installed
			// app always picks up the newest build; cache is the fallback.
			if (isNavigate) {
				try {
					const response = await self.fetch(event.request)
					if (response && response.ok) {
						await cache.put(event.request, response.clone())
						return response
					}
				} catch (e) { /* offline: fall through to cache */ }
			}"""

if anchor not in src:
    print("patch_sw: anchor not found in " + path, file=sys.stderr)
    sys.exit(1)

src = src.replace(anchor, inject, 1)
open(path, "w").write(src)
print("patch_sw: service worker now network-first for navigation")
