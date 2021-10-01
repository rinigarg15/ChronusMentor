# == Schema Information
#
# Table name: connection_memberships
#
#  id                                 :integer          not null, primary key
#  group_id                           :integer          not null
#  user_id                            :integer          not null
#  created_at                         :datetime
#  updated_at                         :datetime
#  status                             :integer          default(0), not null
#  type                               :string(255)
#  last_status_update_at              :datetime
#  api_token                          :string(255)
#  notification_setting               :integer          default(0)
#  last_update_sent_time              :datetime         default(Tue, 26 Feb 2013 06:23:49 UTC +00:00)
#  login_count                        :integer          default(0)
#  role_id                            :integer
#  owner                              :boolean          default(FALSE)
#  last_applied_task_filter           :string(255)
#

class Connection::MentorMembership < Connection::Membership
  # Validate that the user is a mentor
  validate do |membership|
    if membership.user && !membership.user.is_mentor?
      membership.errors.add(:base, "activerecord.custom_errors.membership.cannot_be_mentor_v1".translate(user_name: membership.user.name, mentor: membership.user.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).articleized_term_downcase))
    end
  end
end
