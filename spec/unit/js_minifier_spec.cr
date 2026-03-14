require "../spec_helper"

describe Hwaro::Utils::JsMinifier do
  describe ".minify" do
    it "removes single-line comments" do
      js = "var x = 1; // this is a comment\nvar y = 2;"
      result = Hwaro::Utils::JsMinifier.minify(js)
      result.should_not contain("// this is a comment")
      result.should contain("var x = 1;")
      result.should contain("var y = 2;")
    end

    it "removes multi-line comments" do
      js = "var x = 1; /* multi\nline\ncomment */ var y = 2;"
      result = Hwaro::Utils::JsMinifier.minify(js)
      result.should_not contain("multi")
      result.should contain("var x = 1;")
      result.should contain("var y = 2;")
    end

    it "preserves strings with // inside" do
      js = %{var url = "http://example.com";}
      result = Hwaro::Utils::JsMinifier.minify(js)
      result.should contain("http://example.com")
    end

    it "preserves strings with /* inside" do
      js = %{var s = "/* not a comment */";}
      result = Hwaro::Utils::JsMinifier.minify(js)
      result.should contain("/* not a comment */")
    end

    it "removes blank lines" do
      js = "var x = 1;\n\n\n\nvar y = 2;"
      result = Hwaro::Utils::JsMinifier.minify(js)
      result.should_not contain("\n\n")
    end

    it "handles empty input" do
      Hwaro::Utils::JsMinifier.minify("").should eq("")
    end

    it "preserves template literals" do
      js = "var s = `hello ${name}`;"
      result = Hwaro::Utils::JsMinifier.minify(js)
      result.should contain("`hello ${name}`")
    end
  end
end
