// ============================================================================
// Firefox Hardware Acceleration & RAM Cache Optimization (Arch Linux / Intel)
// Safe, upstream-supported preferences preserved across all Firefox updates.
// ============================================================================

// 1. Force Intel VA-API Hardware Video Decoding & WebRender Compositor
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.compositor", true);
user_pref("widget.dmabuf.force-enabled", true);

// 2. Move Browser Cache from NVMe SSD to 32GB RAM (512 MB RAM Cache)
// Eliminates gigabytes of daily SSD writes and makes page loads instant
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 524288);
user_pref("browser.cache.memory.max_entry_size", 51200);

// 3. Reduce SSD Session Restore Writes (write every 5 mins instead of every 15s)
user_pref("browser.sessionstore.interval", 300000);

// 4. Network & HTTP/3 Responsiveness
user_pref("network.http.http3.enable", true);
user_pref("network.http.pacing.requests.enabled", false);
user_pref("network.dnsCacheEntries", 2000);
user_pref("network.dnsCacheExpiration", 3600);
