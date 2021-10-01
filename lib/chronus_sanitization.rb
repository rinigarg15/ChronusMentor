module Nokogiri
  module HTML
    class DocumentFragment
      PATTERN = /href\s*=\s*"%7B%7B(\w+)%7D%7D"/ unless defined?(PATTERN)
      def cleanup_encoded_links
        self.to_html.gsub(PATTERN, "href=\"{{\\1}}\"")
      end
    end
  end
end
module ChronusSanitization
  include SanitizeAllowScriptAccess

  module HelperMethods

    SANITIZATION_VERSION_V1 = "v1"
    SANITIZATION_VERSION_V2 = "v2"
    SANITIZATION_OPTIONS = {
      :ckeditor => {
        :attributes => %w[style _cke_saved_href accesskey align alt bgcolor border id class cellpadding cellspacing charset classid codebase colspan data-cke-realelement data-cke-saved-href dir height href hspace lang longdesc name pluginspage quality rel rowspan scale scope src start summary tabindex target title type value vspace width wmode allowfullscreen autoplay controller embed flashvars frameborder loop menu salign allowscriptaccess],
        :tags => %w[style a b i u address blockquote br caption div em embed h1 h2 h3 h4 h5 h6 hr iframe img li object ol p param pre s span strong sub sup table tbody td tfoot th thead tr u ul]
      }
    }

    def chronus_sanitize(content, options = {})
      if content.nil?
        content ||= ""
      end
      # Stripping off comments in CKEDITOR
      content = content.gsub(/<!--(.*?)-->[\n]?/m, "") if (content && content =~ /<!--(.*?)-->[\n]?/m)
      if (options[:sanitization_version] && options[:sanitization_version] == SANITIZATION_VERSION_V2)
        content = ActionController::Base.helpers.sanitize(content, SANITIZATION_OPTIONS[:ckeditor])
        content = ChronusSanitization::Utils.sanitize_allowsciptaccess(content)
        # else use sanitization version V1
      end
      content.html_safe
    end

    def chronus_format_text_area(str, options = {})
      h(str).gsub("\n", "\n<br />").html_safe
    end

    def chronus_auto_link(str, options = {})
      formatted_text =  options[:skip_text_formatting] ? str : chronus_format_text_area(str, options)
      auto_link(formatted_text, html: {target: '_blank' })
    end

    def chronus_sanitize_while_render(content, options = {})
      if (options[:sanitization_version] && options[:sanitization_version] == SANITIZATION_VERSION_V1)
        if(options[:sanitization_options])
          sanitize(content, options[:sanitization_options]).to_s.html_safe
        else
          sanitize(content).to_s.html_safe
        end
      else
        content.to_s.html_safe
      end
    end

    def tooltip_double_escape(content)
      h(content).to_str
    end

    def get_safe_string(str = "")
      raise "Invalid contant string" unless ["","&nbsp;","<br/>","<",">","&raquo;","&quot;","&laquo;", "&ndash;"].include?(str)
      str.html_safe
    end

    def chr_json_escape(content)
      content.gsub('/', '\/').html_safe
    end

    def to_sentence_sanitize(content, options = {})
      content.collect{|obj| h(obj)}.to_sentence(options).html_safe
    end

    # highchart has bug so please use this function
    def highchart_string_sanitize(str)
      h(str).gsub('&amp;', '\\\&').gsub('&#39;', "\\\\'").gsub('&quot;', '\"').html_safe
    end
  end

  module Utils
    extend SanitizeAllowScriptAccess
    extend ChronusSanitization::HelperMethods

    class << self
      ALLOWSCRIPTACCESS_STR = "allowscriptaccess"

      def vulnerable_content?(organization, content, options = {})
        sanitization_version = options[:for_sanitization_version] || organization.security_setting.sanitization_version
        original_content = content.to_s
        original_content = original_content.gsub(/\n+/, "\n")
        original_content = cleanup_style_attribute(Nokogiri::HTML::DocumentFragment.parse(original_content)).cleanup_encoded_links
        sanitized_content = cleanup_style_attribute(Nokogiri::HTML::DocumentFragment.parse(chronus_sanitize(original_content, sanitization_version: sanitization_version))).cleanup_encoded_links

        # Comments removed
        original_content = original_content.gsub(/<!--(.*?)-->[\n]?/m, "") if (original_content && original_content =~ /<!--(.*?)-->[\n]?/m)

        # Should show alert only if sanitization version is v2
        vulnerable = (
          (sanitization_version == ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V2) && 
          difference_detected?(original_content, sanitized_content)  
        )
        {vulnerable: vulnerable, original_content: original_content, sanitized_content: sanitized_content}
      end

      def cleanup_style_attribute(doc)
        node_parser(doc) do |node|
          if node.attributes["style"]
            style_value = node.attributes["style"].value
            style_value = style_value.split(";").reject{ |css_rule| css_rule.blank? }.map do |css_rule|
              css_rule_elements = css_rule.split(":")
              if css_rule_elements.size == 2
                "#{css_rule_elements[0].strip}: #{css_rule_elements[1].lstrip}"
              else
                css_rule.lstrip
              end
            end.join("; ")
            style_value << ";" if style_value.present? && style_value[-1] != ";"
            node.attributes["style"].value = style_value
          end
        end
        doc
      end

      def difference_detected?(original_content, sanitized_content)
        original_doc = Nokogiri::HTML::DocumentFragment.parse(original_content)
        sanitized_doc = Nokogiri::HTML::DocumentFragment.parse(sanitized_content)
        (
          (original_doc.inner_text != sanitized_doc.inner_text) || 
          attributes_or_tags_sanitization_detected?(original_doc, sanitized_doc)
        )
      end

      # this will return true is orignal is different from sanitized doc, by detecting stripped off tags or attributes
      def attributes_or_tags_sanitization_detected?(original_doc, sanitized_doc)
        original_doc_attrs_list = get_attributes_of_doc(original_doc)
        sanitized_doc_attrs_list = get_attributes_of_doc(sanitized_doc)
        return true if different_lists?(original_doc_attrs_list, sanitized_doc_attrs_list)
        original_doc_tags_list = get_tags_of_doc(original_doc)
        sanitized_doc_tags_list = get_tags_of_doc(sanitized_doc)
        return true if different_lists?(original_doc_tags_list, sanitized_doc_tags_list)
        original_doc_style_attr_values_list = get_style_attr_values_of_doc(original_doc)
        sanitized_doc_style_attr_values_list = get_style_attr_values_of_doc(sanitized_doc)
        return true if different_lists?(original_doc_style_attr_values_list, sanitized_doc_style_attr_values_list)
        false
      end

      def different_lists?(list1, list2)
        return true if list1.size != list2.size
        list1.each_with_index do |value, index|
          return true if value != list2[index]
        end
        false
      end

      def get_style_attr_values_of_doc(doc)
        node_parser(doc) do |node|
          node.attributes["style"].value if node.attributes["style"]
        end
      end

      def get_attributes_of_doc(doc)
        node_parser(doc) do |node|
          attrs_list = node.attributes.values.map(&:name)
          if attrs_list.include?(ALLOWSCRIPTACCESS_STR)
            attrs_list - (node.attributes[ALLOWSCRIPTACCESS_STR].value.downcase.strip == "never" ? [ALLOWSCRIPTACCESS_STR] : [])
          else
            attrs_list
          end
        end
      end

      def sanitize_allowsciptaccess(content)
        doc = Nokogiri::HTML::DocumentFragment.parse(content)
        node_parser(doc) do |node|
          node.attributes[ALLOWSCRIPTACCESS_STR].remove if node.attributes[ALLOWSCRIPTACCESS_STR] && node.attributes[ALLOWSCRIPTACCESS_STR].try(:value).to_s.downcase.strip != "never"
          node.remove if node.name.to_s.downcase.strip == "param" && node.attributes["name"].to_s.downcase.strip == ALLOWSCRIPTACCESS_STR && node.attributes["value"].to_s.downcase.strip != "never"
        end
        doc.cleanup_encoded_links
      end

      def get_tags_of_doc(doc)
        node_parser(doc) { |node| node.name }
      end

      # this will pass on every node on the graph and fetch the required value by the block in the doc given
      def node_parser(doc, &block)
        list = []
        queue = [doc]
        while queue.present? do
          node = queue.shift
          list << yield(node)
          queue << node.children
          queue.flatten!
        end
        list.flatten
      end
    end
  end
end
