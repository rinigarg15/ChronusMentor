module CareerDevTestHelper
	def create_career_dev_portal(options = {})
		portal_root = options.delete(:root) || "cd"
		organization = options.delete(:organization) || programs(:org_primary)
		portal = CareerDev::Portal.new({:name => "Career Dev Program",
																	  :organization => organization,
																		:program_type => CareerDev::Portal::ProgramType::CHRONUS_CAREER,
																		:mentoring_period => Program::DEFAULT_MENTORING_PERIOD}.merge(options))
		portal.root = portal_root
		portal.save!

		return portal
	end

	def enable_career_development_feature(portal)
		portal.enable_feature(FeatureName::CAREER_DEVELOPMENT, true)
	end

	def disable_career_development_feature(portal)
		portal.enable_feature(FeatureName::CAREER_DEVELOPMENT, false)
	end

	def has_permissions?(role, permissions)
		permissions.each do |permission|
			assert 	role.permissions.collect(&:name).include?(permission)
		end
	end
end