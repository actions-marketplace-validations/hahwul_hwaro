require "../spec_helper"

describe Hwaro::Assets::Pipeline do
  describe "#process" do
    it "bundles multiple CSS files" do
      Dir.mktmpdir do |dir|
        static_dir = File.join(dir, "static")
        output_dir = File.join(dir, "public")
        FileUtils.mkdir_p(File.join(static_dir, "css"))
        FileUtils.mkdir_p(output_dir)

        File.write(File.join(static_dir, "css", "reset.css"), "* { margin: 0; }")
        File.write(File.join(static_dir, "css", "style.css"), "body { color: red; }")

        config = Hwaro::Models::AssetsConfig.new
        config.enabled = true
        config.minify = false
        config.fingerprint = false
        config.source_dir = static_dir
        config.bundles << Hwaro::Models::AssetBundleConfig.new(
          name: "main.css",
          files: ["css/reset.css", "css/style.css"]
        )

        pipeline = Hwaro::Assets::Pipeline.new(config, "")
        pipeline.process(output_dir)

        output_file = File.join(output_dir, "assets", "main.css")
        File.exists?(output_file).should be_true
        content = File.read(output_file)
        content.should contain("margin: 0")
        content.should contain("color: red")
      end
    end

    it "bundles multiple JS files" do
      Dir.mktmpdir do |dir|
        static_dir = File.join(dir, "static")
        output_dir = File.join(dir, "public")
        FileUtils.mkdir_p(File.join(static_dir, "js"))
        FileUtils.mkdir_p(output_dir)

        File.write(File.join(static_dir, "js", "util.js"), "function log(msg) { console.log(msg); }")
        File.write(File.join(static_dir, "js", "app.js"), "log('hello');")

        config = Hwaro::Models::AssetsConfig.new
        config.enabled = true
        config.minify = false
        config.fingerprint = false
        config.source_dir = static_dir
        config.bundles << Hwaro::Models::AssetBundleConfig.new(
          name: "app.js",
          files: ["js/util.js", "js/app.js"]
        )

        pipeline = Hwaro::Assets::Pipeline.new(config, "")
        pipeline.process(output_dir)

        output_file = File.join(output_dir, "assets", "app.js")
        File.exists?(output_file).should be_true
        content = File.read(output_file)
        content.should contain("console.log")
        content.should contain("log('hello')")
      end
    end

    it "minifies CSS bundles" do
      Dir.mktmpdir do |dir|
        static_dir = File.join(dir, "static")
        output_dir = File.join(dir, "public")
        FileUtils.mkdir_p(static_dir)
        FileUtils.mkdir_p(output_dir)

        File.write(File.join(static_dir, "style.css"), "body {\n  color: red;\n  /* comment */\n}")

        config = Hwaro::Models::AssetsConfig.new
        config.enabled = true
        config.minify = true
        config.fingerprint = false
        config.source_dir = static_dir
        config.bundles << Hwaro::Models::AssetBundleConfig.new(
          name: "style.css",
          files: ["style.css"]
        )

        pipeline = Hwaro::Assets::Pipeline.new(config, "")
        pipeline.process(output_dir)

        content = File.read(File.join(output_dir, "assets", "style.css"))
        content.should_not contain("/* comment */")
        content.should_not contain("\n")
      end
    end

    it "generates fingerprinted filenames" do
      Dir.mktmpdir do |dir|
        static_dir = File.join(dir, "static")
        output_dir = File.join(dir, "public")
        FileUtils.mkdir_p(static_dir)
        FileUtils.mkdir_p(output_dir)

        File.write(File.join(static_dir, "style.css"), "body { color: red; }")

        config = Hwaro::Models::AssetsConfig.new
        config.enabled = true
        config.minify = false
        config.fingerprint = true
        config.source_dir = static_dir
        config.bundles << Hwaro::Models::AssetBundleConfig.new(
          name: "style.css",
          files: ["style.css"]
        )

        pipeline = Hwaro::Assets::Pipeline.new(config, "")
        pipeline.process(output_dir)

        # Manifest should have the fingerprinted path
        pipeline.manifest.has_key?("style.css").should be_true
        manifest_path = pipeline.manifest["style.css"]
        manifest_path.should match(/\/assets\/style\.[a-f0-9]{8}\.css/)

        # File should exist on disk
        output_file = File.join(output_dir, manifest_path.lstrip("/"))
        File.exists?(output_file).should be_true
      end
    end

    it "produces consistent fingerprints for same content" do
      Dir.mktmpdir do |dir|
        static_dir = File.join(dir, "static")
        output_dir = File.join(dir, "public")
        FileUtils.mkdir_p(static_dir)
        FileUtils.mkdir_p(output_dir)

        File.write(File.join(static_dir, "a.css"), "body { color: blue; }")

        config = Hwaro::Models::AssetsConfig.new
        config.enabled = true
        config.fingerprint = true
        config.minify = false
        config.source_dir = static_dir
        config.bundles << Hwaro::Models::AssetBundleConfig.new(name: "a.css", files: ["a.css"])

        p1 = Hwaro::Assets::Pipeline.new(config, "")
        p1.process(output_dir)

        p2 = Hwaro::Assets::Pipeline.new(config, "")
        p2.process(output_dir)

        p1.manifest["a.css"].should eq(p2.manifest["a.css"])
      end
    end

    it "does nothing when disabled" do
      config = Hwaro::Models::AssetsConfig.new
      config.enabled = false

      pipeline = Hwaro::Assets::Pipeline.new(config, "")
      pipeline.process("/nonexistent")
      pipeline.manifest.empty?.should be_true
    end

    it "warns on missing source file" do
      Dir.mktmpdir do |dir|
        output_dir = File.join(dir, "public")
        FileUtils.mkdir_p(output_dir)

        config = Hwaro::Models::AssetsConfig.new
        config.enabled = true
        config.minify = false
        config.fingerprint = false
        config.source_dir = dir
        config.bundles << Hwaro::Models::AssetBundleConfig.new(
          name: "missing.css",
          files: ["nonexistent.css"]
        )

        pipeline = Hwaro::Assets::Pipeline.new(config, "")
        pipeline.process(output_dir)

        # Should not crash, manifest should not have the bundle
        pipeline.manifest.has_key?("missing.css").should be_false
      end
    end
  end
end
