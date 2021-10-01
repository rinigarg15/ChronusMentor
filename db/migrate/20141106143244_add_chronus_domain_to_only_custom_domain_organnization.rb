class AddChronusDomainToOnlyCustomDomainOrgannization< ActiveRecord::Migration[4.2]

  NEW_SUBDOMAIN_MAP = {
    "leedsmentoringcolorado"    => ["colorado.edu", "leedsmentoring"],
    "wildlifementoring"         => ["wildlife.org", "mentor"],
    "hoyagateway"               => ["georgetown.edu", "hoyagateway"],
    "bemymentorariseasia"       => ["ariseasia.biz", "bemymentor"],
    "smualumnimentoring"        => ["edu.sg", "mentoring.alumni.smu"],
    "scsutorontomentoring"      => ["utoronto.ca", "mentoring.scs"],
    "collectivechangesmentoring"=> ["collectivechanges.net", "mentoring"],
    "cablecomcastmentor"        => ["comcast.com", "mentor.cable"]
  }

  def change
    if Rails.env.production?
      NEW_SUBDOMAIN_MAP.each do |subdomain, params|
        organization = Program::Domain.get_organization(*params)
        if organization.present? && organization.program_domains.size == 1
          program_domain = organization.program_domains.new
          program_domain.is_default = false
          program_domain.domain = "chronus.com"
          program_domain.subdomain = subdomain.dup
          program_domain.save!
          puts "Chronus program domain created for #{params.join('.')}"
        end
      end
    end
  end
end
