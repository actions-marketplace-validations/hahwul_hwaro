# Convert command for converting frontmatter formats
#
# This command converts frontmatter in content files between YAML and TOML formats.
# Usage:
#   hwaro tool convert to-yaml  - Convert all frontmatter to YAML format
#   hwaro tool convert to-toml  - Convert all frontmatter to TOML format

require "json"
require "option_parser"
require "../../metadata"
require "../../../services/frontmatter_converter"
require "../../../utils/logger"

module Hwaro
  module CLI
    module Commands
      module Tool
        class ConvertCommand
          # Single source of truth for command metadata
          NAME               = "convert"
          DESCRIPTION        = "Convert frontmatter format (YAML <-> TOML)"
          POSITIONAL_ARGS    = ["format"]
          POSITIONAL_CHOICES = ["to-yaml", "to-toml"]

          # Flags defined here are used both for OptionParser and completion generation
          FLAGS = [
            FlagInfo.new(short: "-c", long: "--content-dir", description: "Content directory (default: content)", takes_value: true, value_hint: "DIR"),
            JSON_FLAG,
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
            content_dir = "content"
            format : String? = nil
            json_output = false

            OptionParser.parse(args) do |parser|
              parser.banner = "Usage: hwaro tool convert <to-yaml|to-toml> [options]"
              parser.on("-c DIR", "--content-dir DIR", "Content directory (default: content)") { |dir| content_dir = dir }
              parser.on("-j", "--json", "Output result as JSON") { json_output = true }
              parser.on("-h", "--help", "Show this help") { Logger.info parser.to_s; exit }
              parser.unknown_args do |unknown|
                format = unknown.first? if unknown.any?
              end
            end

            unless format
              Logger.error "Missing format argument. Use 'to-yaml' or 'to-toml'"
              Logger.info ""
              Logger.info "Usage: hwaro tool convert <to-yaml|to-toml> [options]"
              Logger.info ""
              Logger.info "Examples:"
              Logger.info "  hwaro tool convert to-yaml"
              Logger.info "  hwaro tool convert to-toml"
              Logger.info "  hwaro tool convert to-yaml --content-dir=posts"
              exit(1)
            end

            converter = Services::FrontmatterConverter.new(content_dir)

            case format.not_nil!.downcase
            when "to-yaml"
              result = converter.convert_to_yaml
              if json_output
                puts result.to_json
              end
              exit(1) unless result.success
            when "to-toml"
              result = converter.convert_to_toml
              if json_output
                puts result.to_json
              end
              exit(1) unless result.success
            else
              Logger.error "Unknown format: #{format}"
              Logger.info "Use 'to-yaml' or 'to-toml'"
              exit(1)
            end
          end
        end
      end
    end
  end
end
