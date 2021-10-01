# == Schema Information
#
# Table name: mentor_requests
#
#  id                 :integer          not null, primary key
#  program_id         :integer
#  created_at         :datetime
#  updated_at         :datetime
#  status             :integer          default(0)
#  sender_id          :integer
#  receiver_id        :integer
#  message            :text(65535)
#  response_text      :text(65535)
#  group_id           :integer
#  show_in_profile    :boolean          default(TRUE)
#  type               :string(255)      default("MentorRequest")
#  delta              :boolean          default(FALSE)
#  closed_by_id       :integer
#  closed_at          :datetime
#  reminder_sent_time :datetime
#  sender_role_id     :integer
#  accepted_at        :datetime
#  acceptance_message :text(65535)
#

class ProjectRequest < AbstractRequest
  include ProjectRequestElasticsearchQueries
  include ProjectRequestElasticsearchSettings

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:group_id, :message]
  }

  STATUS_KEYS = [
      AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED],
      AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::ACCEPTED],
      AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::REJECTED],
      AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::WITHDRAWN],
      AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::CLOSED]
  ]

  module VIEW
    TO   = 0
    FROM = 1
    def self.all
      [TO, FROM]
    end
  end

  # Relationships
  belongs_to :group, inverse_of: :project_requests
  belongs_to :sender, foreign_key: "sender_id", class_name: "User"
  belongs_to :receiver, foreign_key: "receiver_id", class_name: "User"
  belongs_to :role, foreign_key: "sender_role_id", class_name: "Role"

  # Validations
  validates :message, :sender, :group, presence: true
  validates :sender_id, uniqueness: { scope: [:program_id, :group_id, :status], if: Proc.new {|req| req.active? }}

  validate :check_program_membership

  def self.send_request_change_mail(project_request_ids, activity_type)
    project_requests = ProjectRequest.find(project_request_ids)
    project_requests.each do |project_request|
      project_request.sender.send_email(project_request, activity_type)
    end
  end

  def self.send_emails_to_admins_and_owners(project_request_id, job_uuid)
    project_request = ProjectRequest.find_by(id: project_request_id)
    return if project_request.nil?

    program = project_request.program
    owners = project_request.group.owners
    users_to_notify = (program.admin_users + owners).uniq
    JobLog.compute_with_uuid(users_to_notify, job_uuid, "Project Request emails to admins") do |user|
      ChronusMailer.new_project_request_to_admin_and_owner(user, project_request, sender: project_request.sender).deliver_now
    end
  end

  def self.notify_expired_project_requests
    project_requests = self.closable('circle_request_auto_expiration_days').includes(:program)

    BlockExecutor.iterate_fail_safe(project_requests) do |project_request|
      project_request.close_request!
      ChronusMailer.circle_request_expired_notification_to_sender(project_request.sender, project_request).deliver_now
    end
  end

  def close_request!(message = nil)
    message ||= 'feature.project_request.content.auto_expire_message'.translate(expiration_days: program.circle_request_auto_expiration_days)
    self.close!(message)
  end

  def mark_accepted(acceptor, add_defaults_tasks = true)
    return unless self.active?
    add_defaults_tasks &&= self.group.active?

    group = self.group
    group.skip_observer = true
    other_roles_hash = {}
    group.custom_memberships.includes(:user, :role).each do |membership|
      (other_roles_hash[membership.role] ||= []) << membership.user
    end

    new_members_with_no_default_tasks = [self.sender_id] unless add_defaults_tasks
    group_mentors, group_students, other_roles_hash = build_group_update_members_list(group, other_roles_hash)

    if group.update_members(group_mentors, group_students, acceptor, new_members_with_no_default_tasks: new_members_with_no_default_tasks, other_roles_hash: other_roles_hash)
      ProjectRequest.delay(queue: DjQueues::HIGH_PRIORITY).send_request_change_mail([self.id], RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED)
      Push::Base.queued_notify(PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT, self)
    end
  end

  def build_group_update_members_list(group, other_roles_hash)
    group_mentors = group.mentors.to_a
    group_students = group.students.to_a
    requested_role = self.role
    if requested_role.mentor?
      group_mentors << self.sender
    elsif requested_role.mentee?
      group_students << self.sender
    else
      (other_roles_hash[requested_role] ||= []) << self.sender
    end
    return group_mentors, group_students, other_roles_hash
  end

  def self.send_project_request_reminders
    current_time = Time.now.utc
    programs = Program.active.project_based.where(needs_project_request_reminder: true)

    BlockExecutor.iterate_fail_safe(programs) do |program|
      start_time = (current_time - program.project_request_reminder_duration.days).beginning_of_day
      end_time = start_time.end_of_day
      project_requests = program.project_requests.active.where(reminder_sent_time: nil).where(created_at: start_time..end_time).includes(group: :owners)

      BlockExecutor.iterate_fail_safe(project_requests) do |project_request|
        BlockExecutor.iterate_fail_safe(project_request.group.owners) do |owner|
          project_request.update_attributes!(reminder_sent_time: current_time)
          ChronusMailer.project_request_reminder_notification(owner, project_request).deliver_now
        end
      end
    end
  end

  def self.mark_rejected(project_request_ids, receiver, response_text = nil, status = AbstractRequest::Status::REJECTED, options = {send_email: true})
    project_requests = ProjectRequest.active.where(id: project_request_ids)
    project_requests.each do |project_request|
      project_request.response_text = response_text
      project_request.status = status
      # This is not exposed anywhere in UI currently and just for the bookkeeping.
      project_request.receiver = receiver
      project_request.save!
      Push::Base.queued_notify(PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT, project_request)
    end
    ProjectRequest.delay.send_request_change_mail(project_requests.collect(&:id), RecentActivityConstants::Type::PROJECT_REQUEST_REJECTED) if options[:send_email]
  end

  def self.es_reindex(project_request)
    DelayedEsDocument.do_delta_indexing(Group, Array(project_request), :group_id)
  end

  def withdraw!(response_text)
    self.update_attributes!(status: AbstractRequest::Status::WITHDRAWN, response_text: response_text)
  end

  def with_role?(role)
    self.sender_role_id == role.id
  end

  def self.close_pending_requests_if_required(user_id_role_id_hash)
    users = User.where(id: user_id_role_id_hash.keys).includes(:sent_project_requests, connection_memberships: [:group, :role])
    roles = Role.where(id: user_id_role_id_hash.values)
    users.each do |user|
      role = roles.find{ |r| r.id == user_id_role_id_hash[user.id] }
      next if user.allow_project_requests_for_role?(role)
      user.get_active_sent_project_requests_for_role(role).collect{ |request| request.close_request!('feature.project_request.content.limit_reached'.translate(mentoring_connection: role.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) }
    end
  end

  def self.get_project_request_path_for_privileged_users(user, params = {})
    program = user.program
    organization = program.organization
    params.merge!(root: program.root, subdomain: organization.subdomain, host: organization.domain)
    user.can_manage_project_requests? ? Rails.application.routes.url_helpers.manage_project_requests_url(params) : Rails.application.routes.url_helpers.project_requests_url(params)
  end

  private

  def check_program_membership
    return unless self.program
    if self.sender && !self.sender.member_of?(self.program)
      self.errors.add(:sender, "activerecord.custom_errors.project_request.not_program_member".translate)
    end

    if self.group && self.group.program != self.program
      self.errors.add(:group, "activerecord.custom_errors.project_request.not_program_group".translate)
    end
  end
end
