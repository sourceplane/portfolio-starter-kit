import { beforeAll, describe, expect, it } from "vitest";
import * as path from "node:path";

// The posts loader reads `app/blog/posts` relative to process.cwd(), exactly
// as the Vercel template does; the app directory is the cwd at build time.
const appDir = path.resolve(__dirname, "../../../apps/web");

describe("blog utils (apps/web/app/blog/utils.ts)", () => {
  beforeAll(() => {
    process.chdir(appDir);
  });

  it("reads every MDX post with its front matter", async () => {
    const { getBlogPosts } = await import("app/blog/utils");
    const posts = getBlogPosts();
    expect(posts.map((p) => p.slug).sort()).toEqual(["spaces-vs-tabs", "static-typing", "vim"]);
    for (const post of posts) {
      expect(post.metadata.title).toBeTruthy();
      expect(post.metadata.publishedAt).toMatch(/^\d{4}-\d{2}-\d{2}/);
      expect(post.metadata.summary).toBeTruthy();
      expect(post.content).not.toMatch(/^---/);
    }
  });

  it("formats a date as a long date, with the relative distance on request", async () => {
    const { formatDate } = await import("app/blog/utils");
    expect(formatDate("2024-04-09")).toBe("April 9, 2024");
    expect(formatDate("2024-04-09", true)).toMatch(/^April 9, 2024 \(\d+(y|mo|d) ago\)$/);
    // formatDate compares local calendar dates, so "today" is the local date.
    const now = new Date();
    const today = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, "0"),
      String(now.getDate()).padStart(2, "0"),
    ].join("-");
    expect(formatDate(today, true)).toMatch(/\(Today\)$/);
  });
});

describe("site origin (apps/web/app/sitemap.ts)", () => {
  it("lists the home, the blog index and every post under the configured origin", async () => {
    process.env.NEXT_PUBLIC_SITE_URL = "https://portfolio.example.com";
    const { default: sitemap, baseUrl } = await import("app/sitemap");
    expect(baseUrl).toBe("https://portfolio.example.com");
    const entries = await sitemap();
    const urls = entries.map((e) => e.url);
    expect(urls).toContain("https://portfolio.example.com");
    expect(urls).toContain("https://portfolio.example.com/blog");
    expect(urls).toContain("https://portfolio.example.com/blog/vim");
  });
});
