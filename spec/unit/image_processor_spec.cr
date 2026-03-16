require "../spec_helper"
require "../../src/content/processors/image_processor"

describe Hwaro::Content::Processors::ImageProcessor do
  describe ".image?" do
    it "returns true for supported image extensions" do
      Hwaro::Content::Processors::ImageProcessor.image?("photo.jpg").should be_true
      Hwaro::Content::Processors::ImageProcessor.image?("photo.jpeg").should be_true
      Hwaro::Content::Processors::ImageProcessor.image?("icon.png").should be_true
      Hwaro::Content::Processors::ImageProcessor.image?("scan.bmp").should be_true
    end

    it "returns false for unsupported formats" do
      Hwaro::Content::Processors::ImageProcessor.image?("anim.gif").should be_false
      Hwaro::Content::Processors::ImageProcessor.image?("pic.webp").should be_false
      Hwaro::Content::Processors::ImageProcessor.image?("raw.tiff").should be_false
      Hwaro::Content::Processors::ImageProcessor.image?("photo.tga").should be_false
    end

    it "returns false for non-image files" do
      Hwaro::Content::Processors::ImageProcessor.image?("style.css").should be_false
      Hwaro::Content::Processors::ImageProcessor.image?("script.js").should be_false
      Hwaro::Content::Processors::ImageProcessor.image?("page.md").should be_false
      Hwaro::Content::Processors::ImageProcessor.image?("data.json").should be_false
    end

    it "is case insensitive" do
      Hwaro::Content::Processors::ImageProcessor.image?("PHOTO.JPG").should be_true
      Hwaro::Content::Processors::ImageProcessor.image?("Image.PNG").should be_true
    end
  end

  describe ".resized_filename" do
    it "generates width-based filename" do
      Hwaro::Content::Processors::ImageProcessor.resized_filename("photo.jpg", 800).should eq("photo_800w.jpg")
    end

    it "preserves directory path" do
      Hwaro::Content::Processors::ImageProcessor.resized_filename("images/photo.png", 320).should eq("images/photo_320w.png")
    end

    it "handles filenames with dots" do
      Hwaro::Content::Processors::ImageProcessor.resized_filename("my.photo.jpg", 640).should eq("my.photo_640w.jpg")
    end
  end

  describe ".resize" do
    it "resizes a PNG image" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "test.png")
        dest = File.join(dir, "test_2w.png")

        # Write a 4x4 solid color PNG via stb
        pixels = Bytes.new(4 * 4 * 3, 255_u8)
        LibStb.stbi_write_png(src, 4, 4, 3, pixels.to_unsafe.as(Void*), 4 * 3)

        result = Hwaro::Content::Processors::ImageProcessor.resize(src, dest, 2, 0, 85)
        result.should eq(dest)
        File.exists?(dest).should be_true

        # Verify the output dimensions
        w = uninitialized LibC::Int
        h = uninitialized LibC::Int
        c = uninitialized LibC::Int
        out_pixels = LibStb.stbi_load(dest, pointerof(w), pointerof(h), pointerof(c), 0)
        out_pixels.null?.should be_false
        w.should eq(2)
        h.should eq(2)
        LibStb.stbi_image_free(out_pixels.as(Void*))
      end
    end

    it "resizes a JPG image" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "test.jpg")
        dest = File.join(dir, "test_2w.jpg")

        pixels = Bytes.new(4 * 4 * 3, 128_u8)
        LibStb.stbi_write_jpg(src, 4, 4, 3, pixels.to_unsafe.as(Void*), 90)

        result = Hwaro::Content::Processors::ImageProcessor.resize(src, dest, 2, 0, 85)
        result.should eq(dest)
        File.exists?(dest).should be_true
      end
    end

    it "returns nil for non-existent file" do
      result = Hwaro::Content::Processors::ImageProcessor.resize("/nonexistent.png", "/tmp/out.png", 100)
      result.should be_nil
    end

    it "copies file when target width >= source width" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "small.png")
        dest = File.join(dir, "small_1000w.png")

        pixels = Bytes.new(4 * 4 * 3, 200_u8)
        LibStb.stbi_write_png(src, 4, 4, 3, pixels.to_unsafe.as(Void*), 4 * 3)

        result = Hwaro::Content::Processors::ImageProcessor.resize(src, dest, 1000, 0, 85)
        result.should eq(dest)
        File.exists?(dest).should be_true
        # Should be a copy (same size as source)
        File.size(dest).should eq(File.size(src))
      end
    end

    it "clamps quality to valid range" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "test.jpg")
        dest = File.join(dir, "test_2w.jpg")

        pixels = Bytes.new(4 * 4 * 3, 100_u8)
        LibStb.stbi_write_jpg(src, 4, 4, 3, pixels.to_unsafe.as(Void*), 90)

        # quality = 0 should be clamped to 1, not crash
        result = Hwaro::Content::Processors::ImageProcessor.resize(src, dest, 2, 0, 0)
        result.should eq(dest)
      end
    end

    it "preserves aspect ratio with width-only resize" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "wide.png")
        dest = File.join(dir, "wide_5w.png")

        # Create 10x4 image
        pixels = Bytes.new(10 * 4 * 3, 150_u8)
        LibStb.stbi_write_png(src, 10, 4, 3, pixels.to_unsafe.as(Void*), 10 * 3)

        result = Hwaro::Content::Processors::ImageProcessor.resize(src, dest, 5, 0, 85)
        result.should eq(dest)

        w = uninitialized LibC::Int
        h = uninitialized LibC::Int
        c = uninitialized LibC::Int
        out_pixels = LibStb.stbi_load(dest, pointerof(w), pointerof(h), pointerof(c), 0)
        out_pixels.null?.should be_false
        w.should eq(5)
        h.should eq(2) # 4 * (5/10) = 2
        LibStb.stbi_image_free(out_pixels.as(Void*))
      end
    end
  end
end

describe Hwaro::Models::ImageProcessingConfig do
  it "has sensible defaults" do
    config = Hwaro::Models::ImageProcessingConfig.new
    config.enabled.should be_false
    config.widths.should eq([] of Int32)
    config.quality.should eq(85)
  end
end

describe "Config.load image_processing" do
  it "loads image_processing from TOML" do
    Dir.cd(Dir.tempdir) do
      File.write("config.toml", <<-TOML
        title = "Test"
        [image_processing]
        enabled = true
        widths = [320, 640, 1024]
        quality = 90
        TOML
      )
      config = Hwaro::Models::Config.load
      config.image_processing.enabled.should be_true
      config.image_processing.widths.should eq([320, 640, 1024])
      config.image_processing.quality.should eq(90)
    end
  end

  it "uses defaults when not specified" do
    Dir.cd(Dir.tempdir) do
      File.write("config.toml", "title = \"Test\"")
      config = Hwaro::Models::Config.load
      config.image_processing.enabled.should be_false
      config.image_processing.widths.should eq([] of Int32)
      config.image_processing.quality.should eq(85)
    end
  end

  it "filters out zero and negative widths" do
    Dir.cd(Dir.tempdir) do
      File.write("config.toml", <<-TOML
        title = "Test"
        [image_processing]
        enabled = true
        widths = [0, -100, 320, 640]
        TOML
      )
      config = Hwaro::Models::Config.load
      config.image_processing.widths.should eq([320, 640])
    end
  end

  it "clamps quality to 1-100" do
    Dir.cd(Dir.tempdir) do
      File.write("config.toml", <<-TOML
        title = "Test"
        [image_processing]
        quality = 0
        TOML
      )
      config = Hwaro::Models::Config.load
      config.image_processing.quality.should eq(1)
    end
  end
end
