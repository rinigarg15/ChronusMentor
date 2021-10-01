class CleanupSecuritySettingsAllowedIps< ActiveRecord::Migration[4.2]
  def up
    SecuritySetting.where('allowed_ips!=? AND allowed_ips IS NOT NULL', '').each do |settings|
      separator = ','
      values = settings.allowed_ips.split(separator).map(&:strip).reject { |ip_address| !Resolv::IPv4::Regex.match(ip_address) }
      settings.update_attributes!(allowed_ips: values.join(separator))
    end
  end

  def down
  end
end
