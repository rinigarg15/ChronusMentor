# == Schema Information
#
# Table name: security_settings
#
#  id                                :integer          not null, primary key
#  can_contain_login_name            :boolean          default(TRUE)
#  password_expiration_frequency     :integer          default(0)
#  email_domain                      :text(16777215)
#  auto_reactivate_account           :float(24)        default(24.0)
#  reactivation_email_enabled        :boolean          default(TRUE)
#  program_id                        :integer          not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  login_expiry_period               :integer          default(120)
#  maximum_login_attempts            :integer          default(0)
#  can_show_remember_me              :boolean          default(TRUE)
#  allowed_ips                       :text(16777215)
#  password_history_limit            :integer
#  sanitization_version              :string(255)      default("v2")
#  linkedin_token                    :string(255)
#  linkedin_secret                   :string(255)
#  allow_search_engine_indexing      :boolean          default(TRUE)
#  allow_vulnerable_content_by_admin :boolean          default(TRUE)
#

class SecuritySetting < ActiveRecord::Base
  belongs_to :organization, :foreign_key => "program_id"
  validates :program_id, :presence => true, :uniqueness => true
  validates :maximum_login_attempts, :numericality => { :greater_than_or_equal_to => 0 }
  validates :auto_reactivate_account, :numericality => { :greater_than_or_equal_to => 0 }
  validate :validate_ip_address_format

  # "127.0.0.1,192.168.1.1:192.168.1.9"
  # will be transformed to:
  # [IPAddr.new(127.0.0.1), IPAddr.new(192.168.1.1)..IPAddr.new(192.168.1.9)]
  def allowed_ip_values
    ips_to_access = []
    allowed_ips_list.each do |ip_address|
      if self.class.valid_ip?(ip_address)
        ips_to_access << IPAddr.new(ip_address)
      elsif range = self.class.get_range(ip_address)
        ips_to_access << (IPAddr.new(range.first)..IPAddr.new(range.last))
      end
    end
    ips_to_access.uniq
  end

  def allow_ip?(ip_address)
    ips_to_access = allowed_ip_values
    ips_to_access.empty? || self.class.ip_accessible?(ips_to_access, ip_address)
  end

  def deny_ip?(ip_address)
    !allow_ip?(ip_address)
  end

  class << self
    def ip_address_separator
      ","
    end

    def ip_ranges_separator
      ':'
    end
  end

private
  class << self
    def ip_accessible?(ips_to_access, ip_address)
      ip = IPAddr.new(ip_address)
      logger.info "Checking IP by filters: #{ip_address}"
      ips_to_access.any? do |ip_or_range|
        case ip_or_range
        when Range
          ip_or_range.cover?(ip)
        when IPAddr
          ip_or_range == ip
        end
      end
    end

    def valid_ip?(ip_address)
      !!(Resolv::IPv4::Regex.match(ip_address))
    end

    def get_range(ip_address)
      range = ip_address.split(ip_ranges_separator).map(&:strip)
      if valid_range?(range)
        range
      else
        nil
      end
    end

    def valid_range?(range)
      from, to = range
      (2 == range.size) && valid_ip?(from) && valid_ip?(to) && (IPAddr.new(from) <= IPAddr.new(to))
    end
  end

  def allowed_ips_list
    (allowed_ips || "").split(self.class.ip_address_separator).map(&:strip)
  end

  def validate_ip_address_format
    allowed_ips_list.each do |ip_address|
      unless self.class.valid_ip?(ip_address) || self.class.get_range(ip_address)
        errors.add(:allowed_ips, "activerecord.custom_errors.security_setting.invalid_address".translate)
        return
      end
    end
  end
end
