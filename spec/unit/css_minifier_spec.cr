require "../spec_helper"

describe Hwaro::Utils::CssMinifier do
  describe ".minify" do
    it "removes CSS comments" do
      css = "body { /* main style */ color: red; }"
      result = Hwaro::Utils::CssMinifier.minify(css)
      result.should_not contain("/* main style */")
      result.should contain("color:red")
    end

    it "removes multi-line comments" do
      css = "body {\n  /* this is\n  a multi-line\n  comment */\n  color: red;\n}"
      result = Hwaro::Utils::CssMinifier.minify(css)
      result.should_not contain("multi-line")
      result.should contain("color:red")
    end

    it "collapses whitespace" do
      css = "body  {\n  color:  red;\n  font-size:  14px;\n}"
      result = Hwaro::Utils::CssMinifier.minify(css)
      result.should_not contain("\n")
    end

    it "removes whitespace around structural characters" do
      css = "body { color : red ; font-size : 14px ; }"
      result = Hwaro::Utils::CssMinifier.minify(css)
      result.should contain("color:red")
      result.should contain("font-size:14px")
    end

    it "strips trailing semicolons before }" do
      css = "body { color: red; }"
      result = Hwaro::Utils::CssMinifier.minify(css)
      result.should contain("color:red}")
      result.should_not contain(";}")
    end

    it "handles empty input" do
      Hwaro::Utils::CssMinifier.minify("").should eq("")
    end

    it "preserves functional CSS" do
      css = ".btn{background:#fff;border:1px solid #ccc}"
      result = Hwaro::Utils::CssMinifier.minify(css)
      result.should contain(".btn{background:#fff")
    end
  end
end
