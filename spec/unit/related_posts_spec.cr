require "../spec_helper"
require "../../src/models/config"
require "../../src/models/page"
require "../../src/models/site"
require "../../src/core/build/builder"

# Reopen Builder to expose private method for testing
module Hwaro::Core::Build
  class Builder
    def test_compute_related_posts(site)
      compute_related_posts(site)
    end
  end
end

describe "RelatedConfig" do
  it "has correct defaults" do
    config = Hwaro::Models::RelatedConfig.new
    config.enabled.should be_false
    config.limit.should eq(5)
    config.taxonomies.should eq(["tags"])
  end
end

describe "Related posts" do
  it "computes related posts based on shared tags" do
    builder = Hwaro::Core::Build::Builder.new
    config = Hwaro::Models::Config.new
    config.related.enabled = true
    config.related.limit = 3
    config.related.taxonomies = ["tags"]

    site = Hwaro::Models::Site.new(config)

    p1 = Hwaro::Models::Page.new("posts/a.md")
    p1.title = "Post A"
    p1.tags = ["crystal", "web"]
    p1.url = "/posts/a/"

    p2 = Hwaro::Models::Page.new("posts/b.md")
    p2.title = "Post B"
    p2.tags = ["crystal", "web", "api"]
    p2.url = "/posts/b/"

    p3 = Hwaro::Models::Page.new("posts/c.md")
    p3.title = "Post C"
    p3.tags = ["crystal"]
    p3.url = "/posts/c/"

    p4 = Hwaro::Models::Page.new("posts/d.md")
    p4.title = "Post D"
    p4.tags = ["python"]
    p4.url = "/posts/d/"

    site.pages = [p1, p2, p3, p4]

    builder.test_compute_related_posts(site)

    # p1 shares 2 tags with p2 (crystal, web), 1 with p3 (crystal), 0 with p4
    p1.related_posts.size.should eq(2)
    p1.related_posts[0].title.should eq("Post B") # highest score
    p1.related_posts[1].title.should eq("Post C")

    # p4 shares no tags with anyone
    p4.related_posts.should be_empty
  end

  it "respects the limit setting" do
    builder = Hwaro::Core::Build::Builder.new
    config = Hwaro::Models::Config.new
    config.related.enabled = true
    config.related.limit = 1
    config.related.taxonomies = ["tags"]

    site = Hwaro::Models::Site.new(config)

    p1 = Hwaro::Models::Page.new("posts/a.md")
    p1.title = "Post A"
    p1.tags = ["crystal", "web"]
    p1.url = "/posts/a/"

    p2 = Hwaro::Models::Page.new("posts/b.md")
    p2.title = "Post B"
    p2.tags = ["crystal", "web"]
    p2.url = "/posts/b/"

    p3 = Hwaro::Models::Page.new("posts/c.md")
    p3.title = "Post C"
    p3.tags = ["crystal"]
    p3.url = "/posts/c/"

    site.pages = [p1, p2, p3]

    builder.test_compute_related_posts(site)

    p1.related_posts.size.should eq(1)
    p1.related_posts[0].title.should eq("Post B")
  end

  it "excludes drafts, index pages, and generated pages" do
    builder = Hwaro::Core::Build::Builder.new
    config = Hwaro::Models::Config.new
    config.related.enabled = true
    config.related.taxonomies = ["tags"]

    site = Hwaro::Models::Site.new(config)

    p1 = Hwaro::Models::Page.new("posts/a.md")
    p1.title = "Post A"
    p1.tags = ["crystal"]
    p1.url = "/posts/a/"

    p_draft = Hwaro::Models::Page.new("posts/draft.md")
    p_draft.title = "Draft"
    p_draft.tags = ["crystal"]
    p_draft.draft = true
    p_draft.url = "/posts/draft/"

    p_index = Hwaro::Models::Page.new("posts/_index.md")
    p_index.title = "Index"
    p_index.tags = ["crystal"]
    p_index.is_index = true
    p_index.url = "/posts/"

    p_gen = Hwaro::Models::Page.new("tags/crystal.md")
    p_gen.title = "Crystal Tag"
    p_gen.tags = ["crystal"]
    p_gen.generated = true
    p_gen.url = "/tags/crystal/"

    site.pages = [p1, p_draft, p_index, p_gen]

    builder.test_compute_related_posts(site)

    p1.related_posts.should be_empty
  end

  it "works with custom taxonomy names" do
    builder = Hwaro::Core::Build::Builder.new
    config = Hwaro::Models::Config.new
    config.related.enabled = true
    config.related.taxonomies = ["categories"]

    site = Hwaro::Models::Site.new(config)

    p1 = Hwaro::Models::Page.new("posts/a.md")
    p1.title = "Post A"
    p1.taxonomies = {"categories" => ["tutorials"]}
    p1.url = "/posts/a/"

    p2 = Hwaro::Models::Page.new("posts/b.md")
    p2.title = "Post B"
    p2.taxonomies = {"categories" => ["tutorials", "guides"]}
    p2.url = "/posts/b/"

    p3 = Hwaro::Models::Page.new("posts/c.md")
    p3.title = "Post C"
    p3.taxonomies = {"categories" => ["news"]}
    p3.url = "/posts/c/"

    site.pages = [p1, p2, p3]

    builder.test_compute_related_posts(site)

    p1.related_posts.size.should eq(1)
    p1.related_posts[0].title.should eq("Post B")
  end

  it "scores across multiple taxonomies" do
    builder = Hwaro::Core::Build::Builder.new
    config = Hwaro::Models::Config.new
    config.related.enabled = true
    config.related.taxonomies = ["tags", "categories"]

    site = Hwaro::Models::Site.new(config)

    p1 = Hwaro::Models::Page.new("posts/a.md")
    p1.title = "Post A"
    p1.tags = ["crystal"]
    p1.taxonomies = {"tags" => ["crystal"], "categories" => ["tutorials"]}
    p1.url = "/posts/a/"

    p2 = Hwaro::Models::Page.new("posts/b.md")
    p2.title = "Post B"
    p2.tags = ["crystal"]
    p2.taxonomies = {"tags" => ["crystal"], "categories" => ["tutorials"]}
    p2.url = "/posts/b/"

    p3 = Hwaro::Models::Page.new("posts/c.md")
    p3.title = "Post C"
    p3.tags = ["crystal"]
    p3.taxonomies = {"tags" => ["crystal"], "categories" => ["news"]}
    p3.url = "/posts/c/"

    site.pages = [p1, p2, p3]

    builder.test_compute_related_posts(site)

    # p2 matches on both tags + categories (score=2), p3 only on tags (score=1)
    p1.related_posts.size.should eq(2)
    p1.related_posts[0].title.should eq("Post B")
    p1.related_posts[1].title.should eq("Post C")
  end
end
