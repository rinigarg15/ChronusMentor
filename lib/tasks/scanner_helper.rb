require_relative './../../demo/code/demo_constants'

def lucky?
  [true,false].sample
end

def randomly_pick_atleast_one(array)
  array.sample(rand(1..array.size))
end

def pick_number_between(min, max)
  rand(min..max)
end

class Program < AbstractProgram
  def program_admin
    self.users.includes(:member).where("members.email = ?", ScannerConstants::ADMIN_EMAIL).first
  end

  def program_mentor
    self.users.includes(:member).where("members.email = ?", "test_mentor@chronus.com").first
  end

  def program_mentee
    self.users.includes(:member).where("members.email = ?", "test_mentee@chronus.com").first
  end

  def program_mentor_mentee
    self.users.includes(:member).where("members.email = ?", "test_mentor_mentee@chronus.com").first
  end
end

def organization_admin(organization)
  organization.members.admins.first
end

class Member < ActiveRecord::Base
  def is_org_mentor?
    self.email == "test_mentor@chronus.com"
  end

  def is_org_mentee?
    self.email == "test_mentee@chronus.com"
  end

  def is_org_mentor_mentee?
    self.email == "test_mentor_mentee@chronus.com"
  end
end

##############################################################

def populate_messages(organization, count=10)
  say_populating "Messages" do
    members = organization.members
    count.times do
      message = Message.new
      sender = members.sample
      receivers = [(organization.members - [sender]).sample]
      next unless sender.allowed_to_send_message?(receivers.first)
      message.sender = sender
      message.program_id = organization.id
      message.subject = Populator.words(2..4)
      message.content = Populator.sentences(2..4)
      message.receivers = receivers
      message.save!
      message.message_receivers.each do |message_receiver|
        message_receiver.status = [AbstractMessageReceiver::Status::DELETED, AbstractMessageReceiver::Status::READ, AbstractMessageReceiver::Status::UNREAD].sample
      end
      dot
    end
  end
end

def populate_admin_messages(program, count=10)
  say_populating "Admin Messages" do
    all_admins = program.admin_users.collect(&:member)
    admin = all_admins.first
    sent_by_admin = lucky?
    count.times do
      message = AdminMessage.new()
      if sent_by_admin
        message.sender_id = admin.id
        message.receivers = [(program.users.collect(&:member) - all_admins).sample]
      else
        message.sender_id = (program.users.collect(&:member).collect(&:id) - all_admins.collect(&:id)).sample
        message.receivers = all_admins
      end
      message.program_id = program.id
      message.subject = Populator.words(2..4)
      message.content = Populator.sentences(2..4)
      message.message_receivers.each do |message_receiver|
        message_receiver.status = [AbstractMessageReceiver::Status::DELETED, AbstractMessageReceiver::Status::READ, AbstractMessageReceiver::Status::UNREAD].sample
      end
      message.save!
      dot
    end
  end
end

def populate_invitations(program, count=10)
  say_populating "Progrm Invitations" do
    admin = program.admin_users.first
    count.times do
      inv = ProgramInvitation.new()
      inv.user_id = admin.id

      # Have a few expired invites created too.
      inv.created_at = rand(50).days.ago
      inv.sent_to = Faker::Internet.email
      inv.code = ProgramInvitation.generate_unique_code
      inv.program_id = program.id
      inv.expires_on = inv.created_at + 30.days
      inv.message = "I would like to invite you to join our mentoring program. Please click on the link below."
      inv.use_count = 0
      inv.role_names = [[RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].sample]
      inv.save!
      dot
    end
  end
end

def populate_program_qa(program, count=10)
  say_populating "Program QA" do
    count.times do
      question = QaQuestion.new()
      question.program_id = program.id
      question.user_id = program.users.collect(&:id).sample
      question.summary = Populator.words(5..10)
      question.description = Populator.sentences(2..5)
      question.save!
        
      answer = question.qa_answers.new()
      answer.user_id = program.users.collect(&:id).sample
      answer.score = 0
      answer.content = Populator.sentences(5..10)
      answer.save!
      dot
    end
  end
end

def populate_bulk_match(program)
  say_populating "Bulk Match" do
    program.create_default_admin_views if program.admin_views.empty?
    mentor_views = Program.first.admin_views.select{|view| view.get_included_roles_string == RoleConstants::MENTOR_NAME}
    mentee_views = Program.first.admin_views.select{|view| view.get_included_roles_string == RoleConstants::STUDENT_NAME}
    bulk_match = BulkMatch.new()
    bulk_match.mentor_view = mentor_views.sample
    bulk_match.mentee_view = mentee_views.sample
    bulk_match.program_id = program.id
    bulk_match.save!
    dot
  end
end

def populate_coaching_goals(program, count=8)
  say_populating "Coaching Goals" do
    groups = program.groups
    count.times do
      group = groups.sample
      coaching_goal = CoachingGoal.new()
      coaching_goal.group = group
      coaching_goal.title = Populator.words(2..4)
      coaching_goal.description = Populator.sentences(1..3)
      coaching_goal.creator = group.members.sample
      coaching_goal.save!
      dot
    end
  end
end

def populate_coaching_goal_activities(program, count = 8)
  say_populating "Coaching Goal Activities" do
    coaching_goal_ids = program.groups.collect(&:coaching_goals).flatten.collect(&:id)
    count.times do
      coaching_goal_activity = CoachingGoalActivity.new()
      coaching_goal_activity.coaching_goal_id = coaching_goal_ids.sample
      coaching_goal_activity.message = Populator.words(2..4)
      coaching_goal_activity.progress_value = [*1..100].sample
      coaching_goal_activity.initiator = coaching_goal_activity.coaching_goal.group.members.sample
      coaching_goal_activity.save!
      dot
    end
  end
end

def populate_common_questions(program, count=4)
  say_populating "Common Questions" do
    survey_ids = program.surveys.collect(&:id)
    survey_ids.each do |survey_id|
      count.times do
        survey_question = SurveyQuestion.new()
        survey_question.question_type = CommonQuestion::Type.all.sample
        survey_question.question_text = Populator.words(2..5)
        survey_question.program_id = program.id
        survey_question.survey_id = survey_id
        (survey_question.question_info = Populator.words(3..10).gsub(" ", ProfileQuestion::SEPERATOR)) if survey_question.choice_based?
        survey_question.save!
        dot
      end
    end
    count.times do   
      connection_question = Connection::Question.new()
      connection_question.question_type = CommonQuestion::Type.all.sample
      connection_question.question_text = Populator.words(2..5)
      connection_question.program_id = program.id
      (connection_question.question_info = Populator.words(3..10).gsub(" ", ProfileQuestion::SEPERATOR)) if connection_question.choice_based?
      connection_question.save!
      dot
    end
  end
end

def populate_common_answers(program, count = 4)
  say_populating "Common Answers" do
    program.reload
    survey_questions = program.surveys.collect(&:survey_questions)
    connection_questions = program.connection_questions
    user_ids = program.users.collect(&:id)
    group_ids = program.groups.collect(&:id)
    survey_questions.flatten.each do |survey_question|
      question_info = survey_question.question_info
      count.times do
        survey_answer = SurveyAnswer.new()
        survey_answer.common_question_id = survey_question.id
        survey_answer.user_id = user_ids.sample
        if survey_question.file_type?
          survey_answer.attachment = Rack::Test::UploadedFile.new(scanner_file("qa_answers", "mentor_1.txt"), 'text/text')
        else
          survey_answer.answer_text = survey_question.choice_based? ? get_quesion_choices(question_info) : Populator.words(2..4)
        end
        survey_answer.save!
        dot
      end
    end

    group_ids.each do |group_id|
      connection_questions.each do |connection_question|
        question_info = connection_question.question_info
        connection_answer = Connection::Answer.new()
        connection_answer.common_question_id = connection_question.id
        connection_answer.group_id = group_id
        if connection_question.file_type?
          connection_answer.attachment = Rack::Test::UploadedFile.new(scanner_file("qa_answers", "mentor_1.txt"), 'text/text')
        else
          connection_answer.answer_text = connection_question.choice_based? ? get_quesion_choices(question_info) : Populator.words(2..4)
        end
        connection_answer.save!
        dot
      end
    end
  end
end

def populate_confidentiality_audit_log(program, count = 5)
  say_populating "Confidentiality Audit Logs" do
    admin_user_ids = program.admin_users.collect(&:id)
    program_id = program.id
    group_ids = program.groups.collect(&:id)
    count.times do
      log = ConfidentialityAuditLog.new()
      log.program_id = program_id
      log.group_id = group_ids.sample
      log.user_id = admin_user_ids.sample
      log.reason = Populator.sentences(1..3)
      log.created_at = rand(30..90).day.ago
      log.save!
      dot
    end
  end
end

def populate_connection_private_notes(program, count = 6)
  say_populating "Connection Private Notes" do
    connection_membership_ids = program.groups.collect(&:memberships).flatten.collect(&:id)
    count.times do  
      note = Connection::PrivateNote.new()
      note.text = Populator.sentences(2..5)
      note.connection_membership_id = connection_membership_ids.sample
      note.save!
      dot
    end
  end
end

def populate_contact_admin_setting(program)
  say_populating "Contact Admin Settings" do
    setting = ContactAdminSetting.new()
    setting.label_name = Populator.words(2..5)
    setting.content = Populator.sentences(1..3)
    setting.contact_url = "http://www.chronus.com"
    setting.program_id = program.id
    setting.save!
    dot
  end
end

# def populate_data_imports(organization)
#   DataImport.populate 3..8 do |data_import|
#     data_import.organization_id = organization.id
#     data_import.status = [DataImport::Status::SUCCESS, DataImport::Status::SKIPPED, DataImport::Status::FAIL]
#     (data_import.failure_message = Populator.words(5..10)) unless data_import.success?
#   end
# end

def populate_flags(program)
  say_populating "Flags" do
    flag = Flag.new()
    flag.content_type = "Comment"
    flag.content_id = program.article_publications.collect(&:comments).flatten.collect(&:id).sample
    flag.reason = Populator.words(5..10)
    flag.user_id = program.users.collect(&:id).sample
    flag.program_id = program.id
    flag.status = Flag::Status::UNRESOLVED
    flag.save!
    dot

    flag = Flag.new()
    flag.content_type = "Article"
    flag.content_id = program.articles.collect(&:id).sample
    flag.reason = Populator.words(5..10)
    flag.user_id = program.users.collect(&:id).sample
    flag.program_id = program.id
    flag.status = Flag::Status::UNRESOLVED
    flag.save!
    dot

    flag = Flag.new()
    flag.content_type = "Post"
    flag.content_id = program.forums.collect(&:topics).flatten.collect(&:posts).flatten.collect(&:id).sample
    flag.reason = Populator.words(5..10)
    flag.user_id = program.users.collect(&:id).sample
    flag.program_id = program.id
    flag.status = Flag::Status::UNRESOLVED
    flag.save!
    dot

    flag = Flag.new()
    flag.content_type = "QaQuestion"
    flag.content_id = program.qa_questions.collect(&:id).sample
    flag.reason = Populator.words(5..10)
    flag.user_id = program.users.collect(&:id).sample
    flag.program_id = program.id
    flag.resolver_id = program.admin_users.collect(&:id).sample
    flag.created_at = rand(2..90).days.ago
    flag.resolved_at = flag.created_at + 1.day
    flag.status = Flag::Status::ALLOWED
    flag.save!
    dot

    flag = Flag.new()
    flag.content_type = "QaAnswer"
    flag.content_id = program.qa_answers.collect(&:id)
    flag.reason = Populator.words(5..10)
    flag.user_id = program.users.collect(&:id).sample
    flag.program_id = program.id
    flag.status = Flag::Status::UNRESOLVED
    flag.save!
    dot
  end
end

def populate_organization_languages(organization)
  say_populating "Organization Languages" do
    Language.all.each do |lang|
      lang.enabled = true
      lang.save!
      org_lang = OrganizationLanguage.new()
      org_lang.language_id = lang.id
      org_lang.organization = organization
      org_lang.enabled = true
      org_lang.default = false
      org_lang.save!
      dot
    end
  end
end

def populate_member_languages(organization)
  say_populating "Member Languages" do
    member = Member.find_by(email: "test_mentor@chronus.com")
    member_language = MemberLanguage.new()
    member_language.member_id = member.id
    member_language.language_id = Language.last.id
    member_language.save!
    dot
  end
end

def populate_sections(organization, count = 3)
  say_populating "Sections" do
    count.times do |i|
      Section.create!(:program_id => organization.id, :title => "Section #{i}")
      dot
    end
  end
end

def populate_profile_questions(organization)
  say_populating "Profile Questions" do
    sections = organization.sections
    section_size = sections.size - 1
    ProfileQuestion::Type.all.each do |type|
      next if type == ProfileQuestion::Type::LOCATION
      pq = organization.profile_questions.new
      pq.question_text = Populator.words(3..10)
      pq.question_type = type
      pq.section = sections[[*0..section_size].sample]
      pq.question_info = Populator.words(3..10).gsub(" ", ProfileQuestion::SEPERATOR) if pq.choice_based? || pq.ordered_options_type?
      pq.save!
      dot
    end
  end
end

def populate_role_questions(program)
  say_populating "Role Questions" do
    user_roles = program.roles.where(administrative: false)
    pqs = program.organization.profile_questions
    privacy_options = (RoleQuestion::PRIVACY_SETTING.all + [RoleQuestion::PRIVACY_SETTING::RESTRICTED] * 2)
    restricted_privacy_setting_options = RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(program).collect {|setting| setting[:privacy_setting]}
    available_for_options = [RoleQuestion::AVAILABLE_FOR::BOTH,
                            RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS,
                            RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS]
    pqs.each do |pq|
      next if pq.role_questions.any?
      user_roles.each do |role|
        role_question = role.role_questions.new(:profile_question => pq, :private => privacy_options.sample, :available_for => available_for_options.sample)
        role_question.privacy_settings.build(restricted_privacy_setting_options.sample) if role_question.restricted?
        role_question.save!
        dot
      end
    end
  end
end

def populate_members(organization, count=10)
  say_populating "Members" do
    count.times do
      member = organization.members.new
      member.first_name = Faker::Name.first_name
      member.last_name = Faker::Name.last_name
      member.email = Faker::Internet.email
      member.save!
      dot
    end
  end
end

def populate_users(program)
  say_populating "Users" do
    role_names = program.roles.collect(&:name)
    members = program.organization.members
    members.each do |m|
      if m.admin?
        user = m.user_in_program(program)
        user.role_names += [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
        user.save!
        dot
      elsif m.is_org_mentor?
        user = m.users.new
        user.program = program
        user.role_names = RoleConstants::MENTOR_NAME
        user.save!
        dot
      elsif m.is_org_mentee?
        user = m.users.new
        user.program = program
        user.role_names = RoleConstants::STUDENT_NAME
        user.save!
        dot
      elsif m.is_org_mentor_mentee?
        user = m.users.new
        user.program = program
        user.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
        user.save!        
        dot
      else
        next if lucky?
        user = m.users.new
        user.program = program
        user.role_names = randomly_pick_atleast_one role_names
        user.save!
        dot
      end
    end
  end
end


def populate_membership_requests(program, count=10)
  say_populating "Membership Requests" do
    count.times do
      role = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].sample

      attrs = {
        :first_name => Faker::Name.first_name,
        :last_name => Faker::Name.last_name,
        :email => Faker::Internet.email,
        :role_names => [role],
        :program => program
      }
      req = MembershipRequest.create_from_params(
        attrs.delete(:program), attrs, {})
      req.save!

      req.status = [MembershipRequest::Status::UNREAD, MembershipRequest::Status::ACCEPTED, MembershipRequest::Status::REJECTED].sample
      req.admin = program.admin_users.first unless req.pending?
      req.response_text = Populator.words(5..10) if req.rejected?
      req.accepted_as = req.role_names.sample if req.accepted?
      req.save!
      dot
    end
  end
end

def populate_mentor_requests(program, count = 10)
  return if program.matching_by_admin_alone?
  say_populating "Mentor Requests" do
    count.times do
      student = program.student_users.sample
      mentor = (program.mentor_users - [student]).sample
      next unless MentorRequest.where(:sender_id => student.id, :receiver_id => mentor.id).empty?
      next unless student.can_send_mentor_request?
      next if program.matching_by_mentee_and_admin_with_preference? && student.sent_mentor_requests.any?
      mreq = MentorRequest.new
      mreq.program = program
      mreq.student = student
      mreq.mentor = mentor unless program.matching_by_mentee_and_admin_with_preference?
      mreq.status = [AbstractRequest::Status::NOT_ANSWERED, AbstractRequest::Status::NOT_ANSWERED, AbstractRequest::Status::REJECTED].sample
      mreq.message = Populator.words(10..14)
      mreq.response_text = Populator.words(10..14) if mreq.status == AbstractRequest::Status::REJECTED
      mreq.save!
      if program.matching_by_mentee_and_admin_with_preference?
        mentor_favs = program.mentor_users.sample(rand(1..4))
        # Create favorites
        mentor_favs.each do |mentor_fav|
          student.user_favorites.create!(:favorite => mentor_fav,
            :note => Populator.sentences(2..5), :mentor_request_id => mreq.id)
        end
        # Update mentor request with favorites
        mreq.build_favorites(
          student.user_favorites.collect{|f| f.favorite.id}
        )
      end
      dot
    end
  end
end

def populate_forums(program, count=4)
  say_populating "Forums" do
    count.times do
      forum = program.forums.new(:name => Populator.words(2..5),  :description => Populator.sentences(3..5))
      forum.access_role_names = [[RoleConstants::MENTOR_NAME], [RoleConstants::STUDENT_NAME], [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]].sample
      forum.save!
      dot
      create_topics(forum)
    end
  end
end

def create_topics(forum)
  say_populating "Topics" do
    user = forum.program.program_admin
    forum.subscribe_user(user)
    topic = forum.topics.new(:title => Populator.words(2..5), :user => user, :posts_attributes => {"0" =>{:body => Populator.words(2..5), :published => [true, false].sample}})
    topic.posts.each do |post|
      post.topic = topic
      post.user  = topic.user
    end
    topic.subscribe_user(topic.user)
    topic.save!
    dot
  end
end

def populate_program_events(program)
  say_populating "Program Events" do
    program.program_events.create!(:title => 'New Event', :status => ProgramEvent::Status::PUBLISHED , :start_time => 20.days.from_now.to_date, :user => program.program_admin)
    dot
    program.program_events.create!(:title => 'Old Event', :status => ProgramEvent::Status::PUBLISHED , :start_time => 2.days.ago.to_date, :user => program.program_admin)
    dot
    program.program_events.create!(:title => 'Draft Event', :status => ProgramEvent::Status::DRAFT , :start_time => 20.days.from_now.to_date, :user => program.program_admin)
    dot
  end
end

def populate_connections(program)
  say_populating "Connections" do
    mentor = program.program_mentor
    mentee = program.program_mentee
    mentor_mentee = program.program_mentor_mentee
    admin_mentor_mentee = program.program_admin
    program.groups.create!(:mentors => [mentor], :students => [mentee], :status => Group::Status::ACTIVE, :expiry_time => 4.months.from_now, :created_by => admin_mentor_mentee)
    dot
    program.groups.create!(:mentors => [admin_mentor_mentee], :students => [mentee], :status => Group::Status::DRAFTED, :expiry_time => 4.months.from_now, :created_by => admin_mentor_mentee)
    dot
    program.groups.create!(:mentors => [mentor], :students => [admin_mentor_mentee], :status => Group::Status::ACTIVE, :expiry_time => 4.months.from_now, :global => true, :created_by => admin_mentor_mentee)
    dot
    program.groups.create!(:mentors => [mentor], :students => [mentor_mentee], :status => Group::Status::CLOSED, :created_by => admin_mentor_mentee, :closed_by => admin_mentor_mentee, :closed_at => 1.hour.ago)
    dot
    program.groups.create!(:mentors => [mentor_mentee], :students => [mentee], :status => Group::Status::DRAFTED, :created_by => admin_mentor_mentee)
    dot
  end
end

def populate_user_settings(program, count=5)
  say_populating "User Settings" do
    user_ids = program.users.collect(&:id)
    count.times do
      setting = UserSetting.new()
      setting.user_id = user_ids.sample
      setting.max_meeting_slots = [*5..10].sample
      setting.save!
      dot
    end
  end
end

def populate_profile_answers(program, count=5)
  say_populating "Profile Answers" do
    program.reload
    ref_objs = []
    count.times do
      ref_objs << [program.users.sample, program.membership_requests.sample].sample
    end
    ref_objs.uniq.each do |ref_obj|
      ref_obj_type = (ref_obj.class.name == "MembershipRequest") ? "MembershipRequest" : "Member"
      role_names = ref_obj.role_names
      profile_questions = (ref_obj_type == "MembershipRequest") ? program.membership_questions_for(role_names).uniq : program.role_questions_for(role_names, user: ref_obj).role_profile_questions.collect(&:profile_question).uniq
      ref_obj = (ref_obj_type == "MembershipRequest") ? ref_obj : ref_obj.member
      next if ref_obj.profile_answers.any?
      ref_obj_id = ref_obj.id
      profile_questions.each do |profile_question|
        question_info = profile_question.question_info
        profile_answer = ProfileAnswer.new()
        if profile_question.file_type?
          profile_answer.attachment = Rack::Test::UploadedFile.new(scanner_file("qa_answers", "mentor_1.txt"), 'text/text')
        elsif profile_question.location?
          profile_answer.location = Location.all.sample
        else
          profile_answer.answer_text = profile_question.choice_based? ? get_quesion_choices(question_info) : Populator.words(2..4)
        end
        profile_answer.profile_question_id = profile_question.id
        profile_answer.ref_obj_type = ref_obj_type
        profile_answer.ref_obj_id = ref_obj_id
        profile_answer.save!
        dot
      end
    end
  end
end

def populate_meetings(program, count = 5)
  say_populating "Meetings" do
    #group meetings
    count.times do
      meeting = Meeting.new()
      meeting.program = program
      group = program.groups.sample
      mentor = group.mentors.sample
      student = group.students.sample
      meeting.group_id = group.id
      meeting.members = group.members.collect(&:member)
      meeting.location = (Demo::Groups::Meetings::Locations).sample
      start_time = rand(-10..10).days.ago
      meeting.start_time = start_time
      meeting.end_time = start_time + rand(1..5).hours
      meeting.owner = meeting.members.sample
      meeting.topic = Populator.words(2..5)
      meeting.description = Populator.sentences(2..5)
      meeting.requesting_mentor = mentor
      meeting.requesting_student = student
      meeting.save!
      dot
    end
    #From Availability Slots
    count.times do
      meeting = Meeting.new()
      meeting.program = program
      mentor = program.mentor_users.sample
      student = program.student_users.sample
      slot = mentor.member.mentoring_slots.sample
      meeting.members = [student.member, mentor.member]
      meeting.location = slot.location
      start_time = slot.start_time
      meeting.start_time = start_time
      meeting.end_time = start_time + rand(1..3).hours
      meeting.owner = meeting.members.sample
      meeting.topic = Populator.words(2..5)
      meeting.description = Populator.sentences(2..5)
      meeting.requesting_mentor = mentor
      meeting.requesting_student = student
      meeting.save!
      dot
    end
    #Without Availability Slots
    count.times do
      meeting = Meeting.new()
      meeting.program = program
      mentor = program.mentor_users.sample
      student = program.student_users.sample
      meeting.members = [student.member, mentor.member]
      meeting.owner = meeting.members.sample
      meeting.description = Populator.sentences(2..5)
      meeting.calendar_time_available = false
      meeting.requesting_mentor = mentor
      meeting.requesting_student = student
      start_time = rand(-10..10).days.ago
      meeting.start_time = start_time
      meeting.end_time = start_time + rand(1..5).hours
      meeting.save!
      dot
    end
  end
end

def populate_scraps(program)
  say_populating " Group Scraps" do
    program.groups.each do |group|
      create_group_scraps(group)
    end
  end
end

def create_group_scraps(group, count=5)
  count.times do
    scrap = Scrap.new()
    scrap.group_id = group.id
    u = (group.mentors + group.students).sample
    scrap.message = Populator.sentences(2..5)
    scrap.connection_membership_id = group.membership_of(u)
    scrap.save!
    dot
  end
end

def populate_availability_slots(program)
  say_populating "Availability Slots" do
    mentors = program.mentor_users
    mentors.each do |mentor|
      location = (Demo::Groups::Meetings::Locations).sample
      date = rand(1..5).days.from_now
      date_str = date.strftime("%B %d, %Y")
      offset = rand(1..5)
      start_time_of_day = (date.beginning_of_day() + offset.hours).strftime("%I:00 %p")
      end_time_of_day = (date.beginning_of_day() + rand(6..9).hours).strftime("%I:00 %p")
      start_time, end_time = MentoringSlot.fetch_start_and_end_time(date_str,start_time_of_day,end_time_of_day)
      repeats = [MentoringSlot::Repeats::NONE, MentoringSlot::Repeats::DAILY, MentoringSlot::Repeats::WEEKLY,
        MentoringSlot::Repeats::MONTHLY].sample
      week = (repeats == MentoringSlot::Repeats::WEEKLY) ? start_time.wday.to_s : nil
      slot = MentoringSlot.create!(:member => mentor.member, 
        :start_time => start_time, :end_time => end_time , :location => location, 
        :repeats => repeats, :repeats_on_week => week, :repeats_by_month_date => true)
      dot
    end
  end
end

def populate_announcements(program, count = 6)
  say_populating "Announcements" do
    count.times do
      announcement= Announcement.new
      announcement.title = Populator.words(3..5)
      announcement.body = Populator.sentences(3..5)
      announcement.program_id = program.id
      announcement.user_id = program.admin_users.first.id
      announcement.created_at = rand(5..15).days.ago
      announcement.recipient_role_names = [[RoleConstants::MENTOR_NAME], [RoleConstants::STUDENT_NAME], [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]].sample
      announcement.attachment = Rack::Test::UploadedFile.new(scanner_file("announcements", "all.txt"), 'text/text') if lucky?
      announcement.save!
      dot
    end
  end
end

########################################################

def create_org_admin(organization)
  member = organization.members.create!(:first_name => "test", :last_name => "admin", :email => ScannerConstants::ADMIN_EMAIL, :password => 'test123', :password_confirmation => 'test123', :auth_config => organization.auth_configs.first)
  member.admin = true
  member.save
end

def create_org_mentor_and_mentee(organization)
  organization.members.create!(:first_name => "test", :last_name => "mentor", :email => "test_mentor@chronus.com", :password => 'test123', :password_confirmation => 'test123', :auth_config => organization.auth_configs.first)
  organization.members.create!(:first_name => "test", :last_name => "mentee", :email => "test_mentee@chronus.com", :password => 'test123', :password_confirmation => 'test123', :auth_config => organization.auth_configs.first)
  organization.members.create!(:first_name => "test", :last_name => "mentor mentee", :email => "test_mentor_mentee@chronus.com", :password => 'test123', :password_confirmation => 'test123', :auth_config => organization.auth_configs.first)
end


##########################Q & A###########################################


##########################################################################

############################Articles######################################
def populate_articles(organization)
  say_populating "Articles" do
    a1 = organization.articles.new
    a1.author = organization_admin(organization)
    a1.published_programs = randomly_pick_atleast_one organization.programs
    a1.article_content = a1.build_article_content(:title => "Title 1", :body => "<div>Hi</div>", :type => "text", :status => ArticleContent::Status::PUBLISHED, :published_at => 2.days.ago)
    a1.save!
    dot

    a2 = organization.articles.new
    a2.author = organization_admin(organization)
    a2.published_programs = randomly_pick_atleast_one organization.programs
    a2.article_content = a2.build_article_content(:title => "Title 2", :body => "<div>Bye</div>", :type => "text", :status => ArticleContent::Status::DRAFT, :published_at => 2.days.ago)
    a2.save!
    dot

    a3 = organization.articles.new
    a3.author = organization_admin(organization)
    a3.published_programs = randomly_pick_atleast_one organization.programs
    a3.article_content = a3.build_article_content(:title => "Title 4", :body => "<div>Hi</div>", :embed_code => "<iframe width='560' height='315' src='http://www.youtube.com/embed/jdScCGn-ycI' frameborder='0' allowfullscreen></iframe>", :type => "media", :status => ArticleContent::Status::PUBLISHED, :published_at => 2.days.ago)
    a3.save!
    dot

    a4 = organization.articles.new
    a4.author = organization_admin(organization)
    a4.published_programs = randomly_pick_atleast_one organization.programs
    a4_ac = a4.build_article_content(:title => "Title 5", :type => "list", :status => ArticleContent::Status::PUBLISHED, :published_at => 2.days.ago)
    a4.article_content = a4_ac
    a4_ac_l1 = a4_ac.list_items.new(:content => 'A Navajo Bringing-Home Ceremony: The Claus Chee Sonny Version of Deerway
    Ajilee (American Tribal Religions)')
    a4_ac_l1.type = 'BookListItem'
    a4_ac_l2 = a4_ac.list_items.new(:content => ' http://www.google.com')
    a4_ac_l2.type = 'SiteListItem'
    a4.save!
    dot
  end

  organization.programs.each do |program|
    populate_article_comments(program)
  end
end

def populate_article_comments(program)
  say_populating "Article Comments" do
    return if program.article_publications.empty?
    comment = program.article_publications.first.comments.new(:body => 'text')
    comment.user = program.program_mentor
    comment.save!
    dot
  end
end

def say_populating(model_name)
  print_and_flush "*** Populating #{model_name} "
  yield
  newline
end

private

def get_quesion_choices(question_info)
  question_info.split(ProfileQuestion::SEPERATOR).sample
end

def dot
  print_and_flush(".")
end

def newline
  print_and_flush("\n")
end

def print_and_flush(msg)
  print msg
  $stdout.flush
end

def scanner_file(*path)
  file_name = path.pop
  dirs = path.join("/") + "/" unless path.empty?;
  Rails.root.to_s + "/demo/#{dirs}#{file_name}"
end