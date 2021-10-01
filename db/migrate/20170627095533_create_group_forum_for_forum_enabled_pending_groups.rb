class CreateGroupForumForForumEnabledPendingGroups< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Group.pending.joins(:mentoring_model).where(mentoring_models: { allow_forum: true }).find_each { |group| group.create_group_forum }
    end
  end

  def down
  end
end
