# = Back mark plugin
#
# Mark pages with labels that can be linked back from future pages as back
# links.
#
# Also remembers the last accessed page so that they can be redirected to. Skips
# forms and non-get For instance, a user is viewing items index, and navigates
# to 'new item' page. Once he is done with the creation of the item (i.e., POST
# to items/create), it would be nice if the user is taken to the index page
# rather than the 'new' page, which was the LAST VISITED page. Hence, such CUD
# actions are *_not_remembered_*.
#
# Author    ::  Vikram Venkatesan  (mailto:vikram@chronus.com)
# Copyright ::  Copyright (c) 2009 Chronus Corporation
#
module BackMark
  # Pages/Actions which we don't want to remember. We wouldn't ideally want to
  #   link back to new, edit, etc.,. We would only want to provide a link to the
  #   page that took the user to those pages.
  #
  IGNORE_ACTIONS = %w(new edit create update destroy)

  module ControllerMethods
    def self.included(controller)
      controller.send :attr_accessor, :already_back_marked
      controller.before_action :detect_browser_back
      controller.before_action :back_mark_pages
      controller.after_action :simulate_referer
      controller.helper_method :back_url, :back_label
    end

    # Add this as a before filter for marking the current request url
    #
    # Configuration options:
    # * <tt>:force_mark</tt> -  mark the request even if it is one of the
    #   +IGNORE_ACTIONS+
    def back_mark_pages(options = {})
      return unless params[:dont_back_mark].nil?
      # Even if a request to be ignored, don't do it if :force_mark is passed.
      return if ignore_request? && !options[:force_mark]

      do_backmark(request.url)
    end

    # Add this as a before filter for forcefully marking the current request url
    # This will be useful to backmark new, edit, create, update & destroy actions
    def force_back_mark
      back_mark_pages(force_mark: true)
    end

    # Marks the current url with the given label. Invoke from an action with a
    # meaningful label, if you want that page to be linked back from future
    # pages
    #
    # ===== Params
    # * <tt>label</tt>    - label for the back mark
    # * <tt>url</tt>      - the url to remember instead of the current request
    #   url
    # * <tt>mark_now</tt> - Mark the url in such a way that the back link can be
    #   rendered in the current action
    #
    # ===== Examples
    #   back_mark("Inbox")
    #   back_mark("Home")
    #   back_mark("Login", '/login', true)
    #
    def back_mark(label, url = nil, mark_now = false)
      # Ignore AJAX and non-GET requests since they cannot be linked back.
      return if ajax_or_non_get?

      url ||= request.url

      # Use the given url as though its the previous page's backmark.
      if mark_now
        # Mark as if this call happened in previous request.
        session[:back_url]   = url
        session[:back_label] = label
        self.already_back_marked = true
      else
        # Mark the current page
        do_backmark(url, label)
      end
    end

    # Returns the last back_marked page url
    #
    # ==== Params
    # * <tt>fallback_url</tt> - url to return if there is no backmark
    #   information.
    #
    def back_url(fallback_url = nil, options = {})
      url_to_use = self.already_back_marked ? session[:back_url] : session[:last_visit_url]

      # If we have a back url and it is not same as the current url, use it,
      # else, use +fallback_url+
      (url_to_use && !(url_to_use == request.url && request.get?)) ? back_url_with_options(url_to_use, options) : fallback_url
    end

    def back_url_with_options(url_to_use, options = {})
      additional_params = ""
      if (options[:additional_params].blank? && @cjs_close_iab_refresh && @cjs_close_iab_refresh == 1)
        additional_params = "cjs_close_iab_refresh=1"
      elsif (options[:additional_params].present? && @cjs_close_iab_refresh && @cjs_close_iab_refresh == 1)
        additional_params = options[:additional_params]+"&cjs_close_iab_refresh=1"
      else
        additional_params = options[:additional_params]          
      end
      additional_params.present? ? (url_to_use.match(/\?/) ? url_to_use+"&"+additional_params : url_to_use+"?"+additional_params) : url_to_use
    end

    # Returns the last back_marked label
    def back_label
      session[:back_label]
    end

    # Redirect to the back link stored in the session or redirect to the default
    # url passed.
    #
    # ==== Params
    # * <tt>fallback_url</tt> - url to return if there is no backmark
    #   information.
    #
    def redirect_to_back_mark_or_default(fallback_url, options = {})
      redirect_to back_url(fallback_url, options)
      session[:back_url] = nil
    end

    # Returns whether the request should be ignored. Following requests are
    # ignored
    #
    # * AJAX requests
    # * non-GET requests
    # * actions that are in IGNORE_ACTIONS
    #
    def ignore_request?
      ajax_or_non_get? || ::BackMark::IGNORE_ACTIONS.include?(params[:action])
    end

    # Returns whether the current request is AJAX or one with non GET method.
    def ajax_or_non_get?
      request.xhr? || !request.get?
    end

    # Returns true if *request.referrer* is not the default value.
    # *request.referrer* happens to have default value when the page
    # was reached through browser history.
    #
    def client_referer_available?
      request.referrer && request.referrer != '/'
    end

    private

    # Simulates HTTP referrer logic using session.
    def simulate_referer
      # Ignore this logic in test environment.
      return if request.xhr? || Rails.env == 'test'

      # Consider only requests that resulted in render. This is done since
      # redirects are not included in HTTP referrer history. 
      session[:server_referrer] = request.url if @performed_render
    end

    # Detects whether the previous page access involved a browser back button.
    #
    # ==== Logic:
    # +simulate_referer+ marks all Non-AJAX GET requests to the server and stores
    # them in session[:server_referrer] so as to simulate our own version of the
    # request referrer. The only exception to this is when browser back button
    # is used. In that case, the referrer for the subsequent request will still
    # see the proper referrer sent by the browser, but our session referrer
    # won't match that since we dont' requests for history calls.
    #
    #   A                    [last_visit_url => nil, referrer => nil]
    #   A => B               [last_visit_url => A, referrer => A]
    #   B => A (using BACK)  [last_visit_url => B, referrer => B]
    #   A => C               [last_visit_url => B, referrer => A] => +BACK!+
    #
    # The last C request tells us that the previous request (to A) was a browser
    # BACK access and we will adjust our back marks accordingly.
    def detect_browser_back
      # Ignore this logic in test environment since referrer handling won't be
      # proper in tests and we will get false 'browser back' hits.
      return if ajax_or_non_get? || Rails.env == 'test'

      # If referrer is not the same as our :server_referrer, then the previous
      # page was reached throw browser history.
      if client_referer_available? && session[:server_referrer] && request.referrer != session[:server_referrer]
        # Mark the +request.referrer+ as the tmp_back_url so that it looks as
        # though set by the previous page.
        session[:last_visit_url] = request.referrer
      end
    end

    # Copies previous request's info to backmark and marks the given url and
    #   label.
    #
    # ==== Params
    # * <tt>url</tt> - url to mark for the current request
    # * <tt>label</tt> - label for the current request.
    #
    def do_backmark(url, label = nil)
      # Shift temp backmarks unless already done.
      unless self.already_back_marked
        session[:back_url]    = session[:last_visit_url]
        session[:back_label]  = session[:last_visit_label]
      end

      session[:last_visit_url]   = url
      session[:last_visit_label] = label
      self.already_back_marked   = true
    end
  end

  module ViewMethods
    # Renders a link back to the previous page stored in the session with the
    # stored label if both of them are available.
    def render_back_link
      if back_url && back_label
        link_to "&laquo; Back to '#{back_label}'", back_url, :id => 'back_link'
      end
    end
  end
end
