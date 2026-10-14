// Cloudflare Web Analytics stands in for @vercel/analytics and
// @vercel/speed-insights: one beacon script, Core Web Vitals included. It
// renders nothing until NEXT_PUBLIC_CF_BEACON_TOKEN is set at build time
// (Cloudflare dashboard → Web Analytics → add a site → the JS snippet token).
export function CloudflareWebAnalytics() {
  const token = process.env.NEXT_PUBLIC_CF_BEACON_TOKEN
  if (!token) {
    return null
  }
  return (
    <script
      defer
      src="https://static.cloudflareinsights.com/beacon.min.js"
      data-cf-beacon={JSON.stringify({ token })}
    />
  )
}
