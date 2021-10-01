class AddMentoringConnectionMeetingFeature< ActiveRecord::Migration[4.2]
	def change
    ActiveRecord::Base.transaction do
	    if Feature.count > 0
	      Feature.create_default_features
	    end
	    Organization.active.select(&:calendar_enabled?).each do |organization|
	  		organization.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
	    end
	  end
  end
end
