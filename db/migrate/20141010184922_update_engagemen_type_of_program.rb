class UpdateEngagemenTypeOfProgram< ActiveRecord::Migration[4.2]
  def change
    cal_org = Organization.includes(:programs).select{|org| org.calendar_enabled?}
    # removing calendar as feature from org level from UI
    # bcoz if org level calendar is enabled then at time of program creation one time mentoring will be checked by default
    cal_org.each do |org|
      prog_with_cal = org.programs.select{|prog| prog.calendar_enabled?}
      org.reload.enable_feature(FeatureName::CALENDAR, false)
      prog_with_cal.each do |prog|
        prog.reload.enable_feature(FeatureName::CALENDAR)
      end
    end

    offer_org = Organization.includes(:programs).select{|org| org.mentor_offer_enabled?}
    offer_org.each do |org|
      prog_with_offer = org.programs.select{|prog| prog.mentor_offer_enabled?}
      org.reload.enable_feature(FeatureName::OFFER_MENTORING, false)
      prog_with_offer.each do |prog|
        prog.reload.enable_feature(FeatureName::OFFER_MENTORING, false)
        prog.reload.enable_feature(FeatureName::OFFER_MENTORING)
      end
    end
    Program.find_each do |prog|
      prog.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING) if prog.career_based? && (prog.mentoring_connections_v2_enabled? || prog.mentoring_milestones_enabled? || prog.mentoring_goals_enabled?)
    end
  end
end
