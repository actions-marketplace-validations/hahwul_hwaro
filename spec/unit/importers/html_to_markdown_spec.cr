require "../../spec_helper"

describe Hwaro::Services::Importers::HtmlToMarkdown do
  describe ".convert" do
    it "converts headings" do
      Hwaro::Services::Importers::HtmlToMarkdown.convert("<h1>Title</h1>").should eq("# Title")
      Hwaro::Services::Importers::HtmlToMarkdown.convert("<h2>Sub</h2>").should eq("## Sub")
      Hwaro::Services::Importers::HtmlToMarkdown.convert("<h3>Sub3</h3>").should eq("### Sub3")
    end

    it "converts paragraphs" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert("<p>Hello world</p>")
      result.should eq("Hello world")
    end

    it "converts bold text" do
      Hwaro::Services::Importers::HtmlToMarkdown.convert("<strong>bold</strong>").should eq("**bold**")
      Hwaro::Services::Importers::HtmlToMarkdown.convert("<b>bold</b>").should eq("**bold**")
    end

    it "converts italic text" do
      Hwaro::Services::Importers::HtmlToMarkdown.convert("<em>italic</em>").should eq("*italic*")
      Hwaro::Services::Importers::HtmlToMarkdown.convert("<i>italic</i>").should eq("*italic*")
    end

    it "converts links" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert(%(<a href="https://example.com">Link</a>))
      result.should eq("[Link](https://example.com)")
    end

    it "converts images" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert(%(<img src="/img.png" alt="Alt text" />))
      result.should eq("![Alt text](/img.png)")
    end

    it "converts unordered lists" do
      html = "<ul><li>One</li><li>Two</li></ul>"
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert(html)
      result.should contain("- One")
      result.should contain("- Two")
    end

    it "converts ordered lists" do
      html = "<ol><li>First</li><li>Second</li></ol>"
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert(html)
      result.should contain("1. First")
      result.should contain("2. Second")
    end

    it "converts code blocks" do
      html = "<pre><code>puts 1</code></pre>"
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert(html)
      result.should contain("```")
      result.should contain("puts 1")
    end

    it "converts inline code" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert("<code>foo</code>")
      result.should eq("`foo`")
    end

    it "converts blockquotes" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert("<blockquote>Quote here</blockquote>")
      result.should contain("> Quote here")
    end

    it "converts strikethrough" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert("<del>removed</del>")
      result.should eq("~~removed~~")
    end

    it "decodes HTML entities" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert("&amp; &lt; &gt; &quot;")
      result.should eq("& < > \"")
    end

    it "strips unknown tags" do
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert("<div><span>text</span></div>")
      result.should eq("text")
    end

    it "returns empty string for empty input" do
      Hwaro::Services::Importers::HtmlToMarkdown.convert("").should eq("")
    end

    it "handles complex nested HTML" do
      html = "<p>Hello <strong>bold <em>and italic</em></strong> world</p>"
      result = Hwaro::Services::Importers::HtmlToMarkdown.convert(html)
      result.should contain("**bold *and italic***")
    end
  end
end
