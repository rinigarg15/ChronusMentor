class AddToDefaultAbstractViewsForProgramManagementReport< ActiveRecord::Migration[4.2]
  def up
  	new_admin_view = AdminView::DefaultViews::USERS_WITH_LOW_PROFILE_SCORES
    Program.active.find_each do |program|
      attr_hsh = new_admin_view.call(program)
      attrs = Hash[attr_hsh.to_a.map{|k, v| [k, v.call]}]
      attrs.merge!(program_id: program.id)

      abstract_view = AdminView.create!(attrs)
      abstract_view.create_default_columns
    end
  end

  def down
  end
end
