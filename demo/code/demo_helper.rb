require_relative './demo_constants'
require_relative './demo_campaign_populator'

class User < ActiveRecord::Base
  # Determine if user is female. If gender is not determinable, user male
  def female?
    question_filter = self.is_student? ? RoleConstants::STUDENT_NAME : RoleConstants::MENTOR_NAME
    gender_question = program.profile_questions_for(question_filter, {pq_translation_include: false}).select{|q| q.question_text =="Gender"}[0] ||
      program.profile_questions_for(question_filter, {pq_translation_include: false}).select{|q| q.question_text =="Sex"}[0]
    if ((ans = self.answer_for(gender_question)) && !ans.answer_text.blank?)
      ans_text = ans.answer_text.downcase
      is_female = ans_text.starts_with?("f") || ans_text.starts_with?("w")
    end

    is_female
  end
end

module ActiveRecord
  class Base
    # Skip automatic AR timestamping - http://bit.ly/bzQJu
    def self.skip_timestamping
      raise "No block given" unless block_given?
      old_setting = self.record_timestamps
      self.record_timestamps = false
      yield
      self.record_timestamps = old_setting
    end
  end
end

class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
  end
end

# We pass subscription_type to create specific data for specific subscription types.
#For now we create meetings only for Enterprise edition

def create_group(g_mentor, subscription_type, g_students = [], options = {})
  # Don't create a group if a group is already present between the mentor and
  # student
  g_students.each do |g_student|
    if Group.involving(g_mentor, g_student).any?
      warn "Attempt to create duplicate group. Returning..."
      return
    end
  end

  program = g_mentor.program

  group = Group.new(
    program: program,
    created_at: rand(7).days.ago,
    mentors: [g_mentor],
    students: g_students
  )

  # global is protected. can't set it in mass assignment above.
  group.global = options[:project_based]
  group.save!

  assert_valid group.reload

  #Create scraps
  create_group_scraps(group)

  #Create meetings for Enterprise Edition programs
  if(subscription_type==Organization::SubscriptionType::ENTERPRISE.to_s)
    create_group_meetings(group)
  end
end

def create_group_scraps(group)
  receiver_status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ]
  Scrap.populate 4..10 do |scrap|
    scrap.group_id = group.id
    scrap.program_id = group.program_id
    sender_user = (group.mentors + group.students).sample
    scrap.content = sender_user.is_mentor? ? Demo::Groups::Scraps::Mentors : Demo::Groups::Scraps::Students
    scrap.subject = scrap.content.truncate 80
    scrap.sender_id = sender_user.member_id
    scrap.type =  Scrap.name
    scrap.auto_email = false
    scrap.root_id = scrap.id
    scrap.posted_via_email = false
    receiver_members_ids = (group.members - [sender_user]).collect(&:member_id)
    Scraps::Receiver.populate receiver_members_ids.count do |scrap_receiver|
      scrap_receiver.member_id = receiver_members_ids.shift
      scrap_receiver.message_id = scrap.id
      scrap_receiver.status = receiver_status.sample
      scrap_receiver.api_token = secure_digest(Time.now, (1..10).map{ rand.to_s })
      scrap_receiver.message_root_id = scrap.id
    end
  end
  assert_valid group.reload.scraps
end

def create_group_meetings(groups, options = {})
  Array(groups).each do |group|
    options.reverse_merge!(past_meetings: false)
    group_member_ids = group.members.collect(&:member_id)
    #Create past meetings
    3.times do
      date = rand(15).days.ago.strftime("%B %d, %Y")
      populate_meeting(group, group_member_ids, date)
    end

    #Create upcoming meetings
    3.times do
      date = rand(15).days.from_now.strftime("%B %d, %Y")
      populate_meeting(group, group_member_ids, date)
    end
  end
end

def populate_meeting(group, group_member_ids, date)
  owner_id = group_member_ids.sample
  iterator = rand(5)
  start_time_of_day = iterator.hours.from_now.strftime("%I:00 %p")
  end_time_of_day = (iterator + 1).hours.from_now.strftime("%I:00 %p")
  owner = (group.mentors + group.students).sample
  start_time, end_time = MentoringSlot.fetch_start_and_end_time(date,start_time_of_day,end_time_of_day)
  topic = Demo::Groups::Meetings::Topics.sample
  desc = Demo::Groups::Meetings::Descriptions.sample
  loc = Demo::Groups::Meetings::Locations.sample
  meeting = Meeting.create!(
    program_id: group.program.id, group_id: group.id, topic: topic, start_time: start_time, end_time: end_time,
    description: desc, location: loc, attendee_ids: group_member_ids, owner_id: owner_id)
end

def create_program_admin(program)
  admin = nil
  member = nil
  DataPopulator.benchmark_wrapper "Program Admin Creation" do
    subdomain = program.organization.subdomain
    member = create_member(first_name: "Chronus", last_name: "Admin", email: "#{subdomain}_admin@chronus.com", organization: program.organization, calendar_sync_count: 0)
    admin = create_user(member: member, role_names: [RoleConstants::ADMIN_NAME], program: program)
    admin.member.update_attribute :admin, true
    upload_user_profile_pic(admin, ["Male", "Female"].sample)
  end
  {user: admin, member: member}
end

def create_member(opts)
  Member.populate 1 do |member|
    member.first_name = opts[:first_name] || "Chronus"
    member.last_name = opts[:last_name] || "User"
    member.email = unique_email_address(opts[:email] || "#{member.first_name}@example.com", opts[:organization])
    member.salt = "da4b9237bacccdf19c0760cab7aec4a8359010b0"
    member.crypted_password = "688174433af60e1b89ecd9ed33022104bb6633e3"  # chronus
    member.organization_id = opts[:organization].id
    member.state = opts[:state] || Member::Status::ACTIVE
    member.calendar_api_key = secure_digest(Time.now, (1..10).map{ rand.to_s })
    member.time_zone = "America/Los_Angeles"
    member.failed_login_attempts = 0
    member.calendar_sync_count = 0

    LoginIdentifier.populate 1 do |login_identifier|
      login_identifier.auth_config_id = opts[:organization].chronus_auth.id
      login_identifier.member_id = member.id
    end
  end
  member = Member.last
  assert_valid member
  member
end

def create_user(opts)
  role_names = opts[:role_names] || [RoleConstants::MENTOR_NAME]

  User.populate 1 do |user|
    user.state = :active
    user.member_id = opts[:member].id
    user.program_id = opts[:program].id
    user.mentoring_mode = User::MentoringMode::ONE_TIME_AND_ONGOING
    user.last_program_update_sent_time = Time.now
    user.last_group_update_sent_time = Time.now
    if role_names == [RoleConstants::MENTOR_NAME]
      user.max_connections_limit = rand(9) + 2
    else
      user.max_connections_limit = 0
    end
    user.created_at = ((role_names == [RoleConstants::ADMIN_NAME]) ? 3.weeks.ago : rand(7).days.ago)
  end
  user = User.last
  user.role_names = role_names
  user.primary_home_tab = Program::RA_TABS::ALL_ACTIVITY
  user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::WEEKLY
  user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
  user.save!
  assert_valid user
  return user
end

def create_question(options = {})
  program = options.delete(:program)
  options.reverse_merge!(organization: program.organization)
  question_choices = options.delete(:question_choices) || []
  filterable = options.delete(:filterable)
  private = options.delete(:private) || RoleQuestion::PRIVACY_SETTING::ALL
  privacy_settings = options.delete(:privacy_settings) || []
  available_for = options.delete(:available_for) || RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS
  role_names = options.delete(:role_names)
  role = program.roles.with_name(role_names)[0]
  rq_options = { required: options.delete(:required) || false, filterable: filterable.nil? ? true : filterable, private: private, available_for: available_for}

  question = ProfileQuestion.new(options)
  question.section = options[:organization].sections.default_section.first
  question.save!
  question_choices.each_with_index do |text, index|
    question.question_choices.create!(text: text, position: index + 1)
  end
  pq = ProfileQuestion.last
  rq_options[:profile_question] = question

  role_ques = RoleQuestion.new(rq_options)
  role_ques.role = role
  privacy_settings.each do |setting_params|
    role_ques.privacy_settings.build(setting_params)
  end
  role_ques.save!

  assert_valid pq
  assert_valid RoleQuestion.last

  return pq
end

def create_membership_request(program, program_type, role_names)
  is_mentor = (role_names == [RoleConstants::MENTOR_NAME])
  MembershipRequest.populate 1 do |mem|
    member = create_member(
      first_name: get_user_first_name(['Male', 'Female'].sample),
      last_name: Faker::Name.last_name,
      state: Member::Status::DORMANT,
      organization: program.organization
    )

    mem.first_name = member.first_name
    mem.last_name = member.last_name
    mem.email = member.email
    mem.member_id = member.id
    mem.program_id = program.id
    mem.status = MembershipRequest::Status::UNREAD
    mem.joined_directly = false

    if (program_type == Demo::ProgramType::STUDENT.to_s)
      program.membership_questions_for(role_names).each do |q|
        ProfileAnswer.populate 1 do |mem_ans|
          mem_ans.profile_question_id = q.id
          mem_ans.ref_obj_id = member.id
          mem_ans.ref_obj_type = Member.name
          # Answer for known questions
          if q.question_text == 'Degree'
            mem_ans.answer_text = (is_mentor ? Demo::Educations::MentorDegrees : Demo::Educations::MenteeDegrees)
          elsif q.question_text == "Major"
            mem_ans.answer_text = Demo::Educations::Majors
          elsif q.question_text == 'Graduation year'
            year = Date.today.year
            mem_ans.answer_text = (is_mentor ? ((year - 20)..(year - 5)) : (year..(year + 5)))
          elsif q.question_text == 'Student Id / Roll number'
            mem_ans.answer_text = "#{['abc', 'msc', 'edf', 'vt'].sample}-2009-#{rand(100)}"
          elsif q.question_text == 'Reason to join'
            mem_ans.answer_text = (is_mentor ? Demo::Reasons::Education::MentorReasons : Demo::Reasons::Education::MenteeReasons)
          end
        end
      end
    else
      program.membership_questions_for(role_names).each do |q|
        ProfileAnswer.populate 1 do |mem_ans|
          mem_ans.profile_question_id = q.id
          mem_ans.ref_obj_id = member.id
          mem_ans.ref_obj_type = Member.name
          # Answer for known questions
          if q.question_text == "Title"
            mem_ans.answer_text = Demo::Profession::Titles
          elsif q.question_text == 'Date of joining'
            year = Date.today.year
            mem_ans.answer_text = is_mentor ? ((year - 20)..(year - 5)) : (year..(year + 5))
          elsif q.question_text == 'Employee ID'
            mem_ans.answer_text = "#{['abc', 'msc', 'edf', 'vt'].sample}-2009-#{rand(100)}"
          elsif q.question_text == 'Reason to join'
            mem_ans.answer_text = (is_mentor ? Demo::Reasons::Enterprise::MentorReasons : Demo::Reasons::Enterprise::MenteeReasons)
          end
        end
      end
    end
  end

  mem_req = MembershipRequest.last
  MembershipRequest.skip_timestamping do
    mem_req.role_names = role_names
    mem_req.created_at = mem_req.updated_at = (0..5).to_a.sample.days.ago
    mem_req.save!
  end
  assert_valid mem_req
  mem_req
end

def populate_membership_requests(program, program_type)
  if (program_type == Demo::ProgramType::STUDENT.to_s)
    create_question(program: program,
      question_type: CommonQuestion::Type::STRING,
      question_text: "Degree",
      role_names: [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      required: true)
    create_question(program: program,
      question_type: CommonQuestion::Type::STRING,
      question_text: "Major",
      role_names: [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      required: true)
    create_question(program: program,
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_text: "Graduation year",
      question_choices: ProfileConstants.valid_graduation_years.collect(&:to_s),
      role_names: [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      required: true)
    create_question(program: program,
      question_type: CommonQuestion::Type::STRING,
      question_text: "Student Id / Roll number",
      role_names: [RoleConstants::STUDENT_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      required: true)
  else
    create_question(program: program,
      question_type: CommonQuestion::Type::STRING,
      question_text: "Title",
      role_names: [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      required: true)
    create_question(program: program,
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_text: "Date of joining",
      question_choices: ProfileConstants.valid_years.collect(&:to_s),
      role_names: [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      required: true)
    create_question(program: program,
      question_type: CommonQuestion::Type::STRING,
      question_text: "Employee ID",
      role_names: [RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      required: true)
  end
  say_populating "Membership requests" do
    5.times { create_membership_request(program, program_type, [RoleConstants::STUDENT_NAME]); dot }
    3.times { create_membership_request(program, program_type, [RoleConstants::MENTOR_NAME]); dot }
  end
end

# Create announcements
def create_announcement(program, title, content, role_names)

  Announcement.populate 1 do |announcement|
    announcement.program_id = program.id
    announcement.user_id = program.admin_users.first.id
    announcement.created_at = 1.day.ago..10.days.ago
  end

  announcement = Announcement.last
  announcement.title = title
  announcement.body = content
  announcement.recipient_role_names = role_names
  announcement.status = Announcement::Status::PUBLISHED
  announcement.email_notification = UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND
  announcement.save!
  assert_valid announcement
end

def populate_announcements(program)
  say_populating "Announcements" do
    Demo::Announcements::All.each do |ann|
      create_announcement(program, ann[:title], IO.read(demo_file("announcements", ann[:file])), [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
      dot
    end

    Demo::Announcements::Mentors.each do |ann|
      create_announcement(program, ann[:title], IO.read(demo_file("announcements", ann[:file])), [RoleConstants::MENTOR_NAME])
      dot
    end

    Demo::Announcements::Students.each do |ann|
      create_announcement(program, ann[:title], IO.read(demo_file("announcements", ann[:file])), [RoleConstants::STUDENT_NAME])
      dot
    end
  end
end

def create_program_and_organization(name, subdomain, index, options = {})
  program = nil
  organization = nil
  project_based = options[:engagement_type] == Program::EngagementType::PROJECT_BASED
  DataPopulator.benchmark_wrapper "Organization and Program creation" do
    organization = Organization.new
    organization.name = name
    organization.account_name = "#{name} (subdomain: #{subdomain}) Account (created on #{Time.now.utc.to_s})"
    organization.subscription_type = options[:subscription_type] || Organization::SubscriptionType::PREMIUM
    organization.footer_code = options[:footer_code]
    organization.description = options[:description]
    organization.save!
    DataPopulator.populate_default_contents(organization)

    pdomain = organization.program_domains.new()
    pdomain.subdomain = subdomain
    pdomain.domain = DEFAULT_DOMAIN_NAME
    pdomain.save!

    program = create_program(organization, index, options) unless options[:skip_program_creation]

    Organization.skip_timestamping do
      update_demo_features(organization)
      if organization.subscription_type.to_i == Organization::SubscriptionType::ENTERPRISE
        organization.enable_feature(FeatureName::CALENDAR) unless project_based
      end
      ProgramAsset.find_or_create_by(program_id: organization.id)
      organization.program_asset.logo = Rack::Test::UploadedFile.new(demo_file("pictures", "chronus_logo.jpg"), 'image/jpg', true)
      organization.program_asset.save
      organization.save!
      populate_theme(organization, options[:theme_name], options[:theme_css])
    end
    dot
  end
  [program, organization]
end

def create_program(organization, index, options = {})
  program = Program.new({
      name: options[:program_name],
      description: options[:description] || "Mentoring and career guidance @ #{organization.name}",
      root: Program.program_root_name(index)
    })
  program.organization = organization
  program.allow_one_to_many_mentoring = options[:allow_one_to_many_mentoring] || false
  program.created_at = options[:created_at] || 21.days.ago
  program.engagement_type = options[:engagement_type] || Program::EngagementType::CAREER_BASED_WITH_ONGOING
  program.save!

  DataPopulator.populate_default_contents(program) unless options[:skip_data_creation]

  #To Trigger the changed? option in program observer after_save
  program.mentor_request_style = options[:mentor_request_style] || Program::MentorRequestStyle::MENTEE_TO_MENTOR
  program.save!
  program
end

def create_portal(organization, index, options = {})
  portal = CareerDev::Portal.new({program_type: CareerDev::Portal::ProgramType::CHRONUS_CAREER, name: options[:program_name],
      description: options[:description] || "Career Development @ #{organization.name}",
      root: CareerDev::Portal.program_root_name(index)
    })
  portal.organization = organization
  portal.created_at = options[:created_at] || 21.days.ago
  portal.save!

  portal
end

def update_demo_features(program)
    FeatureName.default_demo_features.each do |feature|
      program.enable_feature(feature)
    end
    Feature.handle_feature_dependency(program)
end

def populate_education(user, answer)
  Education.populate 1..3 do |edu|
    edu.school_name = Demo::Educations::Schools
    edu.degree = user.is_mentor? ? Demo::Educations::MentorDegrees : Demo::Educations::MenteeDegrees
    edu.major = Demo::Educations::Majors
    edu.graduation_year = 1990..2009
    edu.profile_answer_id = answer.id
  end

  assert_valid Education.last
end

def populate_experience(user, answer)
  Experience.populate 2..4 do |exp|
    exp.job_title = (user.is_mentor? ? Demo::Workex::MentorJobTitles : Demo::Workex::MenteeJobTitles)
    exp.start_year = 1990..2000
    exp.end_year = 2000..2009
    exp.start_month = 0..12
    exp.end_month = 0..12
    exp.company = Demo::Workex::Organizations
    exp.current_job = false
    exp.profile_answer_id = answer.id
  end

  assert_valid Experience.last
end

def populate_user_profile_answer(q, user, use_answer = nil)
  member = user.member
  ProfileAnswer.populate 1 do |answer|
    answer.profile_question_id = q.id
    answer.ref_obj_id = member.id
    answer.ref_obj_type = 'Member'
    if use_answer
      answer.answer_text = use_answer
    elsif q.question_type == ProfileQuestion::Type::LOCATION
      loc_id = rand(0..Demo::Locations::Addresses.count-1)
      loc = Demo::Locations::Addresses[loc_id]
      f_address = [loc[:city], loc[:state], loc[:country]].join(",")
      location = Location.find_or_create_by_full_address(f_address)
      answer.location_id = location.id
      answer.answer_text = location.full_address
    end
    if q.question_text == "Phone"
      answer.answer_text = "#{['9899', '9773', '9876', '9736'].sample}#{rand(1000000)}"
    elsif q.question_text == "Skype ID"
      answer.answer_text = member.first_name
    end
  end
  answer = handle_choice_based_answers(q, use_answer)
  assert_valid answer
  answer
end

def handle_choice_based_answers(q, use_answer)
  answer = ProfileAnswer.last
  answer_texts = use_answer.split(",").map(&:strip) if use_answer.present?

  answer_texts ||=  case q.question_type
                    when ProfileQuestion::Type::MULTI_CHOICE
                      pick_random_values_from_array(q.default_choices.dup)
                    when ProfileQuestion::Type::SINGLE_CHOICE
                      q.default_choices.sample
                    end
  return answer if answer_texts.blank?
  ProfileAnswerObserver.without_callback(:before_save) do
    ProfileAnswerObserver.without_callback(:after_save) do
      answer.answer_value = {answer_text: answer_texts, question: q}
      answer.save(validate: false)
    end
  end
  answer
end

def populate_user_profile_answers(user, questions, answers = {})
  # For all the questions for which answers are supplied (the ones in the
  # answers hash), fill in the given answer, else populate answer from
  # Faker
  answers.each_pair do |q_text, ans|
    question = questions.select { |q| q.question_text == q_text }.first
    if (question)
      populate_user_profile_answer(question, user, ans)
      questions.delete(question)
    end
  end

  questions.each do |q|
    if q.education?
      answer = populate_user_profile_answer(q, user)
      populate_education(user, answer)
      answer.answer_value = answer.educations.to_a
      answer.save
    elsif q.experience?
      answer = populate_user_profile_answer(q, user)
      populate_experience(user, answer)
      answer.answer_value = answer.experiences.to_a
      answer.save
    else
      populate_user_profile_answer(q, user)
    end
    update_counter_cache_column(q, "profile_answers")
  end
end

#
# Since males and females are expected in 50-50 ratio, keep picking pics based
# on a sex-based counter. Mind you, this might repeat male/female pics if the
# a program happens to have all-male or all-female members (because 10 mentors +
# 20 mentees are created and there are only 25 pics of men and 25 of women).
# But thats a very race case.
#
$females_count = $males_count = 0;
$max_females_pics = Dir.glob("demo/pictures/women/*.jpg").size
$max_males_pics = Dir.glob("demo/pictures/men/*.jpg").size
def upload_user_profile_pic(user, gender = nil)
  # Based on the sex, choose the right picture from demo pics
  if ((gender == "Female") || user.female?)
    $females_count += 1
    if $females_count > $max_females_pics
      warn "Too many females. Repeating a few female profile pics.."
      $females_count = 1 # Reset counter
    end
    file_path = "demo/pictures/women/#{$females_count}.jpg"
  else
    $males_count += 1
    if $males_count > $max_males_pics
      warn "Too many males. Repeating a few male profile pics.."
      $males_count = 1 # Reset counter
    end
    file_path = "demo/pictures/men/#{$males_count}.jpg"
  end

  profile_picture = user.member.build_profile_picture
  profile_picture.image = Rack::Test::UploadedFile.new(file_path, 'image/jpg', true)
  assert_valid profile_picture
  profile_picture.save!
end

def populate_mentor_profile(mentor, answers = {})
  questions = mentor.program.profile_questions_for(RoleConstants::MENTOR_NAME).select(&:non_default_type?)
  populate_user_profile_answers(mentor, questions, answers)

  # Upload a sample pic for the user
  upload_user_profile_pic(mentor)
end

def populate_student_profile(student, answers = {})
  questions = student.program.profile_questions_for(RoleConstants::STUDENT_NAME).select(&:non_default_type?)
  populate_user_profile_answers(student, questions, answers)

  # Upload a sample pic for the user
  upload_user_profile_pic(student)
end

def create_program_mentor(program, mentor_id)
  subdomain = program.organization.subdomain
  first_name, last_name, email, gender =
    case mentor_id
  when 0
    ["Michael", "Brian", "#{subdomain}_mentor1@chronus.com", "Male"]
  when 1
    ["Bob","Sutton", "#{subdomain}_mentor2@chronus.com", "Male"]
  when 2
    ["Dean", "Parker", "#{subdomain}_mentor3@chronus.com", "Male"]
  else
    g = ["Male", "Female"].sample
    name = get_user_first_name(g)
    [name, Faker::Name.last_name, #@mentor_names[x][0], @mentor_names[x][1]
      unique_email_address("#{name}@example.com", program.organization), g]
  end
  last_seen = rand(15).days.ago
  cu = create_member(first_name: first_name, last_name: last_name, email: email, organization: program.organization)
  assert_valid cu
  mentor = create_user(role_names: [RoleConstants::MENTOR_NAME], member: cu, program: program)
  mentor.last_seen_at = last_seen
  assert_valid mentor
  populate_mentor_profile(mentor, "Gender" => gender)
  return mentor
end

def create_program_student(program, student_id)
  subdomain = program.organization.subdomain
  fname, lname, email, gender =
    case student_id
  when 0
    ["Philip", "Tyolkar", "#{subdomain}_mentee1@chronus.com", 'Male']
  when 2
    ["Kimberley","Harvard", "#{subdomain}_mentee2@chronus.com", 'Female']
  else
    g = ["Male", "Female"].sample
    name = get_user_first_name(g)
    [name, Faker::Name.last_name, #@mentee_names[x][0], @mentee_names[x][1]
      unique_email_address("#{name}@example.com", program.organization), g]
  end
  last_seen = rand(15).days.ago
  skype_id = (student_id == 0 ? 'vtvetrivel' : nil)
  cu = create_member(first_name: fname, last_name: lname, email: email, skype_id: skype_id, organization: program.organization)
  assert_valid cu
  student = create_user(role_names: [RoleConstants::STUDENT_NAME], member: cu, program: program)
  student.last_seen_at = last_seen
  assert_valid student
  populate_student_profile(student, "Gender" => gender)
  return student
end

def populate_mentoring_model_templates(program, mentoring_model_style)
  file_to_import = {0 => 'tasks.csv', 1 => 'tasks_goals.csv', 2 => 'tasks_goals_milestones.csv'}[mentoring_model_style]
  csv_content = File.read(Rails.root.join('demo','mentoring_model_templates', file_to_import).to_s)
  importer = MentoringModel::Importer.new(program.default_mentoring_model, csv_content)
  raise "Mentoring model templates import failed" unless importer.import.successful?
  importer = MentoringModel::Importer.new(program.mentoring_models.create!(title: program.name + "Template 2", default: false, mentoring_period: 10.months), csv_content)
  raise "Mentoring model templates import failed" unless importer.import.successful?
end

def populate_mentors_and_students(program, mentors_count = 10, students_count = 20)
  mentors = []
  students = []

  say_populating "Mentors" do
    mentors_count.times { |i| mentors << create_program_mentor(program, i); dot }
  end

  say_populating "Mentees" do
    students_count.times { |i| students << create_program_student(program, i); dot }
  end

  [mentors, students]
end

def populate_groups_between_mentors_and_students(program, subscription_type, count = 8, options = {})
  # Select only the unassigned mentors. This is done to prevent more than 1
  # group getting created for a mentor in the unmoderated group mentoring case
  say_populating "Groups" do
    unassigned_mentors = program.mentor_users.select { |m| m.mentoring_groups.empty? }
    unassigned_students = program.student_users.to_a

    project_based = options[:engagement_type] == Program::EngagementType::PROJECT_BASED

    count.times do
      # Pick a mentor & add to selected_mentors to not select same mentor again
      mentor = unassigned_mentors.sample
      unassigned_mentors.delete(mentor)

      # Pick random unassigned students and assign to selected_students to not
      # select the same student again for group creation
      students = []
      students_count = program.allow_one_to_many_mentoring? ? (rand(3) + 1) : 1
      students_count = [students_count, mentor.max_connections_limit].min
      students_count.times do
        random_student = unassigned_students.sample
        students << random_student
        unassigned_students.delete(random_student)
      end

      # Create the group
      create_group(mentor, subscription_type, students, project_based: project_based)
      dot
    end

    # Sanity check.
    program_groups_sanity_check(program)
  end
end

def create_qa_question(program, summary, desc, askers)
  QaQuestion.populate 1 do |question|
    question.program_id = program.id
    question.user_id = askers.collect(&:id)
    question.summary = summary
    question.description = desc
    question.qa_answers_count = 0
    question.views = 0
  end

  assert_valid QaQuestion.last
  QaQuestion.last
end

def create_qa_answer(question, answerers, ans)
  QaAnswer.populate 1 do |answer|
    answer.qa_question_id = question.id
    answer.user_id = answerers.collect(&:id)
    answer.content = ans
    answer.score = 0
  end

  # Update question.qa_answer_count counter cache
  update_counter_cache_column(question, "qa_answers")
  assert_valid QaAnswer.last
  QaAnswer.last
end

def populate_program_qa(program)
  say_populating "Questions and Answers" do
    Demo::QA::StudentQuestions.each do |qa|
      question = create_qa_question(program, qa[:summary], qa[:description], program.student_users)
      create_qa_answer(question, program.mentor_users, IO.read(demo_file('qa_answers', qa[:answer_file])))
      dot
      QaQuestion.skip_timestamping do
        question.created_at = rand(15).days.ago
        question.updated_at = rand(10).days.ago
      end
      question.save!
    end
    Demo::QA::MentorQuestions.each do |qa|
      question = create_qa_question(program, qa[:summary], qa[:description], program.mentor_users)
      create_qa_answer(question, program.mentor_users, IO.read(demo_file('qa_answers', qa[:answer_file])))
      dot
      QaQuestion.skip_timestamping do
        question.created_at = rand(15).days.ago
        question.updated_at = rand(10).days.ago
      end
      question.save!
    end
  end
end

def create_article_and_comments(program, article_details)
  # Create the article content
    title = article_details[:title]
    type = article_details[:type]
    status = ArticleContent::Status::PUBLISHED
    case article_details[:type]
    when ArticleContent::Type::TEXT
      body = IO.read(demo_file('articles', article_details[:content]))
      ac = ArticleContent.create(title: title, type: type, status: status, body: body, label_list: article_details[:label_list])
    when ArticleContent::Type::MEDIA
      embed_code = IO.read(demo_file('articles', article_details[:content]))
      ac = ArticleContent.create(title: title, type: type, status: status, embed_code: embed_code, label_list: article_details[:label_list] )
    when ArticleContent::Type::LIST
      ac = ArticleContent.create(title: title, type: type, status: status, label_list: article_details[:label_list] )
      article_details[:list].each do |item|
          list_content = item[1]
          list_description = item[2]
          if (item[0] == :book)
          ac.list_items << BookListItem.new(content: list_content, description: list_description)
          else
          ac.list_items << SiteListItem.new(content: list_content, description: list_description)
      end
      end
    else
      warn "Unallowed ArticleContent Type -#{article_details[:type]}. Check!!"
    end
   ac.save!
  # Create the article
    article = Article.create(view_count: (5..20).to_a.sample, helpful_count: (0..10).to_a.sample )
    article.article_content = ac
    article.author = program.mentor_users.collect{|user| user.member}.sample
    article.organization= program.organization
    article.save!
    Article::Publication.populate 1 do |publication|
      publication.program_id = program.id
      publication.article_id = article.id
    Comment.populate 1..5 do |comment|
        comment.article_publication_id = publication.id
        comment.user_id = program.users.collect(&:id)
        comment.body = Demo::Articles::ArticleComments
    end

  end

  assert_valid Article.last
  assert_valid Article.last.article_content
  assert_valid Article.last.publications.last.comments
  dot
end

def populate_program_articles(program, program_type)
  say_populating "Articles" do
    articles = Demo::Articles::CommonArticles
    if(program_type==Demo::ProgramType::STUDENT.to_s)
      articles += Demo::Articles::Student::TextArticles + Demo::Articles::Student::MediaArticles + Demo::Articles::Student::ListArticles
    else
      articles += Demo::Articles::Enterprise::TextArticles + Demo::Articles::Enterprise::MediaArticles + Demo::Articles::Enterprise::ListArticles
    end

    while !articles.empty?
      art = articles.delete(articles.sample)
      create_article_and_comments(program, art)
    end

    program.articles.published.each do |article_record|
    article = Article.find(article_record.id)
    Article.skip_timestamping do
       article.created_at = rand(15).days.ago
       article.updated_at = rand(10).days.ago
    end
    article.save!
    end

    article = Article.last
    article.view_count = 0
    article.helpful_count = 0
    article.save!
    article.get_publication(program).comments.destroy_all
  end
end

#TODO-CR:  populate response_id
def populate_program_survey(program)
  randomizer = [*1..5]
  say_populating "Mentoring relationship closure Survey" do
    #Populating Mentoring relationship closure
    survey = program.surveys.find_by(name: 'Mentoring Relationship Closure')
    users = program.mentor_users + program.student_users
    participants = users[-5..-1]
    survey.survey_questions.each do |q|
      participants.each do |participant|
        ans = SurveyAnswer.new
        ans.user = participant
        ans.type = 'SurveyAnswer'
        case q.question_type
        when SurveyQuestion::Type::SINGLE_CHOICE, SurveyQuestion::Type::RATING_SCALE
          ans.answer_value = {answer_text: q.default_choices.sample, question: q}
        when SurveyQuestion::Type::MULTI_CHOICE
          ans.answer_value = {answer_text: pick_random_values_from_array(q.default_choices.dup), question: q}
        end
        if q.question_text == "What are your major take-aways from this mentoring relationship?"
          ans.answer_text=Demo::Survey::AnswersTakeaway
        elsif q.question_text == "If no then what were the stumbling blocks?"
          ans.answer_text=Demo::Survey::AnswersBlocks
        elsif q.question_text == "Do you have any additional comments?"
          ans.answer_text=Demo::Survey::AnswersPartnership
        end
        # Rails Gotcha: Cannot use rails association names here. Populator
        # only infers the column names
        ans.common_question = q
        ans.survey_id = survey.id
        ans.last_answered_at = Time.now.utc + randomizer.sample.days
        ans.save!
        assert_valid SurveyAnswer.last
      end
      dot
    end
  end
end

def populate_default_campaigns(program)
  # Admin views are getting created from the program observer. The import has to be called only after the admin views are created. So, adding the default campaigns creation as djob
  # Although this doesn't ensure that import campaign is called after admin view creation, I think this is a reasonable assumption. Discussed with Sabarish as well
  say_populating "Campaigns" do
    DemoCampaignPopulator.delay.setup_program_with_default_campaigns(program.id)
  end
end

def create_and_save_invitation(program)
  admin = program.admin_users.first

  ProgramInvitation.populate 1 do |inv|
    inv.user_id = admin.id

    # Have a few expired invites created too.
    inv.created_at = rand(50).days.ago
    inv.sent_on = inv.created_at
    inv.sent_to = unique_email_address("invite_rand(50)@example.com", program.organization)
    inv.code = ProgramInvitation.generate_unique_code
    inv.program_id = program.id
    inv.expires_on = inv.created_at + 30.days
    inv.message = "I would like to invite you to join our mentoring program. Please click on the link below."
    inv.role_type = ProgramInvitation::RoleType::ASSIGN_ROLE
    inv.use_count = 0
  end

  inv = ProgramInvitation.last
  inv.role_names = [[RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].sample]
  inv.save! # save! runs validations, so no need to explicitly validate

  inv
end

def populate_invitations(program)
  say_populating "Invitations" do
    20.times { create_and_save_invitation(program); dot }
  end
end

def populate_theme(program, theme_name, css_file)
  return if css_file.blank?
  theme = Theme.new
  theme.name = theme_name
  theme.css = File.new(css_file)
  theme.save!
  program.activate_theme(theme)
end

def create_mentor_request(student)
  program = student.program

  MentorRequest.populate 1 do |mem_req|
    mem_req.sender_id = student.id
    mem_req.program_id = program.id

    mem_req.receiver_id = program.mentor_users.collect(&:id) if program.matching_by_mentee_alone?
    mem_req.message = Demo::MentorRequests::Requests
    mem_req.status = [AbstractRequest::Status::NOT_ANSWERED]
  end

  if program.matching_by_mentee_and_admin? # Build favorites
    req = MentorRequest.last
    mentor_ids = []
    all_mentor_ids = program.mentor_users.collect(&:id)
    (rand(4)  + 1).times { mentor_ids << all_mentor_ids.sample }
    mentor_ids.uniq!

    # Create favorites
    mentor_ids.each do |m|
      student.user_favorites.create!(favorite: User.find(m),
        note: Demo::MentorRequests::FavoriteReasons.sample)
    end

    # Update mentor request with favorites
    req.build_favorites(
      student.user_favorites.collect{|f| f.favorite.id}
    )
    req.save!
  end

  assert_valid MentorRequest.last
  MentorRequest.last
end

def populate_mentor_requests(program)
  return if program.matching_by_admin_alone?
  say_populating "Mentor requests" do
    program.student_users[3..-1].each do |stud|
      create_mentor_request(stud); dot
    end
  end

  # Accept a request and reject a request
  program.reload
  if program.matching_by_mentee_and_admin?
    req = program.mentor_requests.sample
    req.rejector = program.admin_users.first
    req.status = AbstractRequest::Status::REJECTED
    req.response_text = "All of your preferred mentors are busy right now. Can you please resend request with a different set of preferred mentors?"
    req.save!

    req2 = program.mentor_requests.active.sample
    req2.assign_mentor!(req2.favorites.first)
  else
    req = program.mentor_requests.sample
    req.rejector = req.mentor
    req.status = AbstractRequest::Status::REJECTED
    req.response_text = "I'm right now busy working with other of my mentees. Can you please seek mentoring from other mentors in the program? Thanks."
    req.save!

    req2 = program.mentor_requests.active.sample

    if program.matching_by_mentee_alone?
      req2.mark_accepted!
    else
      req2.status = AbstractRequest::Status::ACCEPTED
      req2.save!
    end
  end
end

def populate_pending_groups(program, count = 5)
  say_populating "Pending Projects" do
    Group.populate count do |group|
      group.name = Populator.words(2..4)
      group.program_id = program.id
      group.created_at = rand(7).days.ago
      group.global = true
      group.status = Group::Status::PENDING
    end
  end
end

def create_forum_topic(forum, topic_data, posts)
  students = forum.program.student_users
  mentors = forum.program.mentor_users
  Topic.populate 1 do |topic|
    topic.forum_id = forum.id
    topic.user_id = forum.available_for_student? ? students.collect(&:id) : mentors.collect(&:id)
    topic.title = topic_data[:title]
    topic.body = topic_data[:body]
    topic.updated_at = Time.now
    topic.hits = (10..30)
    post_contents = posts.split(",")
    # Create posts
    post_contents.each do |post_content|
      Post.populate 1 do |post|
        post.user_id = forum.available_for_student? ? students.collect(&:id) : mentors.collect(&:id)
        post.topic_id = topic.id
        post.body = post_content
      end
    end
  end

  topic = Topic.last
  last_updated = 100.days.ago
  topic.posts.each_with_index do |p, i|
    Post.skip_timestamping do
      p.created_at = p.updated_at = rand(4 + i).days.ago
      p.save!
      last_updated = p.created_at if (last_updated < p.created_at)
    end
  end
  topic.update_attribute(:updated_at, last_updated)
  update_counter_cache_column(topic, "posts")
  dot
  topic
end

def populate_program_forums(program, program_type)
  # Create Forums, topics, and posts
  say_populating "Forums and topics" do
    mentors_forum = program.forums.for_role(RoleConstants::MENTOR_NAME).first
    topics = (program_type==Demo::ProgramType::STUDENT ? Demo::Forums::Student::MentorTopics : Demo::Forums::Student::MentorTopics ) #Change to Enterprise if new Forum topics are added
    topics.each do |topic|
      posts = IO.read(demo_file("forums", topic[:posts]))
      create_forum_topic(mentors_forum, topic, posts)
    end

    Subscription.populate rand(5) do |sub1|
      sub1.user_id = program.mentor_users.collect(&:id).sample
      sub1.ref_obj_id = mentors_forum.id
      sub1.ref_obj_type = "forum"
      Subscription.skip_timestamping do
       sub1.created_at = rand(15).days.ago
       sub1.updated_at = rand(10).days.ago
      end
    end
    mentees_forum = program.forums.for_role(RoleConstants::STUDENT_NAME).first
    topics = (program_type==Demo::ProgramType::STUDENT ? Demo::Forums::Student::MenteeTopics : Demo::Forums::Student::MenteeTopics ) #Change to Enterprise if new Forum topics are added
    topics.each do |topic|
      posts = IO.read(demo_file("forums", topic[:posts]))
      create_forum_topic(mentees_forum, topic, posts)
    end

    Subscription.populate rand(10) do |sub|
      sub.user_id = program.student_users.collect(&:id).sample
      sub.ref_obj_id = mentees_forum.id
      sub.ref_obj_type = "forum"
      Subscription.skip_timestamping do
       sub.created_at = rand(15).days.ago
       sub.updated_at = rand(10).days.ago
      end
    end
  end
end

def populate_availability_slots(program)
  say_populating "availability slots" do
  mentors = program.mentor_users
  mentors.each do |mentor|
    location = (Demo::Groups::Meetings::Locations).sample
    date = rand(1..5).days.from_now.strftime("%B %d, %Y")
    offset = rand(1..5)
    start_time_of_day = offset.hours.from_now.strftime("%I:00 %p")
    end_time_of_day = (offset + rand(1..3)).hours.from_now.strftime("%I:00 %p")
    start_time, end_time = MentoringSlot.fetch_start_and_end_time(date,start_time_of_day,end_time_of_day)
    end_time = end_time + 1.day if start_time > end_time
    repeats = [MentoringSlot::Repeats::NONE, MentoringSlot::Repeats::DAILY, MentoringSlot::Repeats::WEEKLY,
      MentoringSlot::Repeats::MONTHLY].sample
    week = (repeats == MentoringSlot::Repeats::WEEKLY) ? start_time.wday.to_s : nil
    slot = MentoringSlot.create!(member: mentor.member,
      start_time: start_time, end_time: end_time , location: location,
      repeats: repeats, repeats_on_week: week, repeats_by_month_date: true)
    dot
    end
  end
end

def populate_fake_locations
  Demo::Locations::Addresses.each do |loc|
    Location.populate 1 do |location|
      location.city = loc[:city]
      location.state = loc[:state]
      location.country = loc[:country]
      location.reliable = [true, false]
      location.full_address = "#{location.city}, #{location.state}, #{location.country}"
      location.lat = (0..900000)
      location.lng = (0..3600000)
    end
  end
end

# ---- General purpose helpers ----

# Counter cache column does not work with update_attributes, update_attribute
# and assign-and-save. So, change the counter cache values directly in SQL
def update_counter_cache_column(for_object, association)
  table = for_object.class.table_name
  count = for_object.reload.send(association).count
  counter_column = "#{association}_count"
  ActiveRecord::Base.connection.execute("UPDATE #{table} SET #{counter_column}=#{count} where id=#{for_object.id}")
end

# Generate random choices by picking a random choice from
# the question choices for a random number of times
def pick_random_values_from_array(array, ratio = 3)
  chosen_values = []

  # for a random number of times
  chosen_values_count = rand(array.size / ratio)
  chosen_values_count.times do
    # picking a random value from the array
    answer = array[rand(array.size)]
    # Delete the value so that it doesn't come again
    chosen_values << array.delete(answer)
  end

  chosen_values.flatten
end

def get_user_first_name(sex)
  sex == "Female" ? Demo::Names::FemaleNames.sample : Demo::Names::MaleNames.sample
end

def demo_file(*path)
  file_name = path.pop
  dirs = path.join("/") + "/" unless path.empty?;
  Rails.root.to_s + "/demo/#{dirs}#{file_name}"
end

# If the email arg is unique, returns it, else mutates the email id and returns
# a new unique email address
def unique_email_address(email, organization)
  # Until the email is unique, mutate the email id.
  while true
    user = organization.members.find_by(email: email)
    return email unless user

    name, domain = email.split("@")
    email = "#{name}_#{rand(1000)}@#{domain}"
  end
end

def program_groups_sanity_check(program)
  program.reload
  if program.allow_one_to_many_mentoring? && program.matching_by_mentee_alone?
    program.groups.each do |group|
      # FIXME For multiple mentors
      if group.mentors.first.mentoring_groups.size > 1
        warn "Invalid config! More than 1 group for a mentor " +
          "(id: #{group.mentors.first.id}) in a group mentoring," +
          "unmoderated program. Check!"
      end
    end
  end
end

def assert_valid(obj)
  if obj.is_a?(Array) || obj.is_a?(ActiveRecord::Associations::CollectionProxy)
    obj.each { |entry| warn_about_invalid_object(obj) unless entry.valid? }
  else
    warn_about_invalid_object(obj) unless obj.valid?
  end
end

def warn_about_invalid_object(obj)
  warn "Invalid #{obj.class.name} object at hand. Check!"
  byebug if Rails.env == 'development'
end

# Print routines
def say_populating(model_name)
  print_and_flush "*** DemoPopulator :: Populating #{model_name} "
  yield
  newline
end

def warn(msg)
  print_and_flush "!!! WARNING: #{msg}\n"
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

def secure_digest(*args)
  Digest::SHA1.hexdigest(args.flatten.join('--'))
end
