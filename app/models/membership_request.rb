# == Schema Information
#
# Table name: membership_requests
#
#  id               :integer          not null, primary key
#  email            :string(255)
#  program_id       :integer
#  created_at       :datetime
#  updated_at       :datetime
#  status           :integer          default(0)
#  response_text    :text(65535)
#  admin_id         :integer
#  deleted_at       :datetime
#  accepted_as      :string(255)
#  response_subject :string(255)
#  first_name       :string(255)
#  last_name        :string(255)
#  joined_directly  :boolean          default(FALSE)
#  member_id        :integer
#

class MembershipRequest < ActiveRecord::Base
  include GenerateZipFile
  include EmailFormatCheck

  MASS_UPDATE_ATTRIBUTES = {
    :bulk_update => [:status, :response_text],
    :membership_request_creation => [:first_name, :last_name, :email, :status, :accepted_as, :joined_directly],
    :member_creation => [:first_name, :last_name, :email],
    :update => [:first_name, :last_name, :email]
  }

  acts_as_role_based

  class Status
    UNREAD = 0
    ACCEPTED = 1
    REJECTED = 2
  end

  class FilterStatus
    PENDING = 'pending'
    ACCEPTED = 'accepted'
    REJECTED = 'rejected'
  end

  class ListStyle
    DETAILED = 0
    LIST = 1
  end

  module Source
    MEMBERSHIP_REQUEST_PAGE = 'membership_request_page'
  end

  PER_PAGE_OPTIONS = [10, 25, 50, 100]
  CSV_PROCESSES = 4
  CSV_REPORT_SLICE_SIZE = 2500

  SEPARATOR = ','

  belongs_to_program
  belongs_to :admin, foreign_key: "admin_id", class_name: "User"
  belongs_to :member

  # The request has many answers from users which form the request. The ordering
  # is by the question position
  has_many :recent_activities, as: :ref_obj, dependent: :destroy
  has_many :profile_answers, through: :member

  validates :last_name, :email, :program, presence: true
  validates :admin, presence: true, if: :answered_and_not_joined_directly?
  validates :member, presence: true, on: :create
  validates :email, email_format: { generate_message: true, check_mx: false}
  validates :status, inclusion: { in: [Status::UNREAD, Status::ACCEPTED, Status::REJECTED] }, allow_nil: true

  #Validation to avoid Numeric characters in the first_name and the last_name
  validates :first_name, :format => {:with => RegexConstants::RE_NO_NUMBERS, :message => ->(err,hsh){RegexConstants::MSG_NAME_INVALID.translate} }
  validates :last_name, :format => {:with => RegexConstants::RE_NO_NUMBERS, :message => ->(err,hsh){RegexConstants::MSG_NAME_INVALID.translate} }
  validate :check_rejection_has_reason, :validate_admin_should_be_present_for_accepted_or_rejected_request, :check_accepted_as, :check_member_be_non_suspended
  validate :validate_uniqueness_of_request, :check_suspended_user_cannot_join_directly, on: :create
  validate :check_email_format

  scope :pending, -> { where(status: MembershipRequest::Status::UNREAD) }
  scope :accepted, -> { where(status: MembershipRequest::Status::ACCEPTED) }
  scope :rejected, -> { where(status: MembershipRequest::Status::REJECTED) }
  scope :by_name_asc, -> { order(last_name: :asc) }
  scope :by_name_desc, -> { order(last_name: :desc) }
  scope :by_time_desc, -> { order(id: :desc) }
  scope :by_time_asc, -> { order(id: :asc) }
  scope :order_by, ->(field, direction) { order("membership_requests.#{field} #{direction}") }
  scope :not_joined_directly, -> { where(joined_directly: false) }

  attr_accessor :captcha, :captcha_key, :skip_observer

  # Creates answers with data in the map <i>question_id_to_answer_map</i>
  #
  # ==== Params
  # * <tt>program<tt> : the Program for which to create the membership request
  # * <tt>attrs</tt> : Hash of attributes for the request
  #
  def self.create_from_params(program, attrs, wob_member = nil, params = {})
    roles = params[:roles] || attrs[:roles]
    attrs.delete(:roles)
    membership_request = program.membership_requests.new(attrs)
    membership_request.member = wob_member || program.organization.members.find_by(email: membership_request.email)
    membership_request.role_names = roles
    membership_request.save
    if membership_request.errors.blank?
      profile_question_ids = membership_request.profile_answers.present? ? membership_request.profile_answers.pluck(:profile_question_id) : []
      membership_request_member =  membership_request.member
      if membership_request_member.present? && profile_question_ids.present?
        Member.delay.clear_invalid_answers(membership_request_member.id, membership_request_member.class, membership_request.program.organization.id, profile_question_ids)
      end
    end
    membership_request
  end

  def name
    "#{self.first_name} #{self.last_name}"
  end

  def accepted?
    self.status == Status::ACCEPTED
  end

  def rejected?
    self.status == Status::REJECTED
  end

  def pending?
    self.status == Status::UNREAD
  end

  def answered?
    !pending?
  end

  def answered_and_not_joined_directly?
    answered? && !self.joined_directly?
  end

  def closed_by
    self.admin
  end

  def closed_at
    self.updated_at
  end

  def for_single_role?
    self.roles.count == 1
  end

  def for_mentor_role?
    self.role_names.include?(RoleConstants::MENTOR_NAME)
  end

  # Returns an Array of headers suitable to be used as the header for exporting
  # to csv or pdf format.
  def self.header_for_exporting(program, tab = '')
    # Default fields.
    header = [
      "activerecord.attributes.member.first_name".translate,
      "activerecord.attributes.member.last_name".translate,
      "activerecord.attributes.member.email".translate,
      "feature.connection.content.join_as".translate,
      "feature.membership_request.label.sent".translate,
      "feature.membership_request.label.status".translate
    ]
    accepted_mem_req_header = [
      "feature.membership_request.label.accepted_by".translate,
      "feature.membership_request.label.accepted_on".translate
    ]
    rejected_mem_req_header = [
      "feature.membership_request.label.rejected_by".translate,
      "feature.membership_request.label.rejected_on".translate,
      "feature.membership_request.label.rejection_reason".translate
    ]
    case tab
      when MembershipRequest::FilterStatus::ACCEPTED
        header += accepted_mem_req_header
      when MembershipRequest::FilterStatus::REJECTED
        header += rejected_mem_req_header
    end
    all_membership_questions = program.membership_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).select(&:non_default_type?)

    header += all_membership_questions.group_by(&:question_text).keys
  end

  # Returns an Array of data for exporting the <i>membership_requests</i>.
  # MembershipQuestions with similar text will be compacted to single entry
  # and the answers will be mapped against the common question text entry.
  # The same logic will be followed by <code>header_for_exporting</i> too so
  # that the header and the data are consistent.
  #
  # ==== Params
  # * <tt>program</tt>: the program for which to generate export data
  # * <tt>membership_requests</tt>: the MembershipRequests to export
  #
  def self.data_for_exporting(program, membership_requests)
    organization = program.organization
    membership_request_ids = membership_requests.map(&:id)

    all_usership_questions = program.membership_questions_for(program.role_names_without_admin_role).select(&:non_default_type?)
    questions_grouped_by_text = all_usership_questions.group_by(&:question_text)
    all_usership_question_ids = all_usership_questions.map(&:id)

    member_ids = membership_requests.map(&:member_id).uniq.compact
    member_answers_by_questions = request_answers_by_conditions(member_ids, all_usership_question_ids)
    role_names_by_requests = role_names_by_request_ids(membership_request_ids)

    data_array = []
    role_names_to_human_string = {}
    membership_requests.each do |mem_request|
      role_names = role_names_by_requests[mem_request.id]
      role_names_to_human_string[role_names] ||= RoleConstants.human_role_string(role_names, program: program)
      role_names_to_human_string[mem_request.accepted_role_names] ||= mem_request.accepted_as_str if mem_request.accepted_as

      request_array = [mem_request.first_name, mem_request.last_name, mem_request.email]
      request_array << role_names_to_human_string[role_names]
      request_array << DateTime.localize(mem_request.created_at, format: :full_display_no_day)
      request_array << membership_request_status_string(mem_request, role_names_to_human_string)
      if mem_request.accepted? || mem_request.rejected?
        request_array << mem_request.closed_by.name
        request_array << DateTime.localize(mem_request.closed_at, format: :full_display_no_day)
        request_array << mem_request.response_text if mem_request.rejected?
      end
      questions_grouped_by_text.each do |q_text, mem_questions|
        request_array << membership_answer_text(mem_request, mem_questions, member_answers_by_questions)
      end
      data_array << request_array
    end
    data_array
  end

  # Generate a report for the given requests and email the requestor
  #
  # ==== Params
  # * <tt>admin</tt>: the requestor whom the email should be sent to
  # * <tt>request_ids</tt>: the requests for which the report should be generated
  # * <tt>tab</tt>: 'accepted' | 'pending' | 'rejected'. Used for report title generation
  # * <tt>sort_scope</tt>: string which has sort_by and sorting order conditions
  # * <tt>format</tt>: the format of the report. 'csv' | 'pdf'
  #

  def self.generate_and_email_report(admin, request_ids, tab, sort_scope, format, job_uuid = nil, locale=I18n.locale)
    GlobalizationUtils.run_in_locale(locale) do
      JobLog.compute_with_uuid(admin, job_uuid, "MembershipRequest Export") do |admin_user_object|
        program = admin_user_object.program
        requests = prepare_requests(program, request_ids, sort_scope)
        report_file_name = export_file_name(format)
        case format
        when :pdf
          report_data = MembershipRequestReport::PDF.generate(program, requests, tab)
        when :csv
          data = MembershipRequestReport::CSV.generate(requests, tab)
          report_data = GenerateZipFile.generate_zip_file(data, report_file_name)
          report_file_name = report_file_name+".zip"
        end
        ChronusMailer.membership_requests_export(admin_user_object, report_file_name, report_data).deliver_now
      end
    end
  end

  def self.export_file_name(format)
    "#{'feature.membership_request.header.membership_requests'.translate}-#{DateTime.localize(Time.now, format: :pdf_timestamp)}.#{format}"
  end

  def self.export_to_stream(stream, admin, request_ids, tab, sort_scope)
    slice_size = [1 + request_ids.size / CSV_PROCESSES, CSV_REPORT_SLICE_SIZE].min
    program = admin.program
    headers = MembershipRequest.header_for_exporting(program, tab)
    stream << CSV::Row.new(headers, headers).to_s

    parallel_processor.each(request_ids.each_slice(slice_size), in_processes: CSV_PROCESSES) do |ids|
      # Reconnect DB for each fork (once per each)
      @reconnected ||= User.connection.reconnect!

      requests = prepare_requests(program, ids, sort_scope)
      MembershipRequestReport::CSV.export_to_stream(stream, requests, tab, false) if requests.present?
    end
  end

  def self.trigger_manager_notification(membership_request_id)
    membership_request = MembershipRequest.find_by(id: membership_request_id)
    if membership_request.present?
      if membership_request.program.organization.manager_enabled?
        manager = membership_request.manager
        membership_request.send_manager_notification(manager) if manager.present?
      end
    end
  end

  def self.send_membership_request_accepted_notification(membership_request_id)
    membership_request = MembershipRequest.accepted.not_joined_directly.find_by(id: membership_request_id)
    user = membership_request.try(:user)
    return if membership_request.blank? || user.blank? || user.suspended?

    ChronusMailer.membership_request_accepted(user, membership_request).deliver_now
  end

  def self.send_membership_request_not_accepted_notification(membership_request_id)
    membership_request = MembershipRequest.rejected.not_joined_directly.find_by(id: membership_request_id)
    return if membership_request.blank?

    ChronusMailer.membership_request_not_accepted(membership_request).deliver_now
  end

  def create_user_from_accepted_request
    user = self.program.build_and_save_user!(
      { creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED },
      self.accepted_role_names,
      self.member,
      { admin: self.admin , send_reactivation_email: true}
    )

    # Reload so that we get all recently copied answers.
    # If all the required fields are filled while copying from the request,
    # Set the user state to 'Active'
    user.reload
    if user.profile_pending? && user.profile_incomplete_roles.empty?
      user.update_attribute(:state, User::Status::ACTIVE)
    end
    user
  end

  # Returns an Array of Roles from the 'accepted_as' string.
  def accepted_role_names
    self.accepted_as && self.accepted_as.split(SEPARATOR)
  end

  # Sets the accepted_as string from the role names.
  def accepted_role_names=(role_names)
    self.accepted_as = role_names.join(SEPARATOR)
  end

  # FIXME: Can the dynamic method in AuthorizationManager#formatted_xxx be somehow
  # used here?
  #
  # <i>accepted_as</i> formatted to human readable string with program specific
  # mentor and mentee names.
  #
  # ==== Params
  # * <tt>opts</tt>: options as accepted by RoleConstants.human_role_string
  #
  def accepted_as_str(opts = {})
    RoleConstants.human_role_string(self.accepted_role_names, {:program => self.program}.merge(opts))
  end

  def user
    self.member.present? ? self.program.all_users.of_member(member.id).first : nil
  end

  # It is needed when we perform a save inside an observer or a function called from an observer
  def skip_observer_and_save
    self.skip_observer = true
    self.save
    self.skip_observer = false
  end

  def self.sorted_by_answer(initial_scope, organization, profile_question_id, sort_order)
    member_ids = initial_scope.pluck(:member_id)
    members_scope = organization.members.where(id: member_ids)
    profile_question = organization.profile_questions.find_by(id: profile_question_id)

    if profile_question.present? && member_ids.present?
      sorted_member_ids = Member.sorted_by_answer(members_scope, profile_question, sort_order, location_scope: :city).collect(&:id)
      initial_scope.order("FIELD(member_id, #{sorted_member_ids.join(', ')})")
    else
      initial_scope
    end
  end

  def manager
    member_manager = self.member.manager
    return nil unless member_manager
    return member_manager if member_manager.profile_answer.present_for(self)
  end

  def send_membership_notification
    ChronusMailer.membership_request_sent_notification(self).deliver_now
  end

  def send_manager_notification(manager)
    manager.program = self.program
    ChronusMailer.manager_notification(manager, self).deliver_now
  end

  private

  def self.request_answers_by_conditions(member_ids, all_usership_question_ids)
    answers_scope = ProfileAnswer.where(profile_question_id: all_usership_question_ids).includes(:answer_choices).
      where(ref_obj_id: member_ids, ref_obj_type: Member.name).
      select([:id, :profile_question_id, :ref_obj_id, :attachment_file_name, :answer_text]).
      group([:profile_question_id, :ref_obj_id])
    answers_by_questions = answers_scope.group_by(&:profile_question_id)
    answers_by_questions.each do |profile_question_id, answers|
      answers_by_questions[profile_question_id] = answers.group_by(&:ref_obj_id)
    end
    answers_by_questions
  end

  def self.role_names_by_request_ids(membership_request_ids)
    roles_by_requests_scope = Role.select('ref_obj_id, name').joins(:role_references).where(:role_references => { ref_obj_id: membership_request_ids, ref_obj_type: MembershipRequest.name })
    Role.connection.select_all(roles_by_requests_scope).inject({}) do |result, req_hash|
      result[req_hash['ref_obj_id']] ||= []
      result[req_hash['ref_obj_id']] << req_hash['name']
      result
    end
  end

  def self.prepare_requests(program, request_ids, sort_scope)
    requests = program.membership_requests.where(id: request_ids).not_joined_directly
    requests = if sort_scope.is_a?(Array) && sort_scope[1] =~ /^question-(\d+)$/
      question_id = $1.to_i
      MembershipRequest.sorted_by_answer(requests, program.organization, question_id, sort_scope[2])
    else
      requests.send(*sort_scope)
    end.to_a
  end

  def check_email_format
    security_setting = self.program.organization.security_setting
    member = self.program.organization.members.find_by(email: self.email)
    validate_email_format(true, self.email, security_setting) unless member.present?
  end

  def check_accepted_as
    if self.accepted? && (self.accepted_role_names.blank? || (self.accepted_role_names - self.role_names).any?)
      errors.add(:accepted_as, "activerecord.custom_errors.membership_request.not_among_requested_roles".translate)
    elsif self.rejected? && self.accepted_role_names.present?
      errors.add(:accepted_as, "activerecord.custom_errors.membership_request.cannot_be_present_when_rejected".translate)
    end
  end

  def validate_admin_should_be_present_for_accepted_or_rejected_request
    if (self.accepted? || self.rejected?) && self.admin.blank? && !self.joined_directly?
      errors.add(:admin, "activerecord.custom_errors.membership_request.admin.blank".translate)
    end
  end

  def check_rejection_has_reason
    if self.rejected? && self.response_text.blank?
      errors.add(:base, "activerecord.custom_errors.membership_request.rejection_reason".translate)
    end
  end

  # We dont allow duplicate requests for a role. If a person makes a request twice with same email to same program, it is duplicate request.
  # A request is considered duplicate only if the latest request made by him is either in the pending state having the same role as the new one.
  def validate_uniqueness_of_request
    return unless self.program
    prev_reqs = self.program.membership_requests.joins(:roles).where("roles.name in (?) AND membership_requests.email = ? AND membership_requests.status = ?", self.role_names , self.email, MembershipRequest::Status::UNREAD)
    if prev_reqs.any?
      errors[:base] << "flash_message.membership.duplicate_request_when_original_is_pending".translate
    end
  end

  def self.parallel_processor
    Parallel
  end

  def self.membership_request_status_string(membership_request, role_names_to_human_string)
    status_string = [
      "feature.membership_request.label.pending".translate,
      "feature.membership_request.label.accepted".translate,
      "feature.membership_request.label.rejected".translate
    ][membership_request.status]

    if membership_request.accepted_as
      accepted_roles_string = role_names_to_human_string[membership_request.accepted_role_names]
      status_string << " #{'display_string.as'.translate} #{accepted_roles_string}"
    end
    status_string
  end

  def self.membership_answer_text(mem_request, mem_questions, member_answers_by_questions)
    q_with_ans = nil
    mem_ans = nil
    # Find the answer to the first question with the text 'q_text'
    mem_questions.each do |mem_q|
      mem_ans = ((member_answers_by_questions[mem_q.id] || {})[mem_request.member_id] || []).first
      if mem_ans
        # Found an answer. Break out of loop
        q_with_ans = mem_q
        break
      end
    end

    if mem_ans
      # Use attachment file name for FILE type answer.
      if q_with_ans.question_type == ProfileQuestion::Type::FILE
        mem_ans.attachment? ? mem_ans.attachment_file_name : nil
      elsif q_with_ans.question_type == ProfileQuestion::Type::DATE
        answer_text = mem_ans.answer_text
        DateTime.localize(Date.parse(answer_text), format: :full_display_no_time) if answer_text.present?
      else
        mem_ans.selected_choices_to_str(q_with_ans)
      end
    else
      nil
    end
  end

  # Suspended members cannot submit membership request and their requests cannot be in pending state.
  def check_member_be_non_suspended
    if self.member.try(:suspended?)
      if self.new_record?
        self.errors.add(:member, "activerecord.custom_errors.membership_request.suspended_member_cannot_apply".translate)
      elsif self.pending?
        self.errors.add(:member, "activerecord.custom_errors.membership_request.suspended_member_request_cannot_be_pending".translate)
      end
    end
  end

  # Suspended users can join only by applying
  def check_suspended_user_cannot_join_directly
    if self.user.try(:suspended?) && self.joined_directly?
      self.errors.add(:joined_directly, "activerecord.custom_errors.membership_request.suspended_user_cannot_join_directly".translate)
    end
  end
end
