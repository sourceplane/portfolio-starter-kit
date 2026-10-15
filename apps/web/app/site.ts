// The site's identity, written once. The heading, the page titles, the Open
// Graph card, the RSS channel and the JSON-LD author all read SITE_NAME; the
// nav and the footer link to SOURCE_URL. A product built from this baseline
// gets both rewritten to its own name and repository at instantiation, so
// keep them literal and on one line each.
export const SITE_NAME = "My Portfolio"
export const SOURCE_URL = "https://github.com/sourceplane/portfolio-starter-kit"

// For text placed inside XML (the RSS feed): a site name may carry `&` or `'`.
export function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}
