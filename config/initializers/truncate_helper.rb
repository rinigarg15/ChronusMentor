# By Henrik Nyh <http://henrik.nyh.se> 2008-01-30.
# Free to modify and redistribute with credit.

# modified by Dave Nolan <http://textgoeshere.org.uk> 2008-02-06
# Ellipsis appended to text of last HTML node
# Ellipsis inserted after final word break

# modified by Mark Dickson <mark@sitesteaders.com> 2008-12-18
# Option to truncate to last full word
# Option to include a 'more' link
# Check for nil last child

# modified by Ken-ichi Ueda <http://kueda.net> 2009-09-02
# Rails 2.3 compatability (chars -> mb_chars), via Henrik
# Hpricot 0.8 compatability (avoid dup on Hpricot::Elem)

require "hpricot"

module ActionView
  module Helpers #:nodoc:
    # By Henrik Nyh <http://henrik.nyh.se> 2008-01-30.
    # Free to modify and redistribute with credit.
    module TextHelper
      # Like the Rails _truncate_ helper but doesn't break HTML tags or entities.
      # Like the Rails _truncate_ helper but doesn't break HTML tags, entities, and optionally. words.
      def truncate_html(text, options={})
        return if text.nil?

        max_length = options[:max_length] || 40
        ellipsis = options[:ellipsis] || "..."
        words = options[:words] || false
        status = options[:status] || false
        # use :link => link_to('more', post_path), or something to that effect

        doc = Hpricot(text.to_s)
        ellipsis_length = Hpricot(ellipsis).inner_text.mb_chars.length
        content_length = doc.inner_text.mb_chars.length
        actual_length = max_length - ellipsis_length

        if content_length > max_length
          truncated_doc = doc.truncate(actual_length)

          if words
            word_length = actual_length - (truncated_doc.inner_html.mb_chars.length - truncated_doc.inner_html.rindex(' '))
            truncated_doc = doc.truncate(word_length)
          end

          #XXX The check here has to be blank as the inner_html for text node is blank
          return_string = truncated_doc.inner_html + ellipsis.html_safe
          return_string += options[:link].html_safe if options[:link]
          return_status = true
        else
          return_string = text.to_s
          return_status = false
        end

        return (status ? [return_string.html_safe, return_status] : return_string.html_safe)
      end

    end
  end
end

module HpricotTruncator
  module NodeWithChildren
    def truncate(max_length)
      return self if inner_text.mb_chars.length <= max_length
      truncated_node = if self.is_a?(Hpricot::Doc)
        self.dup
      else
        self.class.send(:new, self.name, self.attributes)
      end
      truncated_node.children = []
      each_child do |node|
        if node.is_a?(Hpricot::Elem) && node.name == "html"
          node.children.each do |c|
            # Find the body node and use it. Let us reset earlier truncations
            # and start afresh with this body tag
            return c.truncate(max_length) if (c.is_a?(Hpricot::Elem) && c.name == "body")
          end
        end

        remaining_length = max_length - truncated_node.inner_text.mb_chars.length
        break if remaining_length <= 0
        truncated_node.children << node.truncate(remaining_length)
      end
      truncated_node
    end
  end

  module TextNode
    def truncate(max_length)
      # We're using String#scan because Hpricot doesn't distinguish entities.
      Hpricot::Text.new(content.scan(/&#?[^\W_]+;|./).first(max_length).join)
    end
  end

  module IgnoredTag
    def truncate(max_length)
      self
    end
  end

  module MapFix # seems like a bug in the latest version of the gem.
    def map(&block)
      self.to_hash.map do |key, value|
        block.call(key, value)
      end
    end
  end
end

Hpricot::Doc.send(:include,       HpricotTruncator::NodeWithChildren)
Hpricot::Elem.send(:include,      HpricotTruncator::NodeWithChildren)
Hpricot::Text.send(:include,      HpricotTruncator::TextNode)
Hpricot::BogusETag.send(:include, HpricotTruncator::IgnoredTag)
Hpricot::Comment.send(:include,   HpricotTruncator::IgnoredTag)
Hpricot::DocType.send(:include,   HpricotTruncator::IgnoredTag)
Hpricot::Attributes.send(:include,   HpricotTruncator::MapFix)