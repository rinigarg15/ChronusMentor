class AddTermsAndConditionsAcceptedToMembers< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :terms_and_conditions_accepted, :datetime
  end
end
