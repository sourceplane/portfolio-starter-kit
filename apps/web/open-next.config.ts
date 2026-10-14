// OpenNext Cloudflare adapter config.
//
// The template is statically generated: every page is pre-rendered at build
// time and nothing revalidates. The static-assets incremental cache serves
// those pre-rendered pages straight from the Worker's static assets (read
// only, no R2/KV/D1 to provision), which is exactly the shape of a content
// site. A template that revalidates (ISR, `revalidateTag`) swaps this for the
// R2 incremental cache plus a tag cache.
import { defineCloudflareConfig } from "@opennextjs/cloudflare/config";
import staticAssetsIncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/static-assets-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: staticAssetsIncrementalCache,
});
