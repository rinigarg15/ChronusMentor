ActionController::Base.send :include, FeatureManager

# Features that are available in the application.
module FeatureName
	def self.permenantly_disabled_career_dev_features
    [
  		MENTORING_CONNECTIONS_V2, EXECUTIVE_SUMMARY_REPORT, PROGRAM_OUTCOMES_REPORT, CONNECTION_PROFILE,
  		CALENDAR, MENTORING_CONNECTION_MEETING, OFFER_MENTORING, BULK_MATCH,
      COACHING_GOALS, MANAGER, MENTORING_INSIGHTS, CONTRACT_MANAGEMENT, COACH_RATING, MENTOR_RECOMMENDATION, SKIP_AND_FAVORITE_PROFILES
  	]
  end

  def self.career_dev_specific_features
    [
      CAREER_DEVELOPMENT
    ]
  end
end