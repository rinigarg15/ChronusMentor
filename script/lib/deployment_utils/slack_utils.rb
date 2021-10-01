module SlackUtils
  MENTOR_CHANNEL = "https://hooks.slack.com/services/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"
  OPS_CHANNEL = "https://hooks.slack.com/services/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"

  def self.send_slack_message(options)
    webhook_url = URI.parse(options[:slack_url])
    http = Net::HTTP.new(webhook_url.host, webhook_url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Post.new(
      webhook_url.request_uri, 
      'Content-Type' => 'application/json'
    )
    request.body = build_slack_message(options)
    response = http.request(request)
    puts "Slack notification not sent".colorize(:red) unless response.kind_of?(Net::HTTPSuccess)
  end

  def self.build_slack_message(options)
    slack_message = {
      "attachments": [{
        "fallback": "#{options[:text]} for #{options[:server]} by #{get_deploy_user}",
        "color": options[:color],
        "pretext": options[:text],
        "author_name": "By #{get_deploy_user}",
        "fields": [
          {
            "title": "Environment/Server",
            "value": options[:server],
            "short": true
          }
        ]
      }]
    }
    slack_message[:attachments].first[:fields] << { "title": "Branch", "value": options[:branch], "short": true } if options[:branch]
    slack_message.to_json
  end

  def self.get_deploy_user
    if (u = ENV['USER']) != ""
      u
    elsif (u = %x{git config user.name}.strip) != ""
      u
    else
      "Someone"
    end
  end
end