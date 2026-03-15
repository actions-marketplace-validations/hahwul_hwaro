require "../../spec_helper"

# Concrete test implementation of the abstract Base class
class TestImporter < Hwaro::Services::Importers::Base
  def run(options : Hwaro::Config::Options::ImportOptions) : Hwaro::Services::Importers::ImportResult
    Hwaro::Services::Importers::ImportResult.new(success: true, message: "ok")
  end

  # Expose protected methods for testing
  def test_generate_frontmatter(fields)
    generate_frontmatter(fields)
  end

  def test_slugify(title)
    slugify(title)
  end

  def test_parse_date(date_str)
    parse_date(date_str)
  end

  def test_format_date(time)
    format_date(time)
  end

  def test_write_content_file(output_dir, section, slug, frontmatter, body, verbose = false)
    write_content_file(output_dir, section, slug, frontmatter, body, verbose)
  end
end

describe Hwaro::Services::Importers::Base do
  describe "#generate_frontmatter" do
    it "generates TOML frontmatter with string values" do
      importer = TestImporter.new
      result = importer.test_generate_frontmatter({
        "title" => "My Post" .as(String | Bool | Array(String) | Nil),
        "date"  => "2024-01-15" .as(String | Bool | Array(String) | Nil),
      })
      result.should contain("+++")
      result.should contain(%(title = "My Post"))
      result.should contain(%(date = "2024-01-15"))
    end

    it "generates TOML frontmatter with bool values" do
      importer = TestImporter.new
      result = importer.test_generate_frontmatter({
        "draft" => true.as(String | Bool | Array(String) | Nil),
      })
      result.should contain("draft = true")
    end

    it "generates TOML frontmatter with array values" do
      importer = TestImporter.new
      result = importer.test_generate_frontmatter({
        "tags" => ["crystal", "web"].as(String | Bool | Array(String) | Nil),
      })
      result.should contain(%(tags = ["crystal", "web"]))
    end

    it "skips nil and empty values" do
      importer = TestImporter.new
      result = importer.test_generate_frontmatter({
        "title" => "Valid".as(String | Bool | Array(String) | Nil),
        "desc"  => nil.as(String | Bool | Array(String) | Nil),
        "empty" => "".as(String | Bool | Array(String) | Nil),
      })
      result.should contain("title")
      result.should_not contain("desc")
      result.should_not contain("empty")
    end
  end

  describe "#slugify" do
    it "converts title to slug" do
      importer = TestImporter.new
      importer.test_slugify("Hello World").should eq("hello-world")
    end
  end

  describe "#parse_date" do
    it "parses ISO date" do
      importer = TestImporter.new
      time = importer.test_parse_date("2024-01-15")
      time.should_not be_nil
      time.not_nil!.year.should eq(2024)
      time.not_nil!.month.should eq(1)
      time.not_nil!.day.should eq(15)
    end

    it "parses datetime" do
      importer = TestImporter.new
      time = importer.test_parse_date("2024-01-15 10:30:00")
      time.should_not be_nil
      time.not_nil!.hour.should eq(10)
    end

    it "returns nil for invalid date" do
      importer = TestImporter.new
      importer.test_parse_date("not-a-date").should be_nil
    end
  end

  describe "#write_content_file" do
    it "writes a markdown file" do
      Dir.mktmpdir do |dir|
        importer = TestImporter.new
        result = importer.test_write_content_file(dir, "posts", "hello-world", "+++\ntitle = \"Hello\"\n+++", "Content here")
        result.should be_true

        path = File.join(dir, "posts", "hello-world.md")
        File.exists?(path).should be_true
        content = File.read(path)
        content.should contain("title = \"Hello\"")
        content.should contain("Content here")
      end
    end

    it "skips existing files" do
      Dir.mktmpdir do |dir|
        importer = TestImporter.new
        importer.test_write_content_file(dir, "", "existing", "+++\n+++", "First")
        result = importer.test_write_content_file(dir, "", "existing", "+++\n+++", "Second")
        result.should be_false

        content = File.read(File.join(dir, "existing.md"))
        content.should contain("First")
        content.should_not contain("Second")
      end
    end
  end
end
