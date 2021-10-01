require_relative './../../../test_helper.rb'

class Api::V2::MembersPresenterTest < ActiveSupport::TestCase

  def setup
    super
    @admin = members(:f_admin)
    @organization = @admin.organization
    @presenter = Api::V2::MembersPresenter.new(nil, @organization)
    @mentor = members(:f_mentor)
    Matching.expects(:perform_users_delta_index_and_refresh).at_least(0)
    Matching.expects(:remove_user).at_least(0).returns(nil)
  end

  def test_get_uuid_without_email_id
    result = @presenter.get_uuid
    assert_false result[:success]
    assert_equal ["email or login_name not passed"], result[:errors]
  end

  def test_get_uuid_with_unknown_email_id
    result = @presenter.get_uuid(email: 'some_random_email@chronus.com')
    assert_false result[:success]
    assert_equal ["member with email some_random_email@chronus.com not found"], result[:errors]
  end

  def test_get_uuid_success_with_proper_email
    result = @presenter.get_uuid({ email: @mentor.email})
    assert result[:success]
    assert_equal @mentor.id, result[:data][:uuid]
  end

  def test_get_uuid_with_unknown_login_name
    result = @presenter.get_uuid(login_name: "1234")
    assert_false result[:success]
    assert_equal ["member with login_name 1234 not found"], result[:errors]
  end

  def test_get_uuid_success_with_proper_login_name
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    @mentor.login_identifiers.create!(auth_config: custom_auth, identifier: "abcd")
    result = @presenter.get_uuid(login_name: "abcd")
    assert result[:success]
    assert_equal @mentor.id, result[:data][:uuid]
  end

  def test_destroy_cannot_remove
    params = { id: @mentor.id }
    result = {}

    Member.any_instance.expects(:can_be_removed_or_suspended?).returns(false)
    assert_no_difference 'Member.count' do
      result = @presenter.destroy(params)
    end
    assert_false result[:success]
    assert_equal result[:errors], ["This member cannot be removed"]
  end

  def test_destroy_invalid_id
    params = { id: 'random' }
    result = {}

    assert_no_difference 'Member.count' do
      result = @presenter.destroy(params)
    end
    assert_false result[:success]
    assert_equal result[:errors], ["member with uuid random not found"]
  end

  def test_destroy
    params = { id: @mentor.id }
    result = {}

    assert_difference 'Member.count', -1 do
      result = @presenter.destroy(params)
    end
    assert result[:success]
    expected_response = { uuid: @mentor.id }
    assert_equal result[:data], expected_response
    member = Member.find_by(id: @mentor.id)
    assert_nil member
  end

  def test_list
    result = @presenter.list
    assert_equal @organization, @presenter.organization
    assert_nil @presenter.program
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 58, result[:data].size
  end

  def test_list_with_profile_and_updated_after
    updated_after_time_stamp = DateTime.localize(1.minute.ago.utc, format: :full_date_full_time)
    member = members(:f_mentor)
    skype_question = member.organization.profile_questions.find_by(question_type: ProfileQuestion::Type::SKYPE_ID)
    skype_answer = member.profile_answers.build(profile_question_id: skype_question.id)
    skype_answer.answer_text = "skypeid"
    skype_answer.save!

    result = @presenter.list(updated_after: updated_after_time_stamp, profile: 1)
    assert result[:success]
    assert_equal 1, result[:data].size
    data = result[:data].first
    assert_equal member.first_name, data["first_name"]
    assert_equal member.id, data["uuid"]
    assert_equal member.state, data["status"]
    assert_equal member.email, data["email"]
    assert_equal member.last_name, data["last_name"]
    assert_false data.keys.include?("programs")
    member_profile = data["profile_updates"]
    assert member_profile.keys.count == 1
    assert member_profile.keys.first, "field_value_#{skype_question.id.to_s}"
    profile_answer_hash = member_profile.values.first
    assert profile_answer_hash[:field_id], skype_question.id
    assert profile_answer_hash[:field_name], skype_question.question_text
    assert profile_answer_hash[:value], skype_answer.answer_text
    assert profile_answer_hash[:applicable], 1
  end

  def test_list_with_invalid_timestamp
    result = @presenter.list(profile: 1, updated_after: "asas")
    expected_errors = ["Invalid timestamp asas for updated after"]
    assert_false result[:success]
    assert_equal expected_errors, result[:errors]
    expected_errors = ["updated_after not passed"]
    result = @presenter.list(profile: 1)
    assert_false result[:success]
    assert_equal expected_errors, result[:errors]
  end

  def test_list_with_invalid_created_after
    result = @presenter.list(profile: 1, created_after: "asas")
    expected_errors = ["Invalid timestamp asas for created after"]
    assert_false result[:success]
    assert_equal expected_errors, result[:errors]
  end

  def test_list_with_created_after
    created_after = DateTime.localize(1.minute.ago.utc, format: :full_date_full_time)
    member = members(:f_mentor)
    member.update_columns(created_at: Time.now.utc)
    result = @presenter.list(created_after: created_after, members_list: true)
    assert result[:success]
    assert_equal 1, result[:data].size
    data = result[:data].first
    assert_equal member.first_name, data["first_name"]
    assert_equal member.id, data["uuid"]
    assert_equal member.state, data["status"]
    assert_equal member.email, data["email"]
    assert_equal member.last_name, data["last_name"]
    assert data.keys.include?("programs")
    assert_false data.keys.include?("profile_updates")
  end

  def test_update_member_profile_with_wrong_argument
    params = {
      id: @mentor.id,
      email: "wrong_format",
      first_name: (0...120).map { 'a' }.join,
      last_name: ""
    }

    expected_errors = ["Last name can't be blank, Last name is too short (minimum is 1 character), First name is too long (maximum is 100 characters), Email is not a valid email address."]
    result = @presenter.update(params)
    assert_false result[:success]
    assert_equal expected_errors, result[:errors]
  end

  def test_update_member_not_found
    params = { id: "unknown_id", email: "example@chronus.com" }
    result = @presenter.update(params)
    assert_false result[:success]
    assert_equal ["member with uuid unknown_id not found"], result[:errors]
  end

  def test_update_profile_question_error
    multiple_choice_type_question = profile_questions(:profile_questions_11)
    error_message = ["Validation failed: Answer text contains an invalid choice"]
    update_profile_question(multiple_choice_type_question, "Unknown,Random", error_message)
    single_choice_type_question = profile_questions(:profile_questions_9)
    update_profile_question(single_choice_type_question, "Some random choice", error_message)

    education_type_question = profile_questions(:education_q)
    error_message = ["school_name not passed"]
    update_profile_question(education_type_question, {}, error_message)

    experience_type_question = profile_questions(:experience_q)
    error_message = ["company not passed"]
    update_profile_question(experience_type_question, {}, error_message)

    publication_type_question = profile_questions(:publication_q)
    error_message = ["title not passed"]
    update_profile_question(publication_type_question, {}, error_message)

    manager_type_question = profile_questions(:manager_q)
    error_message = ["first_name not passed, last_name not passed, email not passed"]
    update_profile_question(manager_type_question, {}, error_message)
  end

  def test_update_member_attrs
    custom_auth_1 = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    custom_auth_2 = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SOAP)
    login_identifier_1 = @mentor.login_identifiers.create!(auth_config: custom_auth_1, identifier: "uid")

    assert_difference "LoginIdentifier.count" do
      @presenter.update(id: @mentor.id, first_name: "Sachin", last_name: "Tendulkar", email: "sachin@chronus.com", login_name: "updated-uid")
    end
    assert_equal "Sachin", @mentor.reload.first_name
    assert_equal "Tendulkar", @mentor.last_name
    assert_equal "sachin@chronus.com", @mentor.email
    assert_equal "updated-uid", login_identifier_1.reload.identifier
    assert_equal "updated-uid", @mentor.login_identifiers.find_by(auth_config_id: custom_auth_2.id).identifier
  end

  def test_update_profile_question_success
    string_type_question = profile_questions(:profile_questions_4)
    update_profile_question(string_type_question, "9876543210")
    update_profile_question(string_type_question, "0123456789")

    text_type_question = profile_questions(:profile_questions_8)
    update_profile_question(text_type_question, "About me! Some cool stuff")
    update_profile_question(text_type_question, "About me! Some wierd stuff")

    single_choice_type_question = profile_questions(:profile_questions_9)
    update_profile_question(single_choice_type_question, "Female")
    update_profile_question(single_choice_type_question, "Male")

    multiple_choice_type_question = profile_questions(:profile_questions_11)
    update_profile_question(multiple_choice_type_question, "Legal,Management")
    update_profile_question(multiple_choice_type_question, "Accounting/Auditing")

    location_type_question = profile_questions(:profile_questions_3)
    update_profile_question(location_type_question, "Chennai, Tamil Nadu, India")
    chennai = locations(:chennai)
    member_answer = @mentor.answer_for(location_type_question)
    assert_equal member_answer.location, chennai
  end

  def test_should_abort_update_if_any_error_education_question
    string_type_question = profile_questions(:profile_questions_4)
    update_profile_question(string_type_question, "9876543210")
    education_type_question = profile_questions(:multi_education_q)

    @mentor.educations.each{|e| e.destroy}
    @mentor.reload
    education_params = {
      "0" => {
          "school_name" => "Test School Name",
          "degree" => "Test Btech",
          "major" => "Test CSE",
          "graduation_year" => 1998
        },
      "1" => {
          "school_name" => "Test School Name 2",
          "degree" => "Test Btech 2",
          "major" => "Test CSE 2",
          "graduation_year" => Time.now.year + 20
      }
    }

    profile_params = {}
    profile_params[education_type_question.id.to_s] = HashWithIndifferentAccess.new(education_params)
    profile_params[string_type_question.id] = "9999999999"
    params = {id: @mentor.id, email: "new_email_id@example.com", profile: profile_params}
    result = @presenter.update(params)
    @mentor.reload

    assert_false result[:success]
    assert_equal ["Validation failed: One or more of your educations is invalid"], result[:errors]
    education_answer = @mentor.answer_for(education_type_question)
    assert_nil education_answer
    assert_equal 0, @mentor.educations.size

    string_answer =  @mentor.answer_for(string_type_question)
    assert_equal "9876543210", string_answer.answer_text
    assert_equal "robert@example.com", @mentor.email
  end

  def test_update_education_type_question
    # create education answer
    education_type_question = profile_questions(:education_q)
    education_answer = @mentor.answer_for(education_type_question)
    education_answer.destroy

    education_params = {
      "school_name" => "Test School Name",
      "degree" => "Test Btech",
      "major" => "Test CSE",
      "graduation_year" => 1998
    }

    profile_params = {}
    profile_params[education_type_question.id.to_s] = HashWithIndifferentAccess.new(education_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    education_answer = @mentor.answer_for(education_type_question)
    assert_equal 1, education_answer.educations.size
    education_updated = education_answer.educations.first
    education_asserts education_params, education_updated

    #create new education answer
    education_params = {
      "school_name" => "Test School Name updated",
      "degree" => "Test Btech updated",
      "major" => "Test CSE updated",
      "graduation_year" => 1999
    }

    profile_params = {}
    profile_params[education_type_question.id.to_s] = HashWithIndifferentAccess.new(education_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    education_answer = @mentor.answer_for(education_type_question)
    assert_equal 1, education_answer.educations.size
    education_updated = education_answer.educations.first
    education_asserts education_params, education_updated

    #update multi education type question
    education_type_question = profile_questions(:multi_education_q)
    education_answer = @mentor.answer_for(education_type_question)
    education_answer.destroy if education_answer.present?

    education_params = {
      "0" => {
          "school_name" => "Test School Name",
          "degree" => "Test Btech",
          "major" => "Test CSE",
          "graduation_year" => 1998
        },
      "1" => {
          "school_name" => "Test School Name 2",
          "degree" => "Test Btech 2",
          "major" => "Test CSE 2",
          "graduation_year" => 2001
      }
    }

    profile_params = {}
    profile_params[education_type_question.id.to_s] = HashWithIndifferentAccess.new(education_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    education_answer = @mentor.answer_for(education_type_question)
    assert_equal 2, education_answer.educations.size
    first_education = education_answer.educations.find_by(school_name: "Test School Name")
    second_education = education_answer.educations.find_by(school_name: "Test School Name 2")
    assert_not_nil first_education
    assert_not_nil second_education
    education_asserts education_params["0"], first_education
    education_asserts education_params["1"], second_education

    education_params = {
      "0" => {
          "school_name" => "Test School Name 3",
          "degree" => "Test Btech 3",
          "major" => "Test CSE 3",
          "graduation_year" => 1998
        }
    }

    profile_params = {}
    profile_params[education_type_question.id.to_s] = HashWithIndifferentAccess.new(education_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    education_answer = @mentor.answer_for(education_type_question)
    assert_equal 1, education_answer.educations.size
    education_asserts education_params["0"], education_answer.educations.first
  end

  def test_should_abort_update_if_any_error_experiences_question
    string_type_question = profile_questions(:profile_questions_4)
    update_profile_question(string_type_question, "9876543210")
    experience_type_question = profile_questions(:multi_experience_q)

    @mentor.experiences.each{|e| e.destroy}
    @mentor.reload
    experience_params = {
      "0" => {
        "job_title" => "Test Job Name",
        "company" => "Test company",
        "start_year" => 1996,
        "end_year" => 1998
      },
      "1" => {
        "job_title" => "Test Job Name 2",
        "company" => "Test company 2",
        "start_year" => 1999,
        "end_year" => Time.now.year + 20
      }
    }

    profile_params = {}
    profile_params[experience_type_question.id.to_s] = HashWithIndifferentAccess.new(experience_params)
    profile_params[string_type_question.id] = "9999999999"
    params = {id: @mentor.id, email: "new_email_id@example.com", profile: profile_params}
    result = @presenter.update(params)
    @mentor.reload
    assert_false result[:success]
    assert_equal ["Validation failed: One or more of your experiences is invalid"], result[:errors]
    experience_answer = @mentor.answer_for(experience_type_question)
    assert_nil experience_answer
    assert_equal 0, @mentor.experiences.size

    string_answer =  @mentor.answer_for(string_type_question)
    assert_equal "9876543210", string_answer.answer_text
    assert_equal "robert@example.com", @mentor.email
  end


  def test_update_experience_type_question
    #create experience answer
    experience_type_question = profile_questions(:experience_q)
    experience_answer = @mentor.answer_for(experience_type_question)
    experience_answer.destroy

    experience_params = {
      "job_title" => "Test Job Name",
      "company" => "Test company",
      "start_year" => 1996,
      "end_year" => 1998
    }

    profile_params = {}
    profile_params[experience_type_question.id.to_s] = HashWithIndifferentAccess.new(experience_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    experience_answer = @mentor.answer_for(experience_type_question)
    assert_equal 1, experience_answer.experiences.size
    experience_updated = experience_answer.experiences.first
    experience_asserts experience_params, experience_updated

    #create new experience answer
    experience_params = {
      "job_title" => "Test Job updated Name",
      "company" => "Test updated  company",
      "start_year" => 1992,
      "end_year" => 1994
    }
    profile_params = {}
    profile_params[experience_type_question.id.to_s] = HashWithIndifferentAccess.new(experience_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    experience_answer = @mentor.answer_for(experience_type_question)
    assert_equal 1, experience_answer.experiences.size
    experience_updated = experience_answer.experiences.first
    experience_asserts experience_params, experience_updated

    #create multi experience answer
    experience_type_question = profile_questions(:multi_experience_q)
    experience_answer = @mentor.answer_for(experience_type_question)
    experience_answer.destroy

    experience_params = {
      "0" => {
        "job_title" => "Test Job Name",
        "company" => "Test company",
        "start_year" => 1996,
        "end_year" => 1998
      },
      "1" => {
        "job_title" => "Test Job Name 2",
        "company" => "Test company 2",
        "start_year" => 1999,
        "end_year" => 2001
      }
    }

    profile_params = {}
    profile_params[experience_type_question.id.to_s] = HashWithIndifferentAccess.new(experience_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    experience_answer = @mentor.answer_for(experience_type_question)
    assert_equal 2, experience_answer.experiences.size

    first_experience = experience_answer.experiences.find_by(job_title: "Test Job Name")
    second_experience = experience_answer.experiences.find_by(job_title: "Test Job Name 2")
    assert_not_nil first_experience
    assert_not_nil second_experience
    experience_asserts experience_params["1"], second_experience
    experience_asserts experience_params["0"], first_experience

    #create new experience answer
    experience_params = {
      "0" => {
        "job_title" => "Test Job updated Name 3",
        "company" => "Test updated  company 3",
        "start_year" => 1992,
        "end_year" => 1994
      }
    }
    profile_params = {}
    profile_params[experience_type_question.id.to_s] = HashWithIndifferentAccess.new(experience_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    experience_answer = @mentor.answer_for(experience_type_question)
    assert_equal 1, experience_answer.experiences.size
    experience_asserts experience_params["0"], experience_answer.experiences.first
  end

  def test_should_abort_update_if_any_error_publications_question
    string_type_question = profile_questions(:profile_questions_4)
    update_profile_question(string_type_question, "9876543210")
    publication_type_question = profile_questions(:multi_publication_q)
    @mentor.publications.each{|e| e.destroy}
    @mentor.reload
    publication_params = {
      "0" => {
        "title" => "Test publication Name",
        "publisher" => "Test publisher",
        "url" => "http://testurl.com",
        "authors" => "test authors",
        "description" => "Test description",
        "day" => 11,
        "month" => 12,
        "year" => 2001},

      "1" => {
        "publisher" => "Test publisher 2",
        "url" => "some_radom_url",
        "authors" => "test authors 2",
        "description" => "Test description 2",
        "day" => 12,
        "month" => 15,
        "year" => Time.now.year + 20}
    }

    profile_params = {}
    profile_params[publication_type_question.id.to_s] = HashWithIndifferentAccess.new(publication_params)
    profile_params[string_type_question.id] = "9999999999"
    params = {id: @mentor.id, email: "new_email_id@example.com", profile: profile_params}
    result = @presenter.update(params)
    @mentor.reload
    assert_false result[:success]
    assert_equal ["title not passed"], result[:errors]
    publication_answer = @mentor.answer_for(publication_type_question)
    assert_nil publication_answer
    assert_equal 0, @mentor.publications.size

    string_answer = @mentor.answer_for(string_type_question)
    assert_equal "9876543210", string_answer.answer_text
    assert_equal "robert@example.com", @mentor.email
  end

  def test_update_publication_type_question
    #create publication answer
    publication_type_question = profile_questions(:publication_q)
    publication_answer = @mentor.answer_for(publication_type_question)
    publication_answer.destroy

    publication_params = {
      "title" => "Test publication Name",
      "publisher" => "Test publisher",
      "url" => "http://testurl.com",
      "authors" => "test authors",
      "description" => "Test description",
      "day" => 11,
      "month" => 12,
      "year" => 2001
    }

    profile_params = {}
    profile_params[publication_type_question.id.to_s] = HashWithIndifferentAccess.new(publication_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    publication_answer = @mentor.answer_for(publication_type_question)
    assert_equal 1, publication_answer.publications.size
    publication_updated = publication_answer.publications.first
    publication_asserts publication_params, publication_updated

    #create new publication answer
    publication_params = {
      "title" => "Test publication Name updated",
      "publisher" => "Test publisher updated",
      "url" => "http://testurl.com/updated",
      "authors" => "test authors updated",
      "description" => "Test description updated",
      "day" => 10,
      "month" => 11,
      "year" => 2002
    }

    profile_params = {}
    profile_params[publication_type_question.id.to_s] = HashWithIndifferentAccess.new(publication_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    publication_answer = @mentor.answer_for(publication_type_question)
    assert_equal 1, publication_answer.publications.size
    publication_updated = publication_answer.publications.first
    publication_asserts publication_params, publication_updated

    #create publication answer
    publication_type_question = profile_questions(:multi_publication_q)
    publication_answer = @mentor.answer_for(publication_type_question)
    publication_answer.destroy

    publication_params = {
      "0" => {
        "title" => "Test publication Name",
        "publisher" => "Test publisher",
        "url" => "http://testurl.com",
        "authors" => "test authors",
        "description" => "Test description",
        "day" => 11,
        "month" => 12,
        "year" => 2001},

      "1" => {
        "title" => "Test publication Name 2",
        "publisher" => "Test publisher 2",
        "url" => "http://testurl.com/2",
        "authors" => "test authors 2",
        "description" => "Test description 2",
        "day" => 12,
        "month" => 1,
        "year" => 2004}
    }

    profile_params = {}
    profile_params[publication_type_question.id.to_s] = HashWithIndifferentAccess.new(publication_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    publication_answer = @mentor.answer_for(publication_type_question)
    assert_equal 2, publication_answer.publications.size
    first_publication = publication_answer.publications.find_by(title: "Test publication Name")
    assert_not_nil first_publication
    second_publication = publication_answer.publications.find_by(title: "Test publication Name 2")
    assert_not_nil first_publication
    assert_not_nil second_publication
    publication_asserts publication_params["0"], first_publication
    publication_asserts publication_params["1"], second_publication

    #create new publication answer
    publication_params = {
      "0" => {
        "title" => "Test publication Name 3",
        "publisher" => "Test publisher 3",
        "url" => "http://testurl.com/3",
        "authors" => "test authors 3",
        "description" => "Test description 3",
        "day" => 11,
        "month" => 12,
        "year" => 2008}
    }

    profile_params = {}
    profile_params[publication_type_question.id.to_s] = HashWithIndifferentAccess.new(publication_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    publication_answer = @mentor.answer_for(publication_type_question)
    assert_equal 1, publication_answer.publications.size
    publication_updated = publication_answer.publications.first
    publication_asserts publication_params["0"], publication_answer.publications.first
  end

  def test_should_abort_update_if_any_error_manager_question
    string_type_question = profile_questions(:profile_questions_4)
    update_profile_question(string_type_question, "9876543210")
    manager_type_question = profile_questions(:manager_q)
    @mentor.manager.destroy
    @mentor.reload

    manager_params = {
      "first_name" => "Test manager First Name updated",
      "last_name" => "Test manager last name updated",
      "email" => "wrong_email_format"
    }

    profile_params = {email: "new_email_id@example.com"}
    profile_params[manager_type_question.id.to_s] = HashWithIndifferentAccess.new(manager_params)
    profile_params[string_type_question.id] = "9999999999"
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    @mentor.reload
    assert_false result[:success]
    assert_equal ["Validation failed: Manager is invalid"], result[:errors]
    manager_answer = @mentor.answer_for(manager_type_question)
    assert_nil manager_answer
    assert_nil @mentor.manager

    string_answer =  @mentor.answer_for(string_type_question)
    assert_equal "9876543210", string_answer.answer_text

    assert_equal "robert@example.com", @mentor.email
  end

  def test_update_manager_type_question
    #create manager answer
    manager_type_question = profile_questions(:manager_q)
    manager_answer = @mentor.answer_for(manager_type_question)
    manager_answer.destroy

    manager_params = {
      "first_name" => "Test manager First Name",
      "last_name" => "Test manager last name",
      "email" => "test_manager1@example.com"
    }

    profile_params = {}
    profile_params[manager_type_question.id.to_s] = HashWithIndifferentAccess.new(manager_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    manager_answer = @mentor.answer_for(manager_type_question)

    manager_updated = manager_answer.manager
    manager_asserts manager_params, manager_updated

    #create new manager answer
    manager_params = {
      "first_name" => "Test manager First Name updated",
      "last_name" => "Test manager last name updated",
      "email" => "udpated_test_manager1@example.com"
    }
    profile_params = {}
    profile_params[manager_type_question.id.to_s] = HashWithIndifferentAccess.new(manager_params)
    params = {id: @mentor.id, profile: profile_params}
    result = @presenter.update(params)
    manager_answer = @mentor.answer_for(manager_type_question)
    manager_updated = manager_answer.manager
    manager_asserts manager_params, manager_updated
  end

  def test_list_return_values
    admin = members(:f_admin)
    Organization.any_instance.expects(:members).returns(Member.where(email: admin.email))
    result = @presenter.list(members_list: 1)
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 1, result[:data].size
    member = result[:data][0]
    assert_equal admin.first_name, member["first_name"]
    assert_equal admin.last_name, member["last_name"]
    assert_equal admin.email, member["email"]
    assert_equal admin.state, member["status"]
    assert_equal admin.id, member["uuid"]
    programs = member["programs"]
    admin.users.each do |u|
      user_hash = programs[u.program.name]
      assert_equal ({status: UsersHelper::STATE_TO_INTEGER_MAP[u.state], roles: ["admin"]}), user_hash
    end
  end

  def test_list_with_email_filter
    result = @presenter.list({email: members(:f_admin).email})
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 1, result[:data].size
  end

  def test_list_with_status
    result = @presenter.list({status: Member::Status::ACTIVE})
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal programs(:org_primary).members.where(state: Member::Status::ACTIVE).count, result[:data].size

    result = @presenter.list({status: Member::Status::SUSPENDED})
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 0, result[:data].size
    members(:f_admin).update_attribute(:state, Member::Status::SUSPENDED)
    result = @presenter.list({status: Member::Status::SUSPENDED})
    assert_instance_of Hash, result
    assert result[:success]
    assert_instance_of Array, result[:data]
    assert_equal 1, result[:data].size
  end

  def test_create_get_errors_when_first_name_missing
    params = get_unique_params last_name: true, email: true
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["first name not passed"]
    assert_equal count, Member.count
  end

  def test_create_get_errors_when_last_name_missing
    params = get_unique_params first_name: true, email: true
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["last name not passed"]
    assert_equal count, Member.count
  end

  def test_create_get_errors_when_email_missing
    params = get_unique_params first_name: true, last_name: true
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["email not passed"]
    assert_equal count, Member.count
  end

  def test_create_get_errors_when_first_name_and_last_name_missing
    params = get_unique_params email: true
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["first name not passed", "last name not passed"]
    assert_equal count, Member.count
  end

  def test_create_get_errors_when_first_name_and_email_missing
    params = get_unique_params last_name: true
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["first name not passed", "email not passed"]
    assert_equal count, Member.count
  end

  def test_create_get_errors_when_last_name_and_email_missing
    params = get_unique_params first_name: true
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["last name not passed", "email not passed"]
    assert_equal count, Member.count
  end

  def test_create_get_errors_when_first_name_last_name_and_email_missing
    params = {}
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["first name not passed", "last name not passed", "email not passed"]
    assert_equal count, Member.count
  end

  def test_get_errors_when_member_with_email_already_exists
    params = get_unique_params first_name: true, last_name: true
    params[:email] = "ram@example.com"
    count = Member.count
    result = @presenter.create(params)
    assert_equal result[:success], false
    assert_equal result[:errors], ["member with email_id: 'ram@example.com' already exists"]
    assert_equal count, Member.count
  end

  def test_create_success
    params = get_unique_params first_name: true, last_name: true, email: true
    count = Member.count
    result = @presenter.create(params)
    expected_new_member = Member.last
    assert result[:success]
    assert_equal count + 1, Member.count
    assert_equal result[:data], { uuid: expected_new_member.id}
    assert_equal expected_new_member.first_name, "first_name"
    assert_equal expected_new_member.last_name, "last_name"
    assert_equal @organization.id, expected_new_member.organization.id
    assert_equal expected_new_member.email, "unique_email@chronus.com"
    assert_equal expected_new_member.state, Member::Status::DORMANT
  end

  def test_create_success_login_name
    custom_auth = @organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    params = get_unique_params first_name: true, last_name: true, email: true, login_name: true
    count = Member.count
    result = @presenter.create(params)
    expected_new_member = Member.last
    login_identifiers = expected_new_member.login_identifiers
    assert result[:success]
    assert_equal count + 1, Member.count
    assert_equal_hash( { uuid: expected_new_member.id }, result[:data])
    assert_equal "first_name", expected_new_member.first_name
    assert_equal "last_name", expected_new_member.last_name
    assert_equal "unique_email@chronus.com", expected_new_member.email
    assert_equal expected_new_member.organization_id, @organization.id
    assert_equal [custom_auth], login_identifiers.map(&:auth_config)
    assert_equal ["login_name"], login_identifiers.map(&:identifier)
    assert_equal Member::Status::DORMANT, expected_new_member.state
  end

  def test_create_member_save_fail
    params = get_unique_params(last_name: true, email: true, login_name: true).merge(first_name: "numeric1234")
    count = Member.count
    result = @presenter.create(params)
    assert_false result[:success]
    assert_equal ["First name contains numeric characters"], result[:errors]
  end

  def test_update_status_when_uuid_not_passed
    params = {
      status: Member::Status::ACTIVE
    }
    expected_result = {
      success: false,
      errors: ["uuid not passed"]
    }
    result = @presenter.update_status(params)
    assert_equal expected_result, result
  end

  def test_update_status_when_status_not_passed
    params = {
      uuid: members(:f_student).id
    }
    expected_result = {
      success: false,
      errors: ["status not passed"]
    }
    result = @presenter.update_status(params)
    assert_equal expected_result, result
  end

  def test_update_status_when_status_and_uuid_not_passed
    params = {}
    expected_result = {
      success: false,
      errors: ["uuid not passed", "status not passed"]
    }
    result = @presenter.update_status(params)
    assert_equal expected_result, result
  end

  def test_update_status_when_member_with_uuid_dont_exist
    params = {
      uuid: Member.last.id + 1,
      status: Member::Status::ACTIVE
    }
    expected_result = {
      success: false,
      errors: ["member with uuid '#{Member.last.id + 1}' not found"]
    }
    result = @presenter.update_status(params)
    assert_equal expected_result, result
  end

  def test_update_status_when_invalid_status_passed
    params = {
      uuid: members(:f_student).id,
      status: -1
    }
    expected_result = {
      success: false,
      errors: ["invalid update status passed"]
    }
    result = @presenter.update_status(params, @admin)
    assert_equal expected_result, result

    params[:status] = Member::Status::DORMANT
    result = @presenter.update_status(params, @admin)
    assert_equal expected_result, result
  end

  def test_update_status_invalid_state_transition
    params = {
      uuid: members(:f_student).id,
      status: Member::Status::SUSPENDED
    }
    expected_result = {
      success: false,
      errors: ["This state transition is not allowed"]
    }

    Member.any_instance.expects(:state_transition_allowed?).returns(false)
    result = @presenter.update_status(params, @admin)
    assert_equal expected_result, result
  end

  def test_update_status_success
    member = members(:f_student)
    params = {
      uuid: member.id,
      status: 2
    }
    expected_result = {
      success: true,
      data:{
        first_name: member.first_name,
        last_name: member.last_name,
        email: member.email,
        status: Member::Status::SUSPENDED,
        uuid: member.id,
        login_name: ""
      }
    }
    result = @presenter.update_status(params, @admin)
    assert_equal expected_result, result
    assert_equal member.reload.state, 2
  end

  def test_update_status_member_with_no_user_to_active
    new_member = Member.new
    new_member.organization = @organization
    new_member.email = "test@chronus.com"
    new_member.first_name = "first"
    new_member.last_name = "last"
    new_member.save
    params = {
      uuid: new_member.id,
      status: 0
    }
    expected_result = {
      success: false,
      errors: ["This state transition is not allowed"]
    }
    result = @presenter.update_status(params, @admin)
    assert_equal expected_result, result
  end

  def test_update_status_dormant_to_suspended
    new_member = Member.new
    new_member.organization = @organization
    new_member.email = "test@chronus.com"
    new_member.first_name = "first"
    new_member.last_name = "last"
    new_member.state = Member::Status::DORMANT
    new_member.save
    params = {
      uuid: new_member.id,
      status: 2
    }
    expected_result = {
      success: true,
      data: {
        first_name: "first",
        last_name: "last",
        email: "test@chronus.com",
        status: 2,
        uuid: new_member.id,
        login_name: ""
      }

    }
    result = @presenter.update_status(params, @admin)
    assert_equal expected_result, result
  end

  def test_find_failure
    params = Member.last.id+1
    result = @presenter.find(params)
    assert_false result[:success]
    assert_equal ["user with uuid '#{params}' not found"], result[:errors]
  end

  def test_find_success
    member = members(:f_mentor)
    result = @presenter.find(member.id, profile: 0)
    assert result[:success]
    data = result[:data]
    assert_equal member.first_name, data[:first_name]
    assert_equal member.id, data[:uuid]
    assert_equal member.state, data[:status]
    assert_equal member.email, data[:email]
    assert_equal member.last_name, data[:last_name]
    assert_equal member.users.count, data[:programs].count
    assert_nil data["profile"]
  end

  def test_find_success_with_profile
    member = members(:f_mentor)
    result = @presenter.find(member.id, {profile: "1"})
    assert result[:success]
    data = result[:data]
    assert_equal member.first_name, data[:first_name]
    assert_equal member.id, data[:uuid]
    assert_equal member.state, data[:status]
    assert_equal member.email, data[:email]
    assert_equal member.last_name, data[:last_name]
    assert_equal member.users.count, data[:programs].count

    education_question = @organization.profile_questions.where(question_type: ProfileQuestion::Type::EDUCATION).first
    experience_question = @organization.profile_questions.where(question_type: ProfileQuestion::Type::EXPERIENCE).first
    publication_question = @organization.profile_questions.where(question_type: ProfileQuestion::Type::PUBLICATION).first
    manager_question = @organization.profile_questions.where(question_type: ProfileQuestion::Type::MANAGER).first
    file_question = @organization.profile_questions.where(question_type: ProfileQuestion::Type::FILE).first
    other_question = @organization.profile_questions.where(question_type: ProfileQuestion::Type::STRING).first

    education_answer = member.answer_for(education_question)
    experience_answer = member.answer_for(experience_question)
    publication_answer = member.answer_for(publication_question)
    manager_answer = member.answer_for(manager_question)
    file_answer = member.answer_for(file_question)
    other_answer = member.answer_for(other_question)

    profile = data[:profile]
    education_hash = profile[("field_value_" + education_answer.id.to_s).to_sym]
    experience_hash = profile[("field_value_" + experience_answer.id.to_s).to_sym]
    publication_hash = profile[("field_value_" + publication_answer.id.to_s).to_sym]
    manager_hash = profile[("field_value_" + manager_answer.id.to_s).to_sym]
    file_hash = profile[("field_value_" + file_answer.id.to_s).to_sym]
    other_hash = profile[("field_value_" + other_answer.id.to_s).to_sym]

    assert_equal education_hash[:field_id], education_question.id
    assert_equal education_hash[:field_name], education_question.question_text
    value = education_hash[:value]["education_#{education_answer.educations.first.id}".to_sym]
    assert_equal value[:school_name], education_answer.educations.first.school_name
    assert_equal value[:degree], education_answer.educations.first.degree
    assert_equal value[:major], education_answer.educations.first.major
    assert_equal value[:graduation_year], education_answer.educations.first.graduation_year

    assert_equal experience_hash[:field_id], experience_question.id
    assert_equal experience_hash[:field_name], experience_question.question_text
    value = experience_hash[:value]["experience_#{experience_answer.experiences.first.id}".to_sym]
    assert_equal value[:company], experience_answer.experiences.first.company
    assert_equal value[:job_title], experience_answer.experiences.first.job_title
    assert_equal value[:current_job], experience_answer.experiences.first.current_job
    assert_equal value[:start_month], experience_answer.experiences.first.start_month
    assert_equal value[:start_year], experience_answer.experiences.first.start_year
    assert_equal value[:end_month], experience_answer.experiences.first.end_month
    assert_equal value[:end_year], experience_answer.experiences.first.end_year

    assert_equal publication_hash[:field_id], publication_question.id
    assert_equal publication_hash[:field_name], publication_question.question_text
    value = publication_hash[:value]["publication_#{publication_answer.publications.first.id}".to_sym]
    assert_equal value[:title], publication_answer.publications.first.title
    assert_equal value[:publisher], publication_answer.publications.first.publisher
    assert_equal value[:url], publication_answer.publications.first.url
    assert_equal value[:authors], publication_answer.publications.first.authors
    assert_equal value[:description], publication_answer.publications.first.description
    assert_equal value[:publication_day], publication_answer.publications.first.day
    assert_equal value[:publication_month], publication_answer.publications.first.month
    assert_equal value[:publication_year], publication_answer.publications.first.year

    assert_equal manager_hash[:field_id], manager_question.id
    assert_equal manager_hash[:field_name], manager_question.question_text
    value = manager_hash[:value]["manager_#{manager_answer.manager.id}".to_sym]
    assert_equal value[:first_name], manager_answer.manager.first_name
    assert_equal value[:last_name], manager_answer.manager.last_name
    assert_equal value[:email], manager_answer.manager.email

    assert_equal file_hash[:field_id], file_question.id
    assert_equal file_hash[:field_name], file_question.question_text
    assert_equal file_hash[:value], file_answer.attachment_file_name

    assert_equal other_hash[:field_id], other_question.id
    assert_equal other_hash[:field_name], other_question.question_text
    assert_equal other_hash[:value], other_answer.answer_text
  end

  def test_find_success_with_no_profile_answers
    member = members(:f_mentor)
    member.profile_answers.destroy_all
    result = @presenter.find(member, {profile: "1"})
    assert result[:success]
    data = result[:data]
    assert_equal member.first_name, data[:first_name]
    assert_equal member.id, data[:uuid]
    assert_equal member.state, data[:status]
    assert_equal member.email, data[:email]
    assert_equal member.last_name, data[:last_name]
    assert_equal member.users.count, data[:programs].count
    assert_equal ({}), data[:profile]
  end

  def test_find_should_show_appicable_details_for_profile
    member = members(:f_mentor)
    profile_answer_1 = member.profile_answers.first
    profile_answer_2 = member.profile_answers.second
    profile_answer_1.update_attributes(not_applicable: true, answer_text: nil)
    profile_answer_2.update_attribute(:not_applicable, false)

    result = @presenter.find(member.id, {profile: "1"})
    assert result[:success]
    data = result[:data]
    assert_equal member.first_name, data[:first_name]
    assert_equal member.id, data[:uuid]
    assert_equal member.state, data[:status]
    assert_equal member.email, data[:email]
    assert_equal member.last_name, data[:last_name]
    assert_equal member.users.count, data[:programs].count
    assert_equal 0, data[:profile][("field_value_"+profile_answer_1.id.to_s).to_sym][:applicable]
    assert_equal 1, data[:profile][("field_value_"+profile_answer_2.id.to_s).to_sym][:applicable]
  end

  def test_find_should_show_should_show_skype_answer
    member = members(:f_mentor)
    skype_question = member.organization.profile_questions.where(question_type: ProfileQuestion::Type::SKYPE_ID).first
    skype_answer = member.profile_answers.build(profile_question_id: skype_question.id)
    skype_answer.answer_text = "skypeid"
    skype_answer.save!

    assert member.organization.skype_enabled?

    result = @presenter.find(member.id, {profile: "1"})
    assert result[:success]
    data = result[:data]
    assert_equal "skypeid", data[:profile][("field_value_"+skype_answer.id.to_s).to_sym][:value]
  end

  def test_find_should_not_show_should_show_skype_answer
    member = members(:f_mentor)
    skype_question = member.organization.profile_questions.where(question_type: ProfileQuestion::Type::SKYPE_ID).first
    skype_answer = member.profile_answers.build(profile_question_id: skype_question.id)
    skype_answer.answer_text = "skypeid"
    skype_answer.save!
    member.organization.expects(:skype_enabled?).at_least(1).returns(false)
    assert_false member.organization.skype_enabled?
    new_presenter = Api::V2::MembersPresenter.new(nil, member.organization)
    result = new_presenter.find(member.id, {profile: "1"})
    assert result[:success]
    data = result[:data]
    assert_nil data[:profile][("field_value_"+skype_answer.id.to_s).to_sym]
  end

  private

  def get_unique_params(options)
    params = {}
    params[:first_name] = "first_name" if options[:first_name]
    params[:last_name] = "last_name" if options[:last_name]
    params[:email] = "unique_email@chronus.com" if options[:email]
    params[:login_name] = "login_name" if options[:login_name]
    params
  end

  def education_asserts(education_params, education)
    assert_equal education_params["school_name"], education.school_name
    assert_equal education_params["degree"], education.degree
    assert_equal education_params["major"], education.major
    assert_equal education_params["graduation_year"], education.graduation_year
  end

  def manager_asserts(manager_params, manager)
    assert_equal manager_params["first_name"], manager.first_name
    assert_equal manager_params["last_name"], manager.last_name
    assert_equal manager_params["email"], manager.email
  end

  def experience_asserts(experience_params, experience)
    assert_equal experience_params["company"], experience.company
    assert_equal experience_params["job_title"], experience.job_title
    assert_equal experience_params["start_year"], experience.start_year
    assert_equal experience_params["end_year"], experience.end_year
  end

  def publication_asserts(publication_params, publication)
    assert_equal publication_params["title"], publication.title
    assert_equal publication_params["publisher"], publication.publisher
    assert_equal publication_params["url"], publication.url
    assert_equal publication_params["authors"], publication.authors
    assert_equal publication_params["description"], publication.description
    assert_equal publication_params["day"], publication.day
    assert_equal publication_params["month"], publication.month
    assert_equal publication_params["year"], publication.year
  end

  def update_profile_question(question, answer_text, error_array = {})
    member_answer = @mentor.answer_for(question)
    profile_params = { question.id.to_s => answer_text }
    params = { id: @mentor.id, profile: profile_params }
    result = @presenter.update(params)
    if error_array.present?
      assert_false result[:success]
      assert_equal result[:errors], error_array
    else
      assert result[:success]
      member_answer = @mentor.answer_for(question)
      expected_text = member_answer.answer_text
      if question_can_be_updated?(question)
        assert_equal member_answer.answer_text, expected_text
      else
        assert_not_equal member_answer.answer_text, expected_text if member_answer.present?
      end
    end
  end

  def question_can_be_updated?(question)
    !Api::V2::BasicHelper::NOT_UPDATEABLE_QUESTION_TYPE.include?(question.question_type)
  end
end