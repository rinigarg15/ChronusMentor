module Pendo
  # https://help.pendo.io/resources/support-library/api/index.html?bash#reset-guide-seen-for-specific-visitor-for-all-guides
  RESET_PENDO_DATA_URL = Proc.new { |email| "https://app.pendo.io/api/v1/guide/all/visitor/#{email}/reset" }

  def self.reset_pendo_guide_seen_data(member, user)
    return unless can_reset_pendo_guide_seen_data?(member, user)

    begin
      url = RESET_PENDO_DATA_URL.call(member.email)
      response = send_request(url)
      if response.blank? || (response.code.to_i != HttpConstants::SUCCESS)
        raise("Failed to reset pendo guide data for member id: #{member.id} - Pendo responded with '#{response.try(:code)}'")
      end
    rescue => e
      Airbrake.notify(e)
    end
  end

  private

  def self.can_reset_pendo_guide_seen_data?(member, user)
    pendo_integration_enabled? && member.present? && (member.admin? || (user.present? && user.is_admin?))
  end

  def self.pendo_integration_enabled?
    defined?(RESET_PENDO_GUIDE_SEEN) && RESET_PENDO_GUIDE_SEEN && APP_CONFIG[:pendo_integration_key].present?
  end

  def self.send_request(url)
    url = URI(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    request = Net::HTTP::Post.new(
      url,
      'Content-Type' => 'application/json',
      'x-pendo-integration-key' => APP_CONFIG[:pendo_integration_key]
    )
    http.request(request)
  end
end