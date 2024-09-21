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
  end

  Html = HTML
end
