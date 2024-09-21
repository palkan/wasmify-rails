module Rails
  module HTML
    class Scrubber
      CONTINUE = Object.new.freeze

      attr_accessor :tags, :attributes
      attr_reader :prune

      def initialize(**)
      end

      def scrub(node) = CONTINUE
    end

    PermitScrubber = Scrubber
    TargetScrubber = Scrubber
    TextOnlyScrubber = Scrubber

    class Sanitizer
      class << self
        def html5_support? = true
        def best_supported_vendor = NullSanitizer
      end
    end

    module Concern
      module SafeList
        # The default safe list for tags
        DEFAULT_ALLOWED_TAGS = Set.new([
                                          "a",
                                          "abbr",
                                          "acronym",
                                          "address",
                                          "b",
                                          "big",
                                          "blockquote",
                                          "br",
                                          "cite",
                                          "code",
                                          "dd",
                                          "del",
                                          "dfn",
                                          "div",
                                          "dl",
                                          "dt",
                                          "em",
                                          "h1",
                                          "h2",
                                          "h3",
                                          "h4",
                                          "h5",
                                          "h6",
                                          "hr",
                                          "i",
                                          "img",
                                          "ins",
                                          "kbd",
                                          "li",
                                          "mark",
                                          "ol",
                                          "p",
                                          "pre",
                                          "samp",
                                          "small",
                                          "span",
                                          "strong",
                                          "sub",
                                          "sup",
                                          "time",
                                          "tt",
                                          "ul",
                                          "var",
                                        ]).freeze

        # The default safe list for attributes
        DEFAULT_ALLOWED_ATTRIBUTES = Set.new([
                                                "abbr",
                                                "alt",
                                                "cite",
                                                "class",
                                                "datetime",
                                                "height",
                                                "href",
                                                "lang",
                                                "name",
                                                "src",
                                                "title",
                                                "width",
                                                "xml:lang",
                                              ]).freeze

        def self.included(klass)
          class << klass
            attr_accessor :allowed_tags
            attr_accessor :allowed_attributes
          end

          klass.allowed_tags = DEFAULT_ALLOWED_TAGS.dup
          klass.allowed_attributes = DEFAULT_ALLOWED_ATTRIBUTES.dup
        end

        def initialize(prune: false)
          @permit_scrubber = PermitScrubber.new(prune: prune)
        end

        def scrub(fragment, options = {})
          if scrubber = options[:scrubber]
            # No duck typing, Loofah ensures subclass of Loofah::Scrubber
            fragment.scrub!(scrubber)
          elsif allowed_tags(options) || allowed_attributes(options)
            @permit_scrubber.tags = allowed_tags(options)
            @permit_scrubber.attributes = allowed_attributes(options)
            fragment.scrub!(@permit_scrubber)
          else
            fragment.scrub!(:strip)
          end
        end

        def sanitize_css(style_string)
          Loofah::HTML5::Scrub.scrub_css(style_string)
        end

        private
          def allowed_tags(options)
            options[:tags] || self.class.allowed_tags
          end

          def allowed_attributes(options)
            options[:attributes] || self.class.allowed_attributes
          end
      end
    end

    # TODO: That should be a real sanitizer (backed by JS or another external interface)
    class NullSanitizer
      class << self
        def safe_list_sanitizer = self
      end

      def sanitize(html, ...) = html
      def sanitize_css(style) = style
    end
  end

  module HTML4
    Sanitizer = HTML::NullSanitizer
    FullSanitizer = Sanitizer
    LinkSanitizer = Sanitizer

    class SafeListSanitizer < Sanitizer
      include HTML::Concern::SafeList
    end
  end

  Html = HTML

  module HTML
    FullSanitizer = HTML4::FullSanitizer
    LinkSanitizer = HTML4::LinkSanitizer
    SafeListSanitizer = HTML4::SafeListSanitizer
    WhiteListSanitizer = SafeListSanitizer
  end
end
