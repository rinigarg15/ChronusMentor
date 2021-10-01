module AuthenticationForExternalServices

  protected

  def mailgun_signature_verified?
    api_key = APP_CONFIG[:mailgun_api_key]
    token = params[:token]
    timestamp = params[:timestamp]
    signature = params[:signature]
    computed_signature = OpenSSL::HMAC.hexdigest(
                              OpenSSL::Digest.new('sha256'),
                              api_key,
                              '%s%s' % [timestamp, token])
    return signature == computed_signature
  end
end
