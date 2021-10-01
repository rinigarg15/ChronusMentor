class AddMentoringModelIdToGroups< ActiveRecord::Migration[4.2]
  def up
    add_column :groups, :mentoring_model_id, :integer
    add_index :groups, :mentoring_model_id

    say_with_time "Set mentoring model ids" do
      Program.active.find_each do |program|
        mentoring_model = program.default_mentoring_model
        say "#{program.name}", false
        program.groups.includes(:object_role_permissions).find_each do |group|
          group.update_attributes!(mentoring_model_id: mentoring_model.id) if group.object_role_permissions.present?
        end
      end
    end
  end

  def down
    remove_column :groups, :mentoring_model_id
    remove_index :groups, :mentoring_model_id
  end
end
