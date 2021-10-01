class AddThresholdToThreeSixtyReviewerGroups< ActiveRecord::Migration[4.2]
  def up
    add_column :three_sixty_reviewer_groups, :threshold, :integer, :null => false
    remove_column :three_sixty_surveys, :threshold

    ActiveRecord::Base.transaction do
      ThreeSixty::ReviewerGroup.all.each do |rg|
        next unless ThreeSixty::ReviewerGroup::DefaultName.all.include?(rg.name)
        rg.update_attribute(:threshold, ThreeSixty::ReviewerGroup::DefaultThreshold[rg.name])
      end
    end
  end

  def down
    remove_column :three_sixty_reviewer_groups, :threshold
    add_column :three_sixty_surveys, :threshold, :integer, :null => false
  end
end