require "../spec_helper"
require "../../src/services/scaffolds/remote"

describe Hwaro::Services::Scaffolds::Remote do
  describe ".remote?" do
    it "detects github: shorthand" do
      Hwaro::Services::Scaffolds::Remote.remote?("github:hahwul/hwaro-starter-blog").should be_true
    end

    it "detects https:// URL" do
      Hwaro::Services::Scaffolds::Remote.remote?("https://github.com/hahwul/hwaro-starter-blog").should be_true
    end

    it "detects http:// URL" do
      Hwaro::Services::Scaffolds::Remote.remote?("http://github.com/hahwul/hwaro-starter-blog").should be_true
    end

    it "detects git: shorthand" do
      Hwaro::Services::Scaffolds::Remote.remote?("git:owasp-noir/noir/docs").should be_true
    end

    it "returns false for built-in scaffold names" do
      Hwaro::Services::Scaffolds::Remote.remote?("simple").should be_false
      Hwaro::Services::Scaffolds::Remote.remote?("blog").should be_false
      Hwaro::Services::Scaffolds::Remote.remote?("docs").should be_false
    end
  end

  describe ".parse_source" do
    it "parses github:owner/repo shorthand" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("github:hahwul/hwaro-starter-blog")
      owner.should eq("hahwul")
      repo.should eq("hwaro-starter-blog")
      subpath.should eq("")
    end

    it "parses github:owner/repo/subpath shorthand" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("github:hahwul/hwaro/docs")
      owner.should eq("hahwul")
      repo.should eq("hwaro")
      subpath.should eq("docs")
    end

    it "parses github:owner/repo/deep/subpath shorthand" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("github:hahwul/hwaro/themes/starter")
      owner.should eq("hahwul")
      repo.should eq("hwaro")
      subpath.should eq("themes/starter")
    end

    it "parses git: shorthand" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("git:owasp-noir/noir/docs")
      owner.should eq("owasp-noir")
      repo.should eq("noir")
      subpath.should eq("docs")
    end

    it "parses https://github.com/owner/repo URL" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("https://github.com/hahwul/hwaro-starter-blog")
      owner.should eq("hahwul")
      repo.should eq("hwaro-starter-blog")
      subpath.should eq("")
    end

    it "parses GitHub URL with /tree/branch/subpath" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("https://github.com/hahwul/hwaro/tree/main/docs")
      owner.should eq("hahwul")
      repo.should eq("hwaro")
      subpath.should eq("docs")
    end

    it "parses GitHub URL with deep subpath" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("https://github.com/hahwul/hwaro/tree/main/themes/starter")
      owner.should eq("hahwul")
      repo.should eq("hwaro")
      subpath.should eq("themes/starter")
    end

    it "parses GitHub URL with direct subpath (no /tree/branch/)" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("https://github.com/owasp-noir/noir/docs")
      owner.should eq("owasp-noir")
      repo.should eq("noir")
      subpath.should eq("docs")
    end

    it "strips .git suffix from URL" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("https://github.com/hahwul/hwaro-starter-blog.git")
      owner.should eq("hahwul")
      repo.should eq("hwaro-starter-blog")
      subpath.should eq("")
    end

    it "handles URL with trailing slash" do
      owner, repo, subpath = Hwaro::Services::Scaffolds::Remote.parse_source("https://github.com/hahwul/hwaro-starter-blog/")
      owner.should eq("hahwul")
      repo.should eq("hwaro-starter-blog")
      subpath.should eq("")
    end

    it "raises on invalid github shorthand" do
      expect_raises(ArgumentError) do
        Hwaro::Services::Scaffolds::Remote.parse_source("github:invalid")
      end
    end

    it "raises on non-github URL" do
      expect_raises(ArgumentError) do
        Hwaro::Services::Scaffolds::Remote.parse_source("https://gitlab.com/user/repo")
      end
    end

    it "raises on github URL without repo" do
      expect_raises(ArgumentError) do
        Hwaro::Services::Scaffolds::Remote.parse_source("https://github.com/hahwul")
      end
    end
  end

  describe "#extract_front_matter (via content_files)" do
    # Test the extract_front_matter logic directly via a helper instance
    it "extracts TOML front matter (+++ delimiters)" do
      input = "+++\ntitle = \"Hello\"\nweight = 1\n+++\n\nThis is body content.\n\n## Heading\n\nMore text."
      expected = "+++\ntitle = \"Hello\"\nweight = 1\n+++\n"

      # Use a test subclass to expose the private method
      result = TestRemoteHelper.extract(input)
      result.should eq(expected)
    end

    it "extracts YAML front matter (--- delimiters)" do
      input = "---\ntitle: Hello\nweight: 1\n---\n\nBody content here."
      expected = "---\ntitle: Hello\nweight: 1\n---\n"

      result = TestRemoteHelper.extract(input)
      result.should eq(expected)
    end

    it "returns original content if no front matter" do
      input = "# Just a heading\n\nSome text."
      result = TestRemoteHelper.extract(input)
      result.should eq(input)
    end

    it "returns original content if front matter is not closed" do
      input = "+++\ntitle = \"Unclosed\"\nno closing delimiter"
      result = TestRemoteHelper.extract(input)
      result.should eq(input)
    end

    it "handles empty front matter" do
      input = "+++\n+++\n\nBody."
      expected = "+++\n+++\n"

      result = TestRemoteHelper.extract(input)
      result.should eq(expected)
    end
  end
end

# Helper to test the private extract_front_matter method
class TestRemoteHelper < Hwaro::Services::Scaffolds::Remote
  def initialize
    @config_data = ""
    @content_data = {} of String => String
    @template_data = {} of String => String
    @static_data = {} of String => String
    @shortcode_data = {} of String => String
    @description_text = "test"
  end

  def self.extract(content : String) : String
    instance = new
    instance.do_extract(content)
  end

  def do_extract(content : String) : String
    extract_front_matter(content)
  end
end
