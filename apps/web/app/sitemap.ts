import { getBlogPosts } from 'app/blog/utils'

// The site's public origin: sitemap, RSS, OG image and JSON-LD links are
// absolute. The Orun build sets it to the environment's Worker URL; set
// NEXT_PUBLIC_SITE_URL yourself for a custom domain or local preview.
export const baseUrl =
  process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000'

export default async function sitemap() {
  let blogs = getBlogPosts().map((post) => ({
    url: `${baseUrl}/blog/${post.slug}`,
    lastModified: post.metadata.publishedAt,
  }))

  let routes = ['', '/blog'].map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date().toISOString().split('T')[0],
  }))

  return [...routes, ...blogs]
}
