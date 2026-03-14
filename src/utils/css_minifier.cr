# CSS minification utilities
#
# Provides conservative CSS minification that removes unnecessary
# whitespace and comments while preserving functional correctness.
#
# Operations:
# - Remove CSS comments (/* ... */)
# - Collapse whitespace
# - Remove whitespace around structural characters
# - Strip trailing semicolons before }

module Hwaro
  module Utils
    module CssMinifier
      extend self

      # Perform conservative CSS minification
      def minify(css : String) : String
        result = css

        # Remove comments
        result = result.gsub(/\/\*.*?\*\//m, "")

        # Collapse whitespace (newlines, tabs, multiple spaces → single space)
        result = result.gsub(/\s+/, " ")

        # Remove space around structural characters
        result = result.gsub(/\s*\{\s*/, "{")
        result = result.gsub(/\s*\}\s*/, "}")
        result = result.gsub(/\s*:\s*/, ":")
        result = result.gsub(/\s*;\s*/, ";")
        result = result.gsub(/\s*,\s*/, ",")

        # Strip trailing semicolons before }
        result = result.gsub(/;\}/, "}")

        result.strip
      end
    end
  end
end
