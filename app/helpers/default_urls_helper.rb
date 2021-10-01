module DefaultUrlsHelper

  def default_url_params
    {
      host: DEFAULT_HOST_NAME,
      subdomain: SECURE_SUBDOMAIN,
      SID_PARAM_NAME => request.session_options[:id],
      protocol: secure_protocol
    }
  end
end