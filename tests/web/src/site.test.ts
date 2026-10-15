import { describe, expect, it } from "vitest";

describe("site identity (apps/web/app/site.ts)", () => {
  it("names the site and links its source repository", async () => {
    const { SITE_NAME, SOURCE_URL } = await import("app/site");
    expect(SITE_NAME.trim()).not.toBe("");
    expect(SOURCE_URL).toMatch(/^https:\/\/github\.com\/[A-Za-z0-9-]+\/[a-z0-9-]+$/);
  });

  it("escapes a site name for the RSS channel", async () => {
    const { escapeXml } = await import("app/site");
    expect(escapeXml("Sam's Notes & <Links>")).toBe("Sam&apos;s Notes &amp; &lt;Links&gt;");
    expect(escapeXml("Plain")).toBe("Plain");
  });
});
