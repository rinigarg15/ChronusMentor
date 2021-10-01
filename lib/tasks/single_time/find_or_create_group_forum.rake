namespace :single_time do
  desc "create forum for open/closed groups"
  task find_or_create_group_forum: :environment do
    Common::RakeModule::Utils.execute_task do
      mentoring_model_ids = MentoringModel.where(allow_forum: true).pluck(:id)
      group_ids = Group.where(mentoring_model_id: mentoring_model_ids).where(status: Group::Status::OPEN_CRITERIA + [Group::Status::CLOSED] + [Group::Status::WITHDRAWN]).pluck(:id)
      group_ids -= Forum.where.not(group_id: nil).pluck(:group_id)
      Group.where(id: group_ids).includes(:members).each do |group|
        group.create_forum!(name: "group_forum_#{group.id}", program_id: group.program_id)
        group.send(:handle_forum_subscriptions, group.members)
      end
    end
  end
end
