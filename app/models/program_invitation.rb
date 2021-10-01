# == Schema Information
#
# Table name: program_invitations
#
#  id          :integer          not null, primary key
#  user_id     :integer
#  code        :string(255)
#  created_at  :datetime
#  redeemed_at :datetime
#  sent_to     :string(255)
#  expires_on  :datetime
#  program_id  :integer
#  use_count   :integer          default(0)
#  message     :text(65535)
#  sent_on     :datetime
#  role_type   :integer
#  locale      :string(255)
#

class ProgramInvitation < ActiveRecord::Base
  VALIDITY_IN_DAYS = 30

  module RoleType
    ASSIGN_ROLE = 0
    ALLOW_ROLE = 1

    STRING_TO_TYPE = {
      "assign_roles" => RoleType::ASSIGN_ROLE,
      "allow_roles" => RoleType::ALLOW_ROLE
    }

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  sanitize_attributes_content :message
  acts_as_redeemable :valid_for => VALIDITY_IN_DAYS.days, :code_length => 8
  acts_as_role_based({:skip_validation => true})
  attr_accessor :skip_observer

  ########################
  # Associations
  ########################
  belongs_to :user
  belongs_to_program
  has_many :campaign_jobs,  as: :abstract_object,
    :class_name => 'CampaignManagement::ProgramInvitationCampaignMessageJob',
    :dependent => :destroy
  has_one :status, as: :abstract_object,
          :dependent => :destroy,
          :class_name => "CampaignManagement::ProgramInvitationCampaignStatus"
  has_many :emails,
          :class_name => "CampaignManagement::CampaignEmail",
          :foreign_key => "abstract_object_id"
  has_many  :event_logs,
            :class_name => "CampaignManagement::EmailEventLog",
            :through => :emails
  has_many :job_logs, as: :ref_obj, dependent: :destroy

  ########################
  # Validations
  ########################
  # sent_to will contain the email id of the user for whom this invite was generated
  validates :program, :presence => true
  validates :role_type, presence: true
  # Check format of email id.
  validates :sent_to, :presence => true, :format => {:with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, :message => Proc.new{ "activerecord.custom_errors.program.not_valid_email".translate }}
  validates :role_type, inclusion: {in: RoleType.all}
  validate :check_admin_invite
  validate :check_user_can_invite_others

  ########################
  # Scopes
  ########################
  scope :pending, -> { where( :use_count => 0 )}

  def self.report_to_stream(current_program, stream, selected_ids, current_member)
    headers = kendo_headers.values
    populate_headers(stream, headers)
    pending_invitation_ids, invitation_event_types_hash = get_pending_invitation_ids_and_events_hash(selected_ids, current_program)
    selected_ids_slices = get_selected_ids_slices(selected_ids)
    role_name_custom_term_map = RoleConstants.program_roles_mapping(current_program)

    selected_ids_slices.each_slice(AdminView::CSV_PROCESSES) do |slice|
      Parallel.each(slice, in_processes: AdminView::CSV_PROCESSES) do |ids|
        # Reconnect DB for each fork (once per each)
        @reconnected ||= ProgramInvitation.connection.reconnect!
        ProgramInvitation.connection.select_all(program_invitation_scope.where(id: ids)).each do |invitation_hash|
          status = get_invitation_status(invitation_hash["program_invitation_id"], invitation_hash["status"], pending_invitation_ids, invitation_event_types_hash)
          populate_row(stream, headers, invitation_hash, status: status, current_member: current_member, role_name_custom_term_map: role_name_custom_term_map)
        end
      end
    end
  end

  def self.populate_row(stream, headers, invitation_hash, options = {})
    stream << CSV::Row.new(headers, get_invitation_row(invitation_hash, options[:status], options[:current_member], options[:role_name_custom_term_map])).to_s
  end

  def self.get_pending_invitation_ids_and_events_hash(selected_ids, current_program)
    program_invitation_ids_with_emails = current_program.program_invitations.where(id: selected_ids).joins(:emails).pluck(:abstract_object_id)
    pending_invitation_ids = selected_ids - program_invitation_ids_with_emails

    event_type_query = current_program.program_invitations.joins(:event_logs).select("program_invitations.id, GROUP_CONCAT(DISTINCT(cm_email_event_logs.event_type)) AS event_types").group("program_invitations.id").to_sql
    event_types_hash = Hash[ActiveRecord::Base.connection.exec_query(event_type_query).rows]

    [pending_invitation_ids, event_types_hash]
  end

  def self.program_invitation_scope
    ProgramInvitation.joins(:roles).left_joins(user: :member).select(fields_for_csv).group("program_invitations.id")
  end

  def self.get_selected_ids_slices(selected_ids)
    slice_size = [1 + selected_ids.size / AdminView::CSV_PROCESSES, AdminView::CSV_USER_SLICE_SIZE].min
    selected_ids.each_slice(slice_size).to_a
  end

  def self.populate_headers(stream, headers)
    stream << CSV::Row.new(headers, headers).to_s
  end

  def self.get_invitation_status(program_invitation_id, status, pending_invitation_ids, invitation_event_types_hash)
    status ||= "feature.program_invitations.kendo.filters.checkboxes.statuses.pending".translate if pending_invitation_ids.include?(program_invitation_id)
    status ||=
      if invitation_event_types_hash[program_invitation_id].present?
        events = invitation_event_types_hash[program_invitation_id].split(",").map(&:to_i)
        process_invitation_events(events)
      else
        "feature.program_invitations.kendo.filters.checkboxes.statuses.sent".translate
      end
    status
  end

  def self.get_invitation_row(invitation_hash, status, current_member, role_name_custom_term_map)
    role_names = invitation_hash["role_names"].split(COMMA_SEPARATOR).map { |role_name| role_name_custom_term_map[role_name] }.join(COMMON_SEPARATOR)

    invitation_hash["sent_on"] = DateTime.localize(invitation_hash["sent_on"].in_time_zone(current_member.get_valid_time_zone), format: :full_display_short_month)
    invitation_hash["expires_on"] = DateTime.localize(invitation_hash["expires_on"].in_time_zone(current_member.get_valid_time_zone), format: :full_display_short_month)
    invitation_hash["roles_name"] = (invitation_hash["role_type"] == RoleType::ASSIGN_ROLE) ? role_names : "feature.program_invitations.content.allow_user_to_choose".translate(role: role_names)
    invitation_hash.slice(*kendo_headers.keys).values << status
  end

  def self.process_invitation_events(events)
    if events.include? CampaignManagement::EmailEventLog::Type::CLICKED
      return "feature.program_invitations.kendo.filters.checkboxes.statuses.clicked".translate
    end

    if events.include? CampaignManagement::EmailEventLog::Type::OPENED
      return "feature.program_invitations.kendo.filters.checkboxes.statuses.opened".translate
    end

    if events.include? CampaignManagement::EmailEventLog::Type::DELIVERED
      return "feature.program_invitations.kendo.filters.checkboxes.statuses.delivered".translate
    end

    not_delivered = [CampaignManagement::EmailEventLog::Type::FAILED]

    if !(events & not_delivered).empty?
      return "feature.program_invitations.kendo.filters.checkboxes.statuses.not_delivered".translate
    end
  end

  def self.fields_for_csv
    [
      "program_invitations.id AS program_invitation_id", "program_invitations.sent_to", "program_invitations.sent_on", "program_invitations.expires_on",
      "role_type", "GROUP_CONCAT(roles.name) AS role_names",
      "IF(members.id = NULL, 'Deleted user', CONCAT(members.first_name, ' ', members.last_name)) AS sender",
      "IF(use_count > 0, 'Accepted', IF( expires_on IS NOT NULL && expires_on < NOW(), 'Expired', NULL )) AS status"
    ]
  end

  def self.kendo_headers
    {
      "sent_to" => "feature.program_invitations.label.recipient".translate,
      "sent_on" => "feature.program_invitations.label.sent".translate,
      "expires_on" => "feature.program_invitations.label.valid_until".translate,
      "roles_name" => "display_string.one_or_many_roles".translate,
      "sender" => "feature.program_invitations.label.sender".translate,
      "statuses" => "feature.program_invitations.label.status".translate,
    }
  end

  def self.recent(period)
    where(["program_invitations.created_at > ?", period])
  end

  def self.for_roles(role_names)
    joins(:roles).where("roles.name in (?)", role_names)
  end

  def self.with_fixed_roles
    where("program_invitations.role_type = ?", RoleType::ASSIGN_ROLE)
  end

  def assign_type?
    self.role_type == RoleType::ASSIGN_ROLE
  end

  def allow_type?
    self.role_type == RoleType::ALLOW_ROLE
  end

  def build_member_from_invite
    self.program.organization.members.build(email: self.sent_to)
  end

  def self.non_expired
    where("program_invitations.expires_on IS NOT ? AND program_invitations.expires_on >= ?", nil, Time.now)
  end

  def self.expired
    where("program_invitations.expires_on IS NOT ? AND program_invitations.expires_on < ?", nil, Time.now)
  end

  def self.accepted
    where("program_invitations.use_count > 0")
  end

  def self.unfailed
    where("program_invitations.id NOT IN (?)", self.joins(:event_logs).where("cm_email_event_logs.event_type IN (?)", [CampaignManagement::EmailEventLog::Type::FAILED]).pluck(:id).presence || '')
  end

  def expired?
    (expires_on != nil && expires_on < Time.now) ? true : false
  end

  def self.in_date_range(start_time, end_time)
    where(sent_on: start_time..end_time)
  end

  module KendoScopes
    # This function has to be changed alot!! It uses complex queries as the events are not stored in order (delivered, opened, clicked..) 
    def self.status_filter(filter)
      value = filter["value"]
      case value
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.expired".translate
        ProgramInvitation.pending.expired
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.accepted".translate
        ProgramInvitation.accepted
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.opened".translate
        ProgramInvitation.pending.non_expired.joins(:event_logs).where("cm_email_event_logs.event_type IN (?)", [CampaignManagement::EmailEventLog::Type::OPENED]).distinct
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.clicked".translate
        ProgramInvitation.pending.non_expired.joins(:event_logs).where("cm_email_event_logs.event_type IN (?)", [CampaignManagement::EmailEventLog::Type::CLICKED]).distinct
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.delivered".translate
        ProgramInvitation.pending.non_expired.joins(:event_logs).where("cm_email_event_logs.event_type IN (?)", [CampaignManagement::EmailEventLog::Type::DELIVERED]).distinct
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.not_delivered".translate
        ProgramInvitation.pending.non_expired.joins(:event_logs).where("cm_email_event_logs.event_type IN (?)", [CampaignManagement::EmailEventLog::Type::FAILED]).distinct
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.sent".translate
        ProgramInvitation.where("program_invitations.id is NOT NULL")
      when "feature.program_invitations.kendo.filters.checkboxes.statuses.pending".translate
        ProgramInvitation.pending.non_expired.unfailed
      end
    end

    def self.roles_filter(filter)
      value = filter["value"]
      case value
      when "feature.program_invitations.kendo.filters.checkboxes.roles.allow_roles".translate
        ProgramInvitation.where("program_invitations.role_type = #{RoleType::ALLOW_ROLE}").distinct
      else
        ProgramInvitation.where("program_invitations.role_type = #{RoleType::ASSIGN_ROLE}").joins(:roles).where("roles.name = ?", value).distinct
      end
    end

    def self.roles_sort(dir)
      dir = (dir == "asc") ? "asc" : "desc"

      # TODO_GLOBALIZE: Provision locale based sorting
      ProgramInvitation.joins(roles: { customized_term: :translations } ).
        where(customized_term_translations: { locale: I18n.default_locale } ).
        order("program_invitations.role_type, customized_term_translations.term #{dir}").
        distinct
    end

    def self.sender_sort(dir)
      dir = (dir == "asc") ? "asc" : "desc"
      ProgramInvitation.joins("LEFT JOIN users ON users.id = program_invitations.user_id").joins("LEFT JOIN members ON members.id = users.member_id").order("members.first_name #{dir}").order("members.last_name #{dir}").distinct
    end

    def self.sender_filter(filter)
      value = filter['value']
      name = value.split(" ")
      if name.size > 1
        ProgramInvitation.joins("LEFT JOIN users ON users.id = program_invitations.user_id").joins("LEFT JOIN members ON members.id = users.member_id").where("members.last_name LIKE ? AND members.first_name LIKE ?", "%#{name.second}%", "%#{name.first}%" ).distinct
      else
        ProgramInvitation.joins("LEFT JOIN users ON users.id = program_invitations.user_id").joins("LEFT JOIN members ON members.id = users.member_id").where("members.last_name LIKE ? OR members.first_name LIKE ?", "%#{value}%", "%#{value}%" ).distinct
      end
    end
  end

  def invitee_already_member?
    email = self.sent_to
    program = self.program
    member = program.organization.members.where(email: email).includes(:users => [:roles]).first
    user = member.users.find {|user| user.program_id == program.id} if member

    active_user_exists = member && user && !user.suspended?

    if self.role_type == ProgramInvitation::RoleType::ALLOW_ROLE
      return active_user_exists
    else
      return active_user_exists && self.role_names.all?{|role| user.has_role?(role)}
    end
  end

  def days_since_sent
    # If there's a sent on, it overrides created_at
    ((Time.now - (self.sent_on || self.created_at)) / 1.day).round
  end

  def sent_to_member
    self.program.organization.members.find_by(email: self.sent_to)
  end

  # This can be completely removed, and we can use the generickendo filter
  def self.get_filtered_pending_invitations(program, filters)
    invitations = program.program_invitations.includes([:user, :roles]).pending
    invitations = invitations.non_expired unless filters[:include_expired_invitations].present?
    invitations = invitations.in_date_range(filters[:sent_between_start_time].beginning_of_day, filters[:sent_between_end_time].end_of_day) if filters[:sent_between].present?
    invitations = invitations.unfailed
    return invitations
  end

  def get_current_programs_program_invitation_campaign
    return program.program_invitation_campaign
  end

  def get_first_job
    campaign = get_current_programs_program_invitation_campaign
    first_program_invitation_campaign_message_id = campaign.campaign_messages.sort_by(&:duration).first.id
    return campaign_jobs.pending.where(:abstract_object_id => self.id, :campaign_message_id => first_program_invitation_campaign_message_id)
  end

  def update_use_count
    self.use_count += 1
    self.save
  end

  def is_sender_admin?
    self.user.present? && self.user.is_admin?
  end

  # Can be one invitation or many
  def self.send_invitations(program_invitation_ids, program_id, inviter_id, options)
    return unless program_invitation_ids.present?
    program = Program.find_by(id: program_id)
    inviter = program.users.find(inviter_id)

    program_invitations = ProgramInvitation.where(id: program_invitation_ids).includes(:user => [:roles], :program => [:program_invitation_campaign => [:translations]])
    campaign = CampaignManagement::ProgramInvitationCampaign.where(program_id: program_id).includes(:campaign_messages, :statuses).first
    campaign.stop_program_invitation_campaign(program_invitations.collect(&:id))
    JobLog.compute_with_historical_data(program_invitations, campaign, options[:action_type] || "Sending Invitations", campaign.version_number, { parallel_processing: true, batch_processing: true }) do |program_invitation|
      program_invitation.send_invitation(campaign, options)
      campaign.versions.create(whodunnit: inviter.id, event: ChronusVersion::Events::UPDATE)
    end
  end

  def send_invitation(campaign, options)
    self.update_attributes(sent_on: Time.now, skip_observer: true) if options[:skip_sending_instantly]
    self.update_column(:expires_on, self.sent_on + self.valid_for) if options[:update_expires_on]
    # only admin can send invitation using program invitation campaign. End user can invite by invite_notification email.
    # If at all, ther is some error in the below set of lines which are executed the Program Index page Sent on will be updated but status will be Pending
    if options[:is_sender_admin]
      #incase of program_invitation resend clear all pending jobs(stop campaign) and start campaign
      campaign.stop_program_invitation_campaign([self.id]) unless options[:skip_sending_instantly]
      campaign.start_program_invitation_campaign_and_send_first_campaign_message(self)
    elsif self.user.present?
      # end user sending invitations will be triggered here
      ChronusMailer.invite_notification(self, sender: self.user).deliver_now
    end
  end

  protected

  # Check whether the invitor has necessary privilege.
  def check_admin_invite
    return unless self.role_names.include?(RoleConstants::ADMIN_NAME)

    if !self.user.can_invite_admins?
      self.errors.add(:user, "activerecord.custom_errors.program.cant_invite_admin".translate(admin: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term))
    end
  end

  # Check whethere the invitor can invite friends
  def check_user_can_invite_others
    return unless self.user && self.program
    return if is_sender_admin?

    unless (self.user.can_invite_roles?)
      self.errors.add(:user, "activerecord.custom_errors.program.invitation_disalbed".translate(program: self.program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term))
    end
  end

  def to_dormant_member?
    member = self.sent_to_member
    member.present? && member.dormant?
  end

end
