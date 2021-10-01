# == Schema Information
#
# Table name: program_domains
#
#  id         :integer          not null, primary key
#  program_id :integer
#  domain     :string(255)      not null
#  subdomain  :string(255)
#  is_default :boolean          default(TRUE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Program::Domain < ActiveRecord::Base
  belongs_to_organization

  # attr_protected :subdomain, :domain

  validates :organization, presence: true
  validates :is_default, inclusion: {in: [true, false] }, uniqueness: {scope: :program_id}

  validates :domain,    :presence => true,
                        :format => { :with => RegexConstants::RE_DOMAIN_NAME, :message => Proc.new { "activerecord.custom_errors.domain.invalid_format".translate }},
                        :allow_blank => false

  validates :subdomain, presence: true, if: :default_domain?

  validates :subdomain, :uniqueness => {:scope => :domain, :case_sensitive => false, :message => Proc.new { "activerecord.custom_errors.domain.already_exists".translate }},
                        :format => { :with => /\A[A-Za-z0-9\-\.]+\z/, :message => Proc.new { "activerecord.custom_errors.domain.invalid".translate }},
                        :length => { :minimum => 3 },
                        :allow_blank => true

  validates :subdomain, :exclusion => {:in => BlockedDomainNames, :message => Proc.new { "activerecord.custom_errors.domain.subdomain_is_reserved".translate }},
                        :if => Proc.new { |domain| domain.default_domain? }

  scope :default, -> { where(is_default: true)}

  before_validation :properize_subdomain_and_domain

  def self.get_organization(domain, subdomain)
    prog_domain = self.where(subdomain: subdomain, domain: domain).first
    if prog_domain
      return Organization.find(prog_domain.program_id)
    end
  end

  def default_domain?
    self.domain == DEFAULT_DOMAIN_NAME
  end

  def get_url
    subdomain.present? ? "#{subdomain}.#{domain}" : domain
  end

  protected

  def properize_subdomain_and_domain
    self.subdomain.downcase! if self.attribute_present?("subdomain")
    self.domain ||= DEFAULT_DOMAIN_NAME
    self.domain.downcase!
  end

end
