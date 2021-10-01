class AddMemberIdToManager< ActiveRecord::Migration[4.2]
  def change
    add_column :managers, :member_id, :integer
    add_index :managers, :member_id

    Manager.reset_column_information
    ActiveRecord::Base.transaction do
      Manager.includes(:profile_answer => :profile_question).find_each do |manager|
        mid = Member.of_organization(manager.profile_answer.profile_question.organization_id).where(:email => manager.email).pluck(:id).try(:first)
        if mid.present?
          manager.member_id = mid
          manager.save!
        end
      end
    end

  end
end
