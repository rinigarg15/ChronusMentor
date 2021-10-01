ActionDispatch::Routing::RouteSet::RESERVED_OPTIONS << :organization_level

module UrlForWithSpecialOptions
  # Add a secure option to the rewrite method.
  def url_for(options = {}, *args)
    # Override the default behaviour of the url_for
    # +:anchor+ attribute will be replaced with +:scroll_to+ for
    # the the url generated.
    # The +scroll_to+ param in the resulted url can be handled by
    # jQuery to show a visually pleasing scroll
    options[:scroll_to] = options.delete(:anchor) if options[:anchor].present?

    # If organization level url, remove :root option.
    options.delete(:root) if options[:organization_level].present?

    super(options, *args)
  end
end


# Monkey patch for a Rails bug. The problem is that if is a asset_host proc,
# the proc is eval-ed only once. This patch fixes it.
# BUG: https://rails.lighthouseapp.com/projects/8994/tickets/1299
# FIX: http://github.com/rails/rails/commit/49a055dff639164435dfb71bf18d695970eedac9
module ActionView
  module Helpers #:nodoc:
    module AssetTagHelper
      private
      class AssetTag
        def initialize(template, controller, source, include_host = true)
          @template = template
          @controller = controller
          @source = source
          @include_host = include_host
          @cache_key = if controller.respond_to?(:request)
            [ self.class.name,controller.request.protocol,
              compute_asset_host(source),
              ActionController::Base.relative_url_root,
              source, include_host ]
          else
            [self.class.name,compute_asset_host(source), source, include_host]
          end
        end

        private
        def request
          request? && @controller.request
        end
      end
    end

    module CacheHelper
      def cache_fragment_name(name = {}, options = nil)
        skip_digest = options && options[:skip_digest].present? ? options[:skip_digest] : true

        if skip_digest
          name
        else
          fragment_name_with_digest(name)
        end
      end
    end

    # Without this change -
    # ActionController::Base.helpers.strip_tags("<div id='x'/>a & b") => "a &amp; b"
    # With this change -
    # ActionController::Base.helpers.strip_tags("<div id='x'/>a & b") => "a & b"
    module SanitizeHelper
      def strip_tags(html)
        stripped_html = self.class.full_sanitizer.sanitize(html)
        stripped_html.present? ? CGI::unescape_html(stripped_html) : stripped_html
      end
    end

    module UrlHelper
      # Yahoo mail client doesn't have the ability to decode the email address in mail_to. In reply url (reply-stage+1234+3edqy9q5@m.chronus.com) we pass "+" which will be encoded in mail_to. So when user tries to reply using mail_to link then mail won't get deliever.
      # Reference: https://litmus.com/community/discussions/4062-mailto-link-not-rendering-encoding-breaks-in-yahoo

      def mail_to(email_address, name = nil, html_options = {}, &block)
        html_options, name = name, nil if block_given?
        html_options = (html_options || {}).stringify_keys

        extras = %w{ cc bcc body subject reply_to }.map! { |item|
          option = html_options.delete(item).presence || next
          "#{item.dasherize}=#{ERB::Util.url_encode(option)}"
        }.compact
        extras = extras.empty? ? "".freeze : "?" + extras.join("&")

        encoded_email_address = ERB::Util.url_encode(email_address).gsub("%40", "@")
        #############################################################
        # CODE OVERRIDE BEGIN
        #############################################################

        encoded_email_address.gsub!("%2B", "+")

        #############################################################
        # CODE OVERRIDE END
        #############################################################
        html_options["href"] = "mailto:#{encoded_email_address}#{extras}"

        content_tag("a".freeze, name || email_address, html_options, &block)
      end
    end
  end
end

module WillPaginate
  module ViewHelpers

    class LinkRenderer < LinkRendererBase
      private
      def link(text, target, attributes = {})
        attributes[:"data-page"] = target
        if target.is_a? Fixnum
          attributes[:rel] = rel_value(target)
          target = url(target)
        end
        attributes[:href] = target
        tag(:a, text, attributes)
      end
    end

    def page_entries_info(collection, options = {})
      entries_name = options[:entries_name].present? ? options[:entries_name] : 'will_paginate.Entries'.translate
      if collection.total_pages < 2
        case collection.size
        when 0;
          "will_paginate.content.no_entry".translate(:entries_name => entries_name)
        else;
          if options[:shortest_display]
            "will_paginate.content.shortest_display_html".translate(:entries_size => "<b>#{collection.size}</b>".html_safe, :entries_name => entries_name)
          elsif options[:short_display]
            "will_paginate.content.short_display_html".translate(:entries_name => entries_name, :entries_size => collection.size)
          else
            "will_paginate.content.long_display_html".translate(:entries_name => entries_name, :entries_size => collection.size)
          end
        end
      else
        if options[:shortest_display]
          "will_paginate.content.shortest_display_html".translate(:entries_size => "<b>#{collection.total_entries}</b>".html_safe, :entries_name => entries_name)
        elsif options[:short_display]
          "will_paginate.content.short_display_more_than_2_html".translate(:entries_name => entries_name, :start_entry => (collection.offset + 1), :end_entry => (collection.offset + collection.size), :total_entry => "<b>#{collection.total_entries}</b>".html_safe)
        else
          "will_paginate.content.long_display_more_than_2_html".translate(:entries_name => entries_name, :start_entry => (collection.offset + 1), :end_entry => (collection.offset + collection.size), :total_entry => "<b>#{collection.total_entries}</b>".html_safe)
        end
      end
    end
  end
end

# Override will_paginate's windowed_page_numbers method to display customized links on a page
# add :renderer => ChronusPagination::LinkRenderer option to override
module ChronusPagination
  class LinkRenderer < WillPaginate::ActionView::LinkRenderer
    protected

    def windowed_page_numbers
      inner_window = @options[:inner_window].to_i
      window_from = current_page - inner_window
      window_to = current_page + inner_window

      # Adjust upper and lower bounds so that number of pages displayed remains the same approximately
      if window_to > total_pages
        window_from -= window_to - total_pages
        window_to = total_pages
      end
      if window_from < 1
        window_to += 1 - window_from
        window_from = 1
        window_to = total_pages if window_to > total_pages
      end

      window = (window_from..window_to).to_a
      window
    end

    def page_number(page)
      unless page == current_page
        tag(:li, link(page, page, :rel => rel_value(page)))
      else
        tag(:li, tag(:span, page, class: "current"), class: "active")
      end
    end

    def gap
      text = @template.will_paginate_translate(:page_gap) { '&hellip;' }
      %(<li class="disabled"><span class="gap">#{text}</span></li>)
    end

    def previous_or_next_page(page, text, classname)
      if page
        tag(:li, link(text, page, class: classname))
      else
        tag(:li, tag(:span, text, class: classname), class: "disabled")
      end
    end

    def html_container(html)
      tag(:ul, html, container_attributes)
    end

    def merge_get_params(url_params)
      if @template.respond_to? :request and @template.request and @template.request.get?
        symbolized_update(url_params, @template.params.to_unsafe_h, GET_PARAMS_BLACKLIST)
      end
      url_params
    end
  end
end

ActionDispatch::Routing::RouteSet.prepend(UrlForWithSpecialOptions)
