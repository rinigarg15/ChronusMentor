class MentoringModel::ActivityObserver < ActiveRecord::Observer
  def after_create(activity)
    RecentActivity.create!(
      :programs => [activity.user.program],
      :ref_obj => activity.ref_obj.group,
      :action_type => RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY,
      :member => activity.user.member,
      :target => RecentActivityConstants::Target::NONE
    )
  end
end