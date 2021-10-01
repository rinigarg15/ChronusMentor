class SecuritySettingService
  def self.parse_params(params)
    params.inject([]) { |res, param|
      if param[:from].present?
        res << (param[:to].present? ? [param[:from], param[:to]].join(SecuritySetting.ip_ranges_separator) : param[:from])
      end
      res
    }.join(SecuritySetting.ip_address_separator)
  end
end
