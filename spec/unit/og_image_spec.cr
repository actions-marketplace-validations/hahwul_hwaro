require "../spec_helper"

private def make_og_config(toml : String = "") : Hwaro::Models::Config
  config_str = <<-TOML
  title = "Test Site"
  description = "A test site"
  base_url = "https://example.com"
  #{toml}
  TOML

  File.tempfile("hwaro-og", ".toml") do |file|
    file.print(config_str)
    file.flush
    return Hwaro::Models::Config.load(file.path)
  end
  raise "unreachable"
end

describe Hwaro::Models::AutoImageConfig do
  describe "defaults" do
    it "is disabled by default" do
      config = Hwaro::Models::Config.new
      config.og.auto_image.enabled.should be_false
      config.og.auto_image.background.should eq("#1a1a2e")
      config.og.auto_image.text_color.should eq("#ffffff")
      config.og.auto_image.font_size.should eq(48)
      config.og.auto_image.output_dir.should eq("og-images")
    end
  end

  describe "loading from TOML" do
    it "loads auto_image config from [og.auto_image]" do
      config = make_og_config(<<-TOML)
      [og.auto_image]
      enabled = true
      background = "#000000"
      text_color = "#ff0000"
      accent_color = "#00ff00"
      font_size = 64
      logo = "static/logo.png"
      output_dir = "social"
      TOML

      ai = config.og.auto_image
      ai.enabled.should be_true
      ai.background.should eq("#000000")
      ai.text_color.should eq("#ff0000")
      ai.accent_color.should eq("#00ff00")
      ai.font_size.should eq(64)
      ai.logo.should eq("static/logo.png")
      ai.output_dir.should eq("social")
    end
  end
end

describe Hwaro::Content::Seo::OgImage do
  describe ".render_svg" do
    it "renders a valid SVG with page title" do
      page = Hwaro::Models::Page.new("test.md")
      page.title = "Hello World"
      page.description = "A great post about things"

      config = Hwaro::Models::Config.new
      config.title = "My Site"
      config.og.auto_image.enabled = true

      svg = Hwaro::Content::Seo::OgImage.render_svg(page, config)

      svg.should contain("<?xml")
      svg.should contain("<svg")
      svg.should contain("1200")
      svg.should contain("630")
      svg.should contain("Hello World")
      svg.should contain("A great post about things")
      svg.should contain("My Site")
    end

    it "uses configured colors" do
      page = Hwaro::Models::Page.new("test.md")
      page.title = "Test"

      config = Hwaro::Models::Config.new
      config.og.auto_image.background = "#ff0000"
      config.og.auto_image.text_color = "#00ff00"
      config.og.auto_image.accent_color = "#0000ff"

      svg = Hwaro::Content::Seo::OgImage.render_svg(page, config)

      svg.should contain("#ff0000")
      svg.should contain("#00ff00")
      svg.should contain("#0000ff")
    end

    it "wraps long titles" do
      page = Hwaro::Models::Page.new("test.md")
      page.title = "This is a very long title that should be wrapped across multiple lines to fit"

      config = Hwaro::Models::Config.new
      config.og.auto_image.enabled = true

      svg = Hwaro::Content::Seo::OgImage.render_svg(page, config)

      # Should have multiple <text> elements for wrapped title
      text_count = svg.scan(/<text[^>]*font-weight="700"/).size
      text_count.should be > 1
    end

    it "escapes XML special characters in title" do
      page = Hwaro::Models::Page.new("test.md")
      page.title = "A <b>bold</b> & \"quoted\" title"

      config = Hwaro::Models::Config.new
      svg = Hwaro::Content::Seo::OgImage.render_svg(page, config)

      svg.should contain("&lt;b&gt;")
      svg.should contain("&amp;")
    end

    it "includes logo when configured" do
      page = Hwaro::Models::Page.new("test.md")
      page.title = "Test"

      config = Hwaro::Models::Config.new
      config.og.auto_image.logo = "static/logo.png"

      svg = Hwaro::Content::Seo::OgImage.render_svg(page, config)

      svg.should contain("<image")
      svg.should contain("/logo.png")
    end
  end

  describe ".generate" do
    it "does nothing when disabled" do
      Dir.mktmpdir do |dir|
        config = Hwaro::Models::Config.new
        pages = [] of Hwaro::Models::Page
        Hwaro::Content::Seo::OgImage.generate(pages, config, dir)

        Dir.exists?(File.join(dir, "og-images")).should be_false
      end
    end

    it "generates SVG files and sets page.image" do
      Dir.mktmpdir do |dir|
        config = Hwaro::Models::Config.new
        config.title = "My Site"
        config.og.auto_image.enabled = true

        page = Hwaro::Models::Page.new("test.md")
        page.title = "My Post"
        page.url = "/posts/my-post/"
        page.render = true

        Hwaro::Content::Seo::OgImage.generate([page], config, dir)

        # SVG file should exist (slug derived from URL path)
        svg_path = File.join(dir, "og-images", "posts-my-post.svg")
        File.exists?(svg_path).should be_true

        # SVG content should be valid
        svg = File.read(svg_path)
        svg.should contain("<svg")
        svg.should contain("My Post")

        # page.image should be set
        page.image.should eq("/og-images/posts-my-post.svg")
      end
    end

    it "skips pages that already have a custom image" do
      Dir.mktmpdir do |dir|
        config = Hwaro::Models::Config.new
        config.og.auto_image.enabled = true

        page = Hwaro::Models::Page.new("test.md")
        page.title = "Has Image"
        page.url = "/posts/has-image/"
        page.image = "/images/custom.png"
        page.render = true

        Hwaro::Content::Seo::OgImage.generate([page], config, dir)

        # Should NOT generate an OG image
        File.exists?(File.join(dir, "og-images", "posts-has-image.svg")).should be_false

        # Original image should remain
        page.image.should eq("/images/custom.png")
      end
    end

    it "skips draft pages" do
      Dir.mktmpdir do |dir|
        config = Hwaro::Models::Config.new
        config.og.auto_image.enabled = true

        page = Hwaro::Models::Page.new("test.md")
        page.title = "Draft"
        page.url = "/posts/draft/"
        page.draft = true
        page.render = true

        Hwaro::Content::Seo::OgImage.generate([page], config, dir)
        File.exists?(File.join(dir, "og-images", "posts-draft.svg")).should be_false
      end
    end

    it "uses custom output directory" do
      Dir.mktmpdir do |dir|
        config = Hwaro::Models::Config.new
        config.og.auto_image.enabled = true
        config.og.auto_image.output_dir = "social-images"

        page = Hwaro::Models::Page.new("test.md")
        page.title = "Custom Dir"
        page.url = "/posts/custom/"
        page.render = true

        Hwaro::Content::Seo::OgImage.generate([page], config, dir)

        File.exists?(File.join(dir, "social-images", "posts-custom.svg")).should be_true
        page.image.should eq("/social-images/posts-custom.svg")
      end
    end

    it "generates unique files for multiple pages" do
      Dir.mktmpdir do |dir|
        config = Hwaro::Models::Config.new
        config.og.auto_image.enabled = true

        page1 = Hwaro::Models::Page.new("a.md")
        page1.title = "First Post"
        page1.url = "/posts/first/"
        page1.render = true

        page2 = Hwaro::Models::Page.new("b.md")
        page2.title = "Second Post"
        page2.url = "/posts/second/"
        page2.render = true

        Hwaro::Content::Seo::OgImage.generate([page1, page2], config, dir)

        File.exists?(File.join(dir, "og-images", "posts-first.svg")).should be_true
        File.exists?(File.join(dir, "og-images", "posts-second.svg")).should be_true
        page1.image.should_not eq(page2.image)
      end
    end
  end
end
