module ApplicationControllerExtensions::RenderingHelpers
  private

  def send_csv(data, options = {})
    options[:type] = options[:type].presence || 'text/csv; charset=iso-8859-1; header=present'
    # Byte Order Mark (BOM) is added to render the CSV with accented characters in MS Excel 2007+
    # http://stackoverflow.com/a/155176
    # https://chronus.atlassian.net/browse/AP-14084?focusedCommentId=50542&page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel#comment-50542
    data = UTF8_BOM + data
    send_data(data, options)
  end

  def redirect_to(options = {}, response_status = {})
    if should_escape_redirect_url?(options)
      url = CGI.escape(options)
      super(handle_redirect_path(redirect_path: url), response_status)
    else
      super(options, response_status)
    end
  end

  def do_redirect(path)
    request.xhr? ? redirect_ajax(path) : redirect_to(path)
  end

  def redirect_ajax(path)
    render js: "window.location.href = \"#{path}\";"
  end

  def should_escape_redirect_url?(options = {})
    !@no_handle_redirect && !is_iab? && (use_browser_tab?(options) || external_redirect_in_android_app?(options))
  end

  def use_browser_tab?(options)
    is_mobile_app? && options.is_a?(String) && use_browsertab_for_external_link?(options)
  end

  def external_redirect_in_android_app?(options)
    is_android_app? && options.is_a?(String) && is_external_link?(options)
  end

end