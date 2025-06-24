# frozen_string_literal: true

Wasmify::Patcha.on_load("ActionText::PlainTextConversion") do
  module ActionText::PlainTextConversion
    def plain_text_for_node(node)
      html = node.to_html
      # FIXME: use external interface?
      html.gsub(/<[^>]*>/, " ").strip
    end
  end
end
