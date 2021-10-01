module GlobalMemberSearch
  def self.search(email, uniq_token)
    members = Member.where(email: email)
    self.configure_login_token_and_email(members, uniq_token)
    #Not including the production server in the list of hosts as the first redirect from app always happen to production server. so there is no need to send request to production server again
    hosts_to_search = APP_CONFIG[:global_member_search_hosts]
    hosts_to_search.each do |host_url|
      search_url = host_url + Rails.application.routes.url_helpers.mobile_v2_home_validate_member_path
      response = send_request(search_url, email, uniq_token)
      if response.blank? || [HttpConstants::NO_CONTENT, HttpConstants::SUCCESS].exclude?(response.code.to_i)
        Airbrake.notify("Failed to search for member for the host url - #{search_url}")
      end
    end
  end

  def self.configure_login_token_and_email(members, uniq_token)
    members.each do |member|
      member.create_login_token_and_send_email(uniq_token)
    end
  end

  private

  def self.send_request(url, email, uniq_token)
    url = URI(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Post.new(
      url,
      'Content-Type' => 'application/json'
    )
    request.body = JSON.dump({
      "global_member_search_api_key" => APP_CONFIG[:global_member_search_api_key],
      "email" => email,
      "uniq_token" => uniq_token
    })
    http.request(request)
  end
end