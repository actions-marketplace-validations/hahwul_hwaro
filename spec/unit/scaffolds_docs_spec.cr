require "../spec_helper"
require "../../src/services/scaffolds/docs"

describe Hwaro::Services::Scaffolds::Docs do
  describe "#static_files" do
    it "includes css/style.css" do
      scaffold = Hwaro::Services::Scaffolds::Docs.new
      files = scaffold.static_files
      files.has_key?("css/style.css").should be_true
      files["css/style.css"].should_not be_empty
    end
  end

  describe "#styles" do
    it "returns a link tag" do
      # Since `styles` is protected, we need to access it via send or similar if we were in Ruby,
      # but in Crystal we can't easily call protected methods from outside.
      # However, we can check `header_template` which uses `styles`.
      scaffold = Hwaro::Services::Scaffolds::Docs.new
      header = scaffold.template_files["header.html"]
      header.should contain("<link rel=\"stylesheet\" href=\"{{ base_url }}/css/style.css\">")
    end
  end
end
