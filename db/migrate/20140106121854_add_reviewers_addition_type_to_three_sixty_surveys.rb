class AddReviewersAdditionTypeToThreeSixtySurveys< ActiveRecord::Migration[4.2]
  def change
    add_column :three_sixty_surveys, :reviewers_addition_type, :integer, :null => false, :default => 0
  end
end
