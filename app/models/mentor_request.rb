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

class MentorRequest < AbstractRequest
  include MentorRequestElasticsearchQueries
  include MentorRequestElasticsearchSettings

  CSV_PROCESSES = 4
  CSV_REPORT_SLICE_SIZE = 2500

  # Relationships
  belongs_to_student_with_validations :student, foreign_key: :sender_id
  belongs_to_mentor_with_validations :mentor, foreign_key: :receiver_id, validate_presence: false, touch: true
  belongs_to :group

  has_many :request_favorites, dependent: :destroy
  has_many :favorites, through: :request_favorites
  has_many :recent_activities, as: :ref_obj, dependent: :destroy
  has_many :push_notifications, as: :ref_obj, dependent: :destroy
  belongs_to :closed_by, foreign_key: :closed_by_id, class_name: "User"

  # Validations
  validates :message, presence: true
  validates_permission_of :student, :send_mentor_request, on: :create
  validates :closed_at, presence: true, if: Proc.new { |req| req.closed? }

  # The student can send as many requests, as long as none of them has been accepted or none is pending.
  validates_uniqueness_of :sender_id, scope: [:program_id, :receiver_id, :status],
    if: Proc.new { |m_req| m_req.program && m_req.program.matching_by_mentee_alone? && (m_req.status == AbstractRequest::Status::NOT_ANSWERED) }

  validate :check_program_membership
  validate :check_mentor_is_mentor
  validate :check_mentor_is_active, on: :create
  validate :check_connection_limit_for_mentee, on: :create
  validate :check_pending_request_limit_for_mentee, on: :create
  validate :check_min_preferred_mentors_limit, on: :create
  validate :check_mentor_blank_if_admin_match_program, on: :create
  validate :check_program_allows_mentoring_requests
  validate :check_if_student_can_connect_to_mentor, on: :create

  scope :involving, Proc.new {|member_ids|
    where(sender_id: member_ids, receiver_id: member_ids)
  }

  MASS_UPDATE_ATTRIBUTES = {
    create: [:message, :receiver_id]
  }
  attr_accessor :rejector, :skip_observer

  def self.to_be_closed
    self.closable('mentor_request_expiration_days')
  end

  # Returns whether the user has access to mentor requests in the given program.
  # True if mentor in loosely managed programs and 'mange_mentor_requests'
  # permission in tightly managed program.
  def self.has_access?(user, program)
    program.member?(user) && ((program.matching_by_mentee_alone? && user.can_view_received_mentor_requests?) ||
          (program.matching_by_mentee_and_admin? && user.can_manage_mentor_requests?))
  end

  # Make the current request accepted and create a group
  def mark_accepted!(group = nil)
    return unless self.active?
    # Note that we are not handling the error case in group creation assuming
    # it wont ideally happen since the mentor request itself takes care of
    # all necessary validations
    my_students = self.mentor.students(:active_or_drafted) + [self.student]
    if my_students.uniq.size > self.mentor.max_connections_limit
      return false
    end

    if self.program.allow_one_to_many_mentoring? && (group && group.mentors.include?(self.mentor))
      student_objs = group.students + [self.student]
      group.update_members(group.mentors, student_objs)
    else
      group = Group.involving(self.student, self.mentor).first
      group ||= self.program.groups.create!({
        students: [self.student],
        mentors:  [self.mentor],
      })
    end
    self.update_attributes(group: group, status: AbstractRequest::Status::ACCEPTED)
    MentorOffer.auto_withdraw(group.reload)
  end

  def receivers
    if self.program.matching_by_mentee_and_admin?
      self.program.admin_users
    elsif self.program.matching_by_mentee_alone?
      [self.mentor]
    end
  end

  # Fills the request by either assigning the given mentor or assigning the student to the given group.
  # In either case, returns the group that was either created or updated.
  # Note that this method <b>does not throw</b> any exceptions and it is upto
  # the caller to check the group record for errors and act accordingly.
  #
  # ==== Params
  # * <tt>mentor_or_group</tt>: either a <i>mentor</i> whom to assign the student to
  # or a <i>group</i> to which to assign to.
  #
  def assign_mentor!(mentor_or_group, options = {})
    mentor_assignment_success = if mentor_or_group.is_a?(Group) # Add the student to the given group
      group = mentor_or_group
      students = [self.student, group.students].flatten
      group.update_members(group.mentors, students)
    else
      # Create a new group with the mentor and the student.
      group = self.program.groups.new(mentors: [mentor_or_group].compact, students: [self.student], created_by: options[:created_by])
      group.mentoring_model = options[:mentoring_model] if options[:mentoring_model]
      group.save
    end
    self.update_attributes!(group_id: group.id, status: AbstractRequest::Status::ACCEPTED) if mentor_assignment_success
    return group
  end

  # For the mentor request we find the user favorites sent by the student and
  # build corresponding request favorites
  #
  def build_favorites(favorite_mentor_ids)
    favorite_mentor_ids.each_with_index do |mentor_id, i|
      # Ignore empty preference.
      next if mentor_id.blank?

      req_fav = self.request_favorites.build(
        :user_id => self.student.id,
        :favorite_id => mentor_id,
        :position => i + 1
      )

      req_fav.mentor_request = self
    end
  end

  def self.sort_by_student(requests, program)
    if program.sort_users_by == Program::SortUsersBy::LAST_NAME
      requests.sort { |a,b| a.student.last_name.downcase <=> b.student.last_name.downcase }
    else
      requests.sort { |a,b| a.student.name.downcase <=> b.student.name.downcase }
    end
  end

  def self.generate_and_email_report(admin, mentor_requests_ids, filter, format = :pdf, job_uuid = nil, locale=I18n.locale)
    GlobalizationUtils.run_in_locale(locale) do
      JobLog.compute_with_uuid(admin, job_uuid, "MentorRequest Export") do |admin_user_object|
        program = admin_user_object.program
        mentor_requests = MentorRequest.where(id: mentor_requests_ids)

        report_data = case format
        when :pdf
          MentorRequestReport::PDF.generate(mentor_requests, filter)
        when :csv
          MentorRequestReport::CSV.generate(program, mentor_requests)
        end
        report_file_name = export_file_name(program, filter == 'active' ? 'pending' : filter, format)

        ChronusMailer.mentor_requests_export(admin_user_object, report_file_name, report_data).deliver_now
      end
    end
  end

  # Returns an Array of headers suitable to be used as the header for exporting
  # to csv format.
  def self.header_for_exporting
    # Default fields.
    header = [
      'feature.mentor_request.label.Sender'.translate,
      'feature.mentor_request.label.Recipient'.translate,
      'feature.mentor_request.label.Request'.translate,
      'feature.mentor_request.label.Sent'.translate
    ]
  end

  # Returns an Array of data for exporting the <i>mentor_requests</i>.
  #
  # ==== Params
  # * <tt>mentor_requests</tt>: the MentorRequests to export
  #
  def self.data_for_exporting(mentor_requests)
    data_array = []
    mentor_requests.each do |m_req|
      sent = DateTime.localize(m_req.created_at, format: :short)
      data_array << [m_req.student.name, m_req.mentor.name, m_req.message.to_s.strip, sent]
    end
    data_array
  end

  def self.export_file_name(program, filter, format)
    "#{'manage_strings.program.Administration.Connection.Mentor_Requests_v1'.translate(:Mentoring => program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term)}-#{"feature.mentor_request.status.#{filter}".translate}-#{DateTime.localize(Time.now, format: :pdf_timestamp)}.#{format}"
  end

  def self.export_to_stream(stream, admin, request_ids)
    slice_size = [1 + request_ids.size / CSV_PROCESSES, CSV_REPORT_SLICE_SIZE].min
    program = admin.program
    headers = MentorRequest.header_for_exporting
    stream << CSV::Row.new(headers, headers).to_s

    parallel_processor.each(request_ids.each_slice(slice_size), in_processes: CSV_PROCESSES) do |ids|
      # Reconnect DB for each fork (once per each)
      @reconnected ||= MentorRequest.connection.reconnect!
      mentor_requests = program.mentor_requests.where(id: ids).select([:sender_id, :receiver_id, :message, :created_at])

      MentorRequest.data_for_exporting(mentor_requests).each do |row_data|
        stream << CSV::Row.new(headers, row_data).to_s
      end
    end
  end

  def self.send_close_request_mail(mentor_requests, mail_to_sender, mail_to_recipient)
    mentor_requests.each do |mentor_request|
      mentor_request.student.send_email(mentor_request, RecentActivityConstants::Type::MENTOR_REQUEST_CLOSED_SENDER) if mail_to_sender
      mentor_request.mentor.send_email(mentor_request, RecentActivityConstants::Type::MENTOR_REQUEST_CLOSED_RECIPIENT) if mail_to_recipient
    end
  end

  def self.send_mails(mentor_request, receiver, mail_type, options = {})
    template = RecentActivityConstants::EmailTemplate[mail_type]
    ChronusMailer.send(template, receiver, mentor_request, options).deliver_now
  end

  def self.send_mentor_request_reminders
    current_time = DateTime.now.utc

    BlockExecutor.iterate_fail_safe(Program.active) do |program|
      next unless program.needs_mentoring_request_reminder? && program.matching_by_mentee_alone?

      start_time = (current_time - program.mentoring_request_reminder_duration.days).at_beginning_of_day
      end_time = start_time.end_of_day
      mentor_requests = program.mentor_requests.active.where(reminder_sent_time: nil).where(created_at: start_time..end_time).includes(:mentor)

      BlockExecutor.iterate_fail_safe(mentor_requests) do |mentor_request|
        mentor_request.update_attributes!(reminder_sent_time: current_time)
        Push::Base.queued_notify(PushNotification::Type::MENTOR_REQUEST_REMINDER, mentor_request, recipients: mentor_request.mentor)
        ChronusMailer.mentor_request_reminder_notification(mentor_request.mentor, mentor_request).deliver_now
      end
    end
  end

  def close_request!
    self.close!('feature.mentor_request.tasks.expired_message_v1'.translate(mentor: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase, expiration_days: program.mentor_request_expiration_days))
  end

  def self.notify_expired_mentor_requests
    BlockExecutor.iterate_fail_safe(self.to_be_closed.includes(:program)) do |mentor_request|
      mentor_request.close_request!

      # Send Mail only for Mentor Request to Mentor Mode
      if mentor_request.program.matching_by_mentee_alone?
        ChronusMailer.mentor_request_expired_to_sender(mentor_request.student, mentor_request).deliver_now
      end
    end
  end

  def sender_name
    self.student.name(name_only: true)
  end

  def receiver_name
    self.mentor.name(name_only: true)
  end

  # Use this method during mentor related scenarios like mentor_rejection, meeting_creation, etc.
  def can_convert_to_meeting_request?
    self.allow_request_type_change_from_mentor_to_meeting? && self.active? && self.program.dual_request_mode?(self.mentor, self.student)
  end

  protected

  def check_mentor_is_mentor
    if self.program.try(:matching_by_mentee_alone?) && !self.mentor.try(:can_view_received_mentor_requests?)
      errors.add(:mentor, "activerecord.custom_errors.mentor_request.not_mentor".translate(mentor: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term))
    end
  end

  def check_mentor_is_active
    errors.add(:mentor, "activerecord.custom_errors.mentor_request.must_be_active".translate) if self.mentor and !self.mentor.active?
  end

  def check_min_preferred_mentors_limit
    if self.student && self.program.try(:matching_by_mentee_and_admin_with_preference?) && (self.request_favorites.size < self.program.min_preferred_mentors)
      errors.add(:student, "activerecord.custom_errors.mentor_request.min_preferred_mentors".translate(preferred_mentors: self.program.min_preferred_mentors, mentors: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term))
    end
  end

  def check_mentor_blank_if_admin_match_program
    if self.program.try(:matching_by_mentee_and_admin?) && self.mentor.present?
      errors.add(:mentor, "activerecord.custom_errors.mentor_request.cant_be_present".translate)
    end
  end

  def check_connection_limit_for_mentee
    if self.program && self.student
      errors.add(:student, "activerecord.custom_errors.mentor_request.mentors_limit".translate) if self.student.connection_limit_as_mentee_reached?
    end
  end

  def check_pending_request_limit_for_mentee
    if self.program && self.student && self.student.pending_request_limit_reached_for_mentee?
      errors.add(:student, "activerecord.custom_errors.mentor_request.pending_requests_limit".translate)
    end
  end

  def check_program_allows_mentoring_requests
    if self.program && self.student && self.new_record?
      errors.add(:program, "activerecord.custom_errors.mentor_request.blocked_by_program".translate) unless self.program.allow_mentoring_requests?
    end
  end

  def self.es_reindex(mentor_request)
    DelayedEsDocument.do_delta_indexing(User, Array(mentor_request), :receiver_id)
  end

  private

  # Validates membership of student and mentor in the program
  def check_program_membership
    # We do program presence check since this can be called before program
    # presence validation.
    return unless self.program
    if self.student
      self.errors.add(:student, "activerecord.custom_errors.mentor_request.not_program_member".translate) unless self.student.member_of?(self.program)
      self.errors.add(:base, "activerecord.custom_errors.mentor_request.self_mentor_request".translate) if self.student == self.mentor
    end

    if self.mentor
      self.errors.add(:mentor, "activerecord.custom_errors.mentor_request.not_program_member".translate) unless self.mentor.member_of?(self.program)
    end
  end

  def check_if_student_can_connect_to_mentor
    if self.program && self.student && self.mentor
      errors.add(:base, self.program.zero_match_score_message) unless self.student.can_connect_to_mentor?(mentor)
    end
  end

  def self.parallel_processor
    Parallel
  end
end
