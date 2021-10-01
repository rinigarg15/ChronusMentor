class SetDefaultEngagementType< ActiveRecord::Migration[4.2]
  def change
    Program.where(engagement_type: nil).update_all(engagement_type: Program::EngagementType::CAREER_BASED)
  end
end
