#This controller is here to test the api links using scanner.
#We provide an infrastructure to scanner to crawl thrugh api links with proper methods
#Any new method added for api should be added here as well

class ApiTestsController < ApplicationController
  skip_before_action :login_required_in_program , :require_program, :back_mark_pages

  def index
    organization = Program::Domain.get_organization(ScannerConstants::PROGRAM_DOMAIN, ScannerConstants::PROGRAM_SUBDOMAIN)
    program = organization.programs.sample
    member = organization.members.find_by(email: ScannerConstants::ADMIN_EMAIL)
    member.enable_api!
    api_key = member.api_key
    @get_api_links = generate_get_api_links(program, api_key)
    @post_api_links = generate_post_api_links(program, api_key)
    @put_api_links = generate_put_api_links(program, api_key)
    @delete_api_links = generate_delete_api_links(program, api_key)
  end

  private

  def generate_get_api_links(program, api_key)
    user = program.users.sample
    group = program.groups.sample
    group_id = group ? group.id : ""
    links = {}
    suffix = "/p/#{program.root}/"
    links.merge!("Users index" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_users_path(api_key: api_key, format: :xml)}"))
    links.merge!("Drafted Connections Index" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connections_path(api_key: api_key, format: :xml, state: 0)}"))
    links.merge!("Ongoing Connections Index" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connections_path(api_key: api_key, format: :xml, state: 1)}"))
    links.merge!("Closed Connections Index" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connections_path(api_key: api_key, format: :xml, state: 2)}"))
    links.merge!("Users show" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_user_path(id: user.member_id, api_key: api_key, format: :xml)}"))
    links.merge!("Users show with profile fields" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_user_path(id: user.member_id, profile: 1, api_key: api_key, format: :xml)}"))
    links.merge!("Connections show" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connection_path(id: group_id, api_key: api_key, format: :xml)}"))
    links.merge!("Connections show with connection profile fields" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connection_path(id: group_id, profile: 1, api_key: api_key, format: :xml)}"))
    links.merge!("Mentor Profile Fields Index" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_profile_fields_path(api_key: api_key, roles: 'mentor', format: :xml)}"))
    links.merge!("Mentee Profile Fields Index" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_profile_fields_path(api_key: api_key, roles: 'mentee', format: :xml)}"))
    links.merge!("Connection Profile Fields Index" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connection_profile_fields_path(api_key: api_key, format: :xml)}"))
  end

  def generate_post_api_links(program, api_key)
    user = program.users.sample
    links = {}
    suffix = "/p/#{program.root}/"
    new_email = "new_user#{user.member.id}@chronus.com"
    mentor_email = program.mentor_users.collect(&:email).sample
    mentee_email = program.student_users.collect(&:email).sample
    links.merge!("User Create" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_users_path(uuid: new_email, api_key: api_key, email: new_email, roles: ['mentor', 'mentee'].sample, first_nam: 'Test', last_name: 'User', format: :xml)}"))
    links.merge!("Connection Create" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connections_path(mentor_email: mentor_email, mentee_email: mentee_email, api_key: api_key, format: :xml)}"))
  end

  def generate_put_api_links(program, api_key)
    suffix = "/p/#{program.root}/"
    user = program.mentor_users.sample
    group = program.groups.sample
    group_id = group ? group.id : ""
    profile_question = program.profile_questions_for(user.role_names).select{|q| q.text_type?}.sample
    profile_field = profile_question ? profile_question.id.to_s : ""
    connection_question = program.connection_questions.select{|q| !q.file_type?}.sample
    new_answer = (connection_question && connection_question.choice_based?) ? connection_question.default_choices.sample : 'new_answer'
    connection_field = connection_question ? connection_question.id.to_s : ""
    links = {}
    links.merge!("User Update" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_user_path(id: user.member_id, api_key: api_key, format: :xml, profile: {profile_field => 'new_answer'}, roles: [['mentor', 'mentee'].sample])}"))
    links.merge!("Connection Update" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connection_path(id: group_id, api_key: api_key, format: :xml, profile: {connection_field => new_answer}, expiry_date: '20301231')}"))
  end

  def generate_delete_api_links(program, api_key)
    suffix = "/p/#{program.root}/"
    user = (program.users-program.admin_users).sample
    user = program.users.sample
    group = program.groups.sample
    group_id = group ? group.id : ""
    links = {}
    links.merge!("User Delete" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_user_path(id: user.member_id, api_key: api_key, format: :xml)}"))
    links.merge!("Connection Delete" => ("#{suffix}#{chronus_mentor_api_engine.api_v2_connection_path(id: group_id, api_key: api_key, format: :xml)}"))
  end
end