require "option_parser"
require "../../metadata"
require "../../../config/options/import_options"
require "../../../services/importers/base"
require "../../../services/importers/html_to_markdown"
require "../../../services/importers/wordpress_importer"
require "../../../services/importers/jekyll_importer"
require "../../../services/importers/hugo_importer"
require "../../../utils/logger"

module Hwaro
  module CLI
    module Commands
      module Tool
        class ImportCommand
          NAME               = "import"
          DESCRIPTION        = "Import content from WordPress, Jekyll, or Hugo"
          POSITIONAL_ARGS    = ["source-type", "path"]
          POSITIONAL_CHOICES = ["wordpress", "jekyll", "hugo"]

          FLAGS = [
            FlagInfo.new(short: "-o", long: "--output", description: "Output content directory (default: content)", takes_value: true, value_hint: "DIR"),
            FlagInfo.new(short: "-d", long: "--drafts", description: "Include draft content"),
            FlagInfo.new(short: "-v", long: "--verbose", description: "Show detailed output"),
            HELP_FLAG,
          ]

          def self.metadata : CommandInfo
            CommandInfo.new(
              name: NAME,
              description: DESCRIPTION,
              flags: FLAGS,
              positional_args: POSITIONAL_ARGS,
              positional_choices: POSITIONAL_CHOICES
            )
          end

          def run(args : Array(String))
            options = parse_options(args)

            if options.source_type.empty?
              Logger.error "Missing source type. Usage: hwaro tool import <wordpress|jekyll|hugo> <path>"
              exit(1)
            end

            if options.path.empty?
              Logger.error "Missing path. Usage: hwaro tool import #{options.source_type} <path>"
              exit(1)
            end

            importer = case options.source_type
                       when "wordpress"
                         Services::Importers::WordPressImporter.new
                       when "jekyll"
                         Services::Importers::JekyllImporter.new
                       when "hugo"
                         Services::Importers::HugoImporter.new
                       else
                         Logger.error "Unknown source type: #{options.source_type}"
                         Logger.info "Supported: wordpress, jekyll, hugo"
                         exit(1)
                       end

            Logger.info "Importing from #{options.source_type}: #{options.path}"
            Logger.info "Output directory: #{options.output_dir}"

            result = importer.run(options)

            if result.success
              Logger.success "Import complete: #{result.imported_count} imported, #{result.skipped_count} skipped, #{result.error_count} errors"
            else
              Logger.error "Import failed: #{result.message}"
              exit(1)
            end
          end

          private def parse_options(args : Array(String)) : Config::Options::ImportOptions
            output_dir = "content"
            drafts = false
            verbose = false
            positional = [] of String

            OptionParser.parse(args) do |parser|
              parser.banner = "Usage: hwaro tool import <wordpress|jekyll|hugo> <path> [options]"
              parser.on("-o DIR", "--output DIR", "Output content directory (default: content)") { |dir| output_dir = dir }
              parser.on("-d", "--drafts", "Include draft content") { drafts = true }
              parser.on("-v", "--verbose", "Show detailed output") { verbose = true }
              parser.on("-h", "--help", "Show this help") { Logger.info parser.to_s; exit }
              parser.unknown_args do |remaining|
                positional = remaining
              end
            end

            source_type = positional.shift? || ""
            path = positional.shift? || ""

            Config::Options::ImportOptions.new(
              source_type: source_type,
              path: path,
              output_dir: output_dir,
              drafts: drafts,
              verbose: verbose,
            )
          end
        end
      end
    end
  end
end
