+++
title = "Auto OG Images"
description = "Auto-generate Open Graph preview images from page titles"
weight = 20
toc = true
+++

Hwaro can automatically generate Open Graph (OG) preview images for pages that don't have a custom image set. These images are used by social media platforms when your content is shared.

## How It Works

1. During build, Hwaro checks each page for a custom `image` in front matter
2. Pages without an image get an auto-generated SVG image (1200x630)
3. The generated image path is set as `page.image`, so `og:image` meta tags pick it up automatically
4. No external tools or dependencies required — images are pure SVG

## Configuration

```toml
[og.auto_image]
enabled = true
background = "#1a1a2e"
text_color = "#ffffff"
accent_color = "#e94560"
font_size = 48
logo = "static/logo.png"
output_dir = "og-images"
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| enabled | bool | false | Enable auto OG image generation |
| background | string | "#1a1a2e" | Background color (hex) |
| text_color | string | "#ffffff" | Title and description text color |
| accent_color | string | "#e94560" | Accent color for bars and site name |
| font_size | int | 48 | Title font size in pixels |
| logo | string | — | Logo file path (e.g., `static/logo.png`) |
| output_dir | string | "og-images" | Directory for generated images |

## Generated Image Layout

Each image is a 1200x630 SVG with:

```
┌─────────────────────────────────────┐
│ ████████████ accent bar ████████████│
│                                     │
│   Page Title (auto-wrapped,         │
│   bold, large font)                 │
│                                     │
│   Description text (smaller,        │
│   semi-transparent)                 │
│                                     │
│   [logo] Site Name                  │
│ ████████████ accent bar ████████████│
└─────────────────────────────────────┘
```

## Behavior

- Pages with a custom `image` in front matter are **skipped** (the custom image takes priority)
- Draft pages are **skipped**
- Long titles are automatically **word-wrapped** across multiple lines
- The generated SVG uses `system-ui` font family for broad compatibility

## Output

Given a page at `/posts/hello-world/`, the generated image will be:

```
public/og-images/hello-world.svg
```

And the OG meta tag will automatically include:

```html
<meta property="og:image" content="https://example.com/og-images/hello-world.svg">
```

## Overriding Per Page

To use a custom image for a specific page, set `image` in front matter:

```toml
+++
title = "My Post"
image = "/images/custom-og.png"
+++
```

This page will use the custom image instead of auto-generating one.

## See Also

- [SEO](/features/seo/) — OpenGraph, Twitter Cards, and meta tags
- [Configuration](/start/config/) — Full config reference
