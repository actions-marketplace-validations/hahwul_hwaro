require "json"
require "../../models/config"
require "../../models/page"

module Hwaro
  module Content
    module Seo
      module JsonLd
        extend self

        # Generate Article JSON-LD for a page
        def article(page : Models::Page, config : Models::Config) : String
          base = config.base_url.rstrip("/")
          url = page.permalink || "#{base}#{page.url.starts_with?("/") ? page.url : "/#{page.url}"}"

          data = {
            "@context"      => "https://schema.org",
            "@type"         => "Article",
            "headline"      => page.title,
            "url"           => url,
            "datePublished" => page.date.try(&.to_s("%Y-%m-%dT%H:%M:%S%:z")) || "",
          }

          if updated = page.updated
            data["dateModified"] = updated.to_s("%Y-%m-%dT%H:%M:%S%:z")
          end

          if desc = page.description
            data["description"] = desc
          end

          if image = page.image
            img_url = image.starts_with?("http") ? image : "#{base}#{image.starts_with?("/") ? image : "/#{image}"}"
            data["image"] = img_url
          end

          unless page.authors.empty?
            # Use first author for simplicity
            data["author"] = {
              "@type" => "Person",
              "name"  => page.authors.first,
            }.to_json
          end

          wrap_script(data)
        end

        # Generate BreadcrumbList JSON-LD from page ancestors
        def breadcrumb(page : Models::Page, config : Models::Config) : String
          base = config.base_url.rstrip("/")

          items = [] of Hash(String, String | Int32)

          # Home
          items << {
            "@type"    => "ListItem",
            "position" => 1,
            "name"     => config.title,
            "item"     => "#{base}/",
          }

          # Ancestors
          page.ancestors.each_with_index do |ancestor, idx|
            ancestor_url = "#{base}#{ancestor.url.starts_with?("/") ? ancestor.url : "/#{ancestor.url}"}"
            items << {
              "@type"    => "ListItem",
              "position" => idx + 2,
              "name"     => ancestor.title,
              "item"     => ancestor_url,
            }
          end

          # Current page (last item, no "item" URL per spec recommendation)
          items << {
            "@type"    => "ListItem",
            "position" => items.size + 1,
            "name"     => page.title,
          }

          json = JSON.build do |json|
            json.object do
              json.field "@context", "https://schema.org"
              json.field "@type", "BreadcrumbList"
              json.field "itemListElement" do
                json.array do
                  items.each do |item|
                    json.object do
                      item.each do |k, v|
                        json.field k, v
                      end
                    end
                  end
                end
              end
            end
          end

          %(<script type="application/ld+json">#{json}</script>)
        end

        # Generate both Article + BreadcrumbList JSON-LD
        def all_tags(page : Models::Page, config : Models::Config) : String
          parts = [] of String
          parts << article(page, config)
          parts << breadcrumb(page, config) unless page.ancestors.empty? && page.is_index
          parts.join("\n")
        end

        private def wrap_script(data : Hash) : String
          # Build JSON manually to avoid nested JSON encoding of author
          json = JSON.build do |json|
            json.object do
              data.each do |k, v|
                if k == "author" && v.is_a?(String) && v.starts_with?("{")
                  json.field k do
                    json.raw v
                  end
                else
                  json.field k, v
                end
              end
            end
          end
          %(<script type="application/ld+json">#{json}</script>)
        end
      end
    end
  end
end
