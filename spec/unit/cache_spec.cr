require "../spec_helper"

describe Hwaro::Core::Build::Cache do
  describe "#initialize" do
    it "creates a disabled cache by default when disabled" do
      cache = Hwaro::Core::Build::Cache.new(enabled: false)
      cache.enabled?.should be_false
    end

    it "creates an enabled cache when specified" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.enabled?.should be_true
      end
    end
  end

  describe "#changed?" do
    it "returns true when cache is disabled" do
      cache = Hwaro::Core::Build::Cache.new(enabled: false)
      cache.changed?("any/path.md").should be_true
    end

    it "returns true for non-existent file" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.changed?("non_existent_file.md").should be_true
      end
    end

    it "returns true for file not in cache" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "content")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.changed?(test_file).should be_true
      end
    end

    it "returns false for unchanged file in cache" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "content")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(test_file)
        cache.changed?(test_file).should be_false
      end
    end

    it "returns true when file content changes" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "original content")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(test_file)

        # Modify file content and update mtime
        sleep 10.milliseconds # Ensure different mtime
        File.write(test_file, "modified content")

        cache.changed?(test_file).should be_true
      end
    end

    it "returns true when output file does not exist" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        output_file = File.join(dir, "output.html")
        File.write(test_file, "content")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(test_file, output_file)

        # Check with non-existent output
        cache.changed?(test_file, output_file).should be_true
      end
    end
  end

  describe "#update" do
    it "does nothing when cache is disabled" do
      cache = Hwaro::Core::Build::Cache.new(enabled: false)
      # Should not raise
      cache.update("any/path.md")
    end

    it "stores file entry in cache" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "content")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(test_file)

        # File should now be considered unchanged
        cache.changed?(test_file).should be_false
      end
    end

    it "stores output path with entry" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        output_file = File.join(dir, "output.html")
        File.write(test_file, "content")
        File.write(output_file, "<p>content</p>")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(test_file, output_file)

        cache.changed?(test_file, output_file).should be_false
      end
    end
  end

  describe "#invalidate" do
    it "removes file from cache" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "content")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(test_file)
        cache.changed?(test_file).should be_false

        cache.invalidate(test_file)
        cache.changed?(test_file).should be_true
      end
    end
  end

  describe "#clear" do
    it "removes all entries from cache" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file1 = File.join(dir, "test1.md")
        test_file2 = File.join(dir, "test2.md")
        File.write(test_file1, "content1")
        File.write(test_file2, "content2")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(test_file1)
        cache.update(test_file2)
        cache.save

        cache.clear

        cache.stats[:total].should eq(0)
        File.exists?(cache_path).should be_false
      end
    end
  end

  describe "#save and #load" do
    it "persists cache to disk" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "content")

        # Create and save cache
        cache1 = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache1.update(test_file)
        cache1.save

        File.exists?(cache_path).should be_true

        # Load cache in new instance
        cache2 = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache2.changed?(test_file).should be_false
      end
    end

    it "loads legacy cache format (plain array without metadata)" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "content")
        mtime = File.info(test_file).modification_time.to_unix_ms

        # Write legacy format: plain array of entries without template_hash/config_hash
        legacy_json = %([{"path":"#{test_file}","mtime":#{mtime},"hash":"","output_path":""}])
        File.write(cache_path, legacy_json)

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.stats[:total].should eq(1)
        cache.changed?(test_file).should be_false
      end
    end

    it "loads new format entries that are missing optional fields" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        test_file = File.join(dir, "test.md")
        File.write(test_file, "content")
        mtime = File.info(test_file).modification_time.to_unix_ms

        # New format with metadata, but entries lack template_hash/config_hash
        new_json = %({
          "metadata":{"template_hash":"abc","config_hash":"def"},
          "entries":[{"path":"#{test_file}","mtime":#{mtime},"hash":"","output_path":""}]
        })
        File.write(cache_path, new_json)

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.stats[:total].should eq(1)
        cache.changed?(test_file).should be_false
      end
    end

    it "handles corrupted cache file gracefully" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        File.write(cache_path, "invalid json content{{{")

        # Should not raise, just start with empty cache
        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.stats[:total].should eq(0)
      end
    end

    it "does not save when disabled" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")

        cache = Hwaro::Core::Build::Cache.new(enabled: false, cache_path: cache_path)
        cache.save

        File.exists?(cache_path).should be_false
      end
    end
  end

  describe "#filter_changed" do
    it "returns all files when cache is disabled" do
      cache = Hwaro::Core::Build::Cache.new(enabled: false)
      files = ["a.md", "b.md", "c.md"]
      cache.filter_changed(files).should eq(files)
    end

    it "returns only changed files" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        file1 = File.join(dir, "unchanged.md")
        file2 = File.join(dir, "changed.md")
        file3 = File.join(dir, "new.md")

        File.write(file1, "content1")
        File.write(file2, "content2")
        File.write(file3, "content3")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(file1)
        cache.update(file2)

        # Modify file2
        sleep 10.milliseconds
        File.write(file2, "modified content2")

        changed = cache.filter_changed([file1, file2, file3])
        changed.should contain(file2)
        changed.should contain(file3)
        changed.should_not contain(file1)
      end
    end
  end

  describe "#stats" do
    it "returns correct statistics" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        file1 = File.join(dir, "exists.md")
        file2 = File.join(dir, "deleted.md")

        File.write(file1, "content1")
        File.write(file2, "content2")

        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.update(file1)
        cache.update(file2)

        # Delete one file
        File.delete(file2)

        stats = cache.stats
        stats[:total].should eq(2)
        stats[:valid].should eq(1)
      end
    end
  end

  describe "#enabled?" do
    it "returns true when enabled" do
      Dir.mktmpdir do |dir|
        cache_path = File.join(dir, ".hwaro_cache.json")
        cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
        cache.enabled?.should be_true
      end
    end

    it "returns false when disabled" do
      cache = Hwaro::Core::Build::Cache.new(enabled: false)
      cache.enabled?.should be_false
    end
  end
end

describe Hwaro::Core::Build::CacheEntry do
  it "serializes and deserializes to JSON" do
    entry = Hwaro::Core::Build::CacheEntry.new(
      path: "test.md",
      mtime: 1234567890_i64,
      hash: "abc123",
      output_path: "test.html",
      template_hash: "tmpl_hash",
      config_hash: "cfg_hash",
    )

    json = entry.to_json
    restored = Hwaro::Core::Build::CacheEntry.from_json(json)

    restored.path.should eq("test.md")
    restored.mtime.should eq(1234567890_i64)
    restored.hash.should eq("abc123")
    restored.output_path.should eq("test.html")
    restored.template_hash.should eq("tmpl_hash")
    restored.config_hash.should eq("cfg_hash")
  end
end

describe Hwaro::Core::Build::Cache, "global checksums" do
  it "invalidates all entries when template hash changes" do
    Dir.mktmpdir do |dir|
      cache_path = File.join(dir, ".hwaro_cache.json")
      test_file = File.join(dir, "test.md")
      File.write(test_file, "content")

      cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
      cache.set_global_checksums("tmpl_v1", "cfg_v1")
      cache.update(test_file)
      cache.save

      # Reload with different template hash
      cache2 = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
      cache2.set_global_checksums("tmpl_v2", "cfg_v1")

      cache2.changed?(test_file).should be_true
    end
  end

  it "invalidates all entries when config hash changes" do
    Dir.mktmpdir do |dir|
      cache_path = File.join(dir, ".hwaro_cache.json")
      test_file = File.join(dir, "test.md")
      File.write(test_file, "content")

      cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
      cache.set_global_checksums("tmpl_v1", "cfg_v1")
      cache.update(test_file)
      cache.save

      # Reload with different config hash
      cache2 = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
      cache2.set_global_checksums("tmpl_v1", "cfg_v2")

      cache2.changed?(test_file).should be_true
    end
  end

  it "preserves entries when checksums are unchanged" do
    Dir.mktmpdir do |dir|
      cache_path = File.join(dir, ".hwaro_cache.json")
      test_file = File.join(dir, "test.md")
      File.write(test_file, "content")

      cache = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
      cache.set_global_checksums("tmpl_v1", "cfg_v1")
      cache.update(test_file)
      cache.save

      # Reload with same checksums
      cache2 = Hwaro::Core::Build::Cache.new(enabled: true, cache_path: cache_path)
      cache2.set_global_checksums("tmpl_v1", "cfg_v1")

      cache2.changed?(test_file).should be_false
    end
  end
end

describe Hwaro::Core::Build::Cache, "compute helpers" do
  it "computes consistent template hash" do
    templates = {"page" => "<p>{{ content }}</p>", "default" => "<html>{{ content }}</html>"}
    hash1 = Hwaro::Core::Build::Cache.compute_templates_hash(templates)
    hash2 = Hwaro::Core::Build::Cache.compute_templates_hash(templates)
    hash1.should eq(hash2)
  end

  it "produces different hash for different templates" do
    t1 = {"page" => "<p>v1</p>"}
    t2 = {"page" => "<p>v2</p>"}
    Hwaro::Core::Build::Cache.compute_templates_hash(t1).should_not eq(
      Hwaro::Core::Build::Cache.compute_templates_hash(t2)
    )
  end

  it "computes config hash from file" do
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.toml")
      File.write(config_path, "title = \"test\"")
      hash = Hwaro::Core::Build::Cache.compute_config_hash(config_path)
      hash.should_not be_empty
    end
  end

  it "returns empty string for missing config" do
    Hwaro::Core::Build::Cache.compute_config_hash("/nonexistent/config.toml").should eq("")
  end
end
