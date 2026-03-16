# Image processing hooks for build lifecycle
#
# Processes images during the Write phase, generating resized variants
# for configured widths. The resized image map is exposed to the
# `resize_image()` template function.

require "../../core/lifecycle"
require "../processors/image_processor"

module Hwaro
  module Content
    module Hooks
      class ImageHooks
        include Core::Lifecycle::Hookable

        # Class-level map: original_url => { width => resized_url }
        @@resize_map = {} of String => Hash(Int32, String)
        @@resize_map_mutex = Mutex.new

        def register_hooks(manager : Core::Lifecycle::Manager)
          manager.on(Core::Lifecycle::HookPoint::AfterWrite, priority: 30, name: "image:resize") do |ctx|
            process_images(ctx)
            Core::Lifecycle::HookResult::Continue
          end
        end

        def self.resize_map : Hash(String, Hash(Int32, String))
          @@resize_map_mutex.synchronize { @@resize_map }
        end

        def self.find_resized(url : String, width : Int32) : String?
          @@resize_map_mutex.synchronize do
            @@resize_map[url]?.try { |m| m[width]? }
          end
        end

        def self.find_closest(url : String, width : Int32) : String?
          @@resize_map_mutex.synchronize do
            widths_map = @@resize_map[url]?
            return nil unless widths_map
            return widths_map[width] if widths_map.has_key?(width)

            # Find the smallest width that is >= requested
            best_key = nil
            widths_map.each_key do |w|
              if w >= width
                if best_key.nil? || w < best_key
                  best_key = w
                end
              end
            end
            # If nothing bigger, pick the largest available
            best_key ||= widths_map.keys.max?
            best_key ? widths_map[best_key] : nil
          end
        end

        private def process_images(ctx : Core::Lifecycle::BuildContext)
          config = ctx.config
          return unless config
          return unless config.image_processing.enabled
          return if config.image_processing.widths.empty?

          widths = config.image_processing.widths
          quality = config.image_processing.quality
          output_dir = ctx.output_dir
          resized_count = 0
          new_map = {} of String => Hash(Int32, String)

          # Process co-located page assets
          ctx.all_pages.each do |page|
            next if page.assets.empty?

            page_bundle_dir = File.dirname(page.path)
            url_path = page.url.lchop("/")
            dest_dir = File.join(output_dir, url_path)

            page.assets.each do |asset_path|
              next unless Processors::ImageProcessor.image?(asset_path)

              source_path = File.join("content", asset_path)
              next unless File.exists?(source_path)

              relative_to_bundle = Path[asset_path].relative_to(page_bundle_dir)
              original_url = "/" + url_path + relative_to_bundle.to_s
              asset_dest_dir = File.join(dest_dir, File.dirname(relative_to_bundle.to_s))

              width_map = {} of Int32 => String
              widths.each do |width|
                resized_name = Processors::ImageProcessor.resized_filename(File.basename(asset_path), width)
                dest_path = File.join(asset_dest_dir, resized_name)
                if Processors::ImageProcessor.resize(source_path, dest_path, width, 0, quality)
                  resized_url = "/" + url_path + File.join(File.dirname(relative_to_bundle.to_s), resized_name)
                  width_map[width] = resized_url
                  resized_count += 1
                end
              end
              new_map[original_url] = width_map unless width_map.empty?
            end
          end

          # Process content files (non-page-bundle images)
          if config.content_files.enabled?
            process_content_file_images(config, output_dir, widths, quality, new_map)
          end

          # Process static directory images
          process_static_images(output_dir, widths, quality, new_map)

          @@resize_map_mutex.synchronize { @@resize_map = new_map }
          resized_count = new_map.values.sum(&.size)
          Logger.success "  Generated #{resized_count} resized image(s)." if resized_count > 0
        end

        private def process_content_file_images(
          config : Models::Config,
          output_dir : String,
          widths : Array(Int32),
          quality : Int32,
          new_map : Hash(String, Hash(Int32, String)),
        )
          Dir.glob(File.join("content", "**", "*")).each do |file|
            next unless File.file?(file)
            next unless Processors::ImageProcessor.image?(file)
            relative = Path[file].relative_to("content").to_s
            next unless config.content_files.publish?(relative)

            original_url = "/" + relative
            dest_dir = File.join(output_dir, File.dirname(relative))

            width_map = {} of Int32 => String
            widths.each do |width|
              resized_name = Processors::ImageProcessor.resized_filename(File.basename(file), width)
              dest_path = File.join(dest_dir, resized_name)
              if Processors::ImageProcessor.resize(file, dest_path, width, 0, quality)
                resized_url = "/" + File.join(File.dirname(relative), resized_name)
                width_map[width] = resized_url
              end
            end
            new_map[original_url] = width_map unless width_map.empty?
          end
        end

        private def process_static_images(
          output_dir : String,
          widths : Array(Int32),
          quality : Int32,
          new_map : Hash(String, Hash(Int32, String)),
        )
          return unless Dir.exists?("static")

          Dir.glob(File.join("static", "**", "*")).each do |file|
            next unless File.file?(file)
            next unless Processors::ImageProcessor.image?(file)

            relative = Path[file].relative_to("static").to_s
            original_url = "/" + relative
            dest_dir = File.join(output_dir, File.dirname(relative))

            width_map = {} of Int32 => String
            widths.each do |width|
              resized_name = Processors::ImageProcessor.resized_filename(File.basename(file), width)
              dest_path = File.join(dest_dir, resized_name)
              if Processors::ImageProcessor.resize(file, dest_path, width, 0, quality)
                resized_url = "/" + File.join(File.dirname(relative), resized_name)
                width_map[width] = resized_url
              end
            end
            new_map[original_url] = width_map unless width_map.empty?
          end
        end
      end
    end
  end
end
