# This is a minimal Nokogiri stub to make Action Text basic features work (no embeddings)
module Nokogiri
  module XML
    class DocumentFragment
    end

    module Node
      module SaveOptions
        AS_HTML = 1
      end
    end
  end

  module HTML5
    class Document
      def initialize
        # TODO
      end

      def encoding=(enc)
      end

      def fragment(html)
        DocumentFragment.new(html)
      end

      def create_element(tag_name, attributes = {})
        # Create an element with given tag name and attributes
      end
    end

    class DocumentFragment < XML::DocumentFragment
      attr_reader :elements, :name

      def initialize(html_string)
        @html_string = html_string
        @elements = []
        @name = html_string.match(/<(\w+)/).then { next unless _1; _1[1] }
      end

      def css(selector)
        # Return array of matching nodes
        # Must support selectors like:
        # - "a[href]" - anchor tags with href attribute
        # - "action-text-attachment" - elements by tag name
        # - Complex selectors for attachment galleries
        []
      end

      def children
        []
      end

      def dup
        self.class.new(@html_string)
      end

      def to_html(options = {})
        # Must respect options[:save_with] if provided
        @html_string
      end

      def elements
        self
      end

      def deconstruct
        children
      end
    end

    class Node
      attr_accessor :parent

      def initialize(name, attributes = {})
        @name = name
        @attributes = attributes
        @children = []
        @text = ""
      end

      # Node type and content
      def name
        @name # e.g., "p", "div", "text", etc.
      end

      def text
        # Return text content (for text nodes) or aggregate text of children
      end

      def text?
        # Return true if this is a text node
        name == "text" || name == "#text"
      end

      # Attribute access
      def [](attribute_name)
        # Get attribute value
        @attributes[attribute_name]
      end

      def []=(attribute_name, value)
        # Set attribute value
        @attributes[attribute_name] = value
      end

      def key?(attribute_name)
        # Check if attribute exists
        @attributes.key?(attribute_name)
      end

      def remove_attribute(attribute_name)
        # Remove attribute and return its value
        @attributes.delete(attribute_name)
      end

      # DOM traversal
      def children
        # Return array of child nodes
        @children
      end

      def ancestors
        # Return array of ancestor nodes (parent, grandparent, etc.)
        result = []
        node = parent
        while node
          result << node
          node = node.parent
        end
        result
      end

      # DOM manipulation
      def replace(replacement)
        # Replace this node with the replacement (string or node)
        # If replacement is a string, parse it as HTML
      end

      # CSS matching
      def matches?(selector)
        # Check if this node matches the given CSS selector
      end

      # HTML output
      def to_html(options = {})
        # Convert to HTML string
      end

      def to_s
        to_html
      end

      def inspect
        # For debugging
        "#<Node:#{name} #{@attributes.inspect}>"
      end
    end
  end

  module HTML4
    Document = HTML5::Document
    DocumentFragment = HTML5::DocumentFragment
  end
end
