require_relative './../test_helper.rb'

class ProfileAnswerTest < ActiveSupport::TestCase
  def test_should_not_create_answer_without_user_and_question
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ProfileAnswer.create!
    end

    assert_match("Question can't be blank", e.message)
    assert_match("Ref obj can't be blank", e.message)
  end

  def test_should_create_answer
    assert_difference('ProfileAnswer.count') do
      ProfileAnswer.create!(
        :answer_text => 'hello',
        :profile_question => create_question, :ref_obj => members(:f_student))
    end
  end

  def test_observers_reindex_es
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, users(:f_student, :f_student_nwen_mentor, :f_student_pbe).map(&:id)).times(4)
    profile_answer = ProfileAnswer.create!(
      answer_text: 'hello',
      profile_question: create_question, ref_obj: members(:f_student))

    profile_answer.update_attribute(:answer_text, "World")
    profile_answer.update_attribute(:location_id, Location.first.id)
    profile_answer.destroy
  end

  def test_for_question_scope
    q1 = create_question
    q2 = create_question
    a1 = ProfileAnswer.create!(:answer_text => 'hello', :profile_question => q1, :ref_obj => members(:f_student))
    a2 = ProfileAnswer.create!(:answer_text => 'hello', :profile_question => q1, :ref_obj => members(:f_mentor))
    assert_equal [a1, a2], ProfileAnswer.for_question(q1).all
    assert ProfileAnswer.for_question(q2).empty?
  end

  def test_not_applicable_scope
    q1 = create_question
    q2 = create_question
    a1 = ProfileAnswer.create!(:profile_question => q1, :ref_obj => members(:f_student), :not_applicable => true)
    a2 = ProfileAnswer.create!(:answer_text => 'hello', :profile_question => q1, :ref_obj => members(:f_mentor))
    assert_equal [a1], ProfileAnswer.not_applicable.all
  end

  def test_should_assign_to_answer
    q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A","B","C","D"])
    a = ProfileAnswer.new(:profile_question => q)
    a.answer_value = ["B"]
    assert_equal("B", a.answer_value)

    a1 = ProfileAnswer.new(:profile_question => q)
    a1.answer_value = {answer_text: "B, C", question: q, from_import: true}
    assert_equal("B", a.answer_value)

    q.update_attributes!(allow_other_option: true)
    a = ProfileAnswer.new(:profile_question => q)
    a.answer_value = ["B, C"]
    assert_equal("B, C", a.answer_value)

    a = ProfileAnswer.new(:profile_question => q)
    a.answer_value = ["Other"]
    assert_equal("Other", a.answer_value)

    q = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["A","B","C","D"])
    a = ProfileAnswer.new(:profile_question => q)
    a.answer_value = ["B", "C"]
    assert_equal(["B", "C"], a.answer_value)

    a1 = ProfileAnswer.new(:profile_question => q)
    a1.answer_value = {answer_text: "B, C", question: q, from_import: true}
    assert_equal(["B", "C"], a.answer_value)

    q.update_attributes!(allow_other_option: true)
    a = ProfileAnswer.new(:profile_question => q)
    a.answer_value = ["B", "C", "Other"]
    assert_equal(["B", "C", "Other"], a.answer_value)

    b = ProfileAnswer.new(:profile_question => create_question)
    b.answer_value = "Abcdef"
    assert_equal("Abcdef", b.answer_value)

    file_ans = ProfileAnswer.new(:profile_question => create_question(:question_type => ProfileQuestion::Type::FILE))
    file_ans.answer_value = fixture_file_upload(File.join('files', 'some_file.txt'))
    assert file_ans.attachment?
    assert_equal("some_file.txt", file_ans.attachment_file_name)
    assert_equal file_ans.attachment, file_ans.answer_value

    multi_line_ans = ProfileAnswer.new(:profile_question => create_question(:question_type => ProfileQuestion::Type::MULTI_STRING))
    multi_line_ans.answer_value = ["I am ", "very good", " boy ", "        "]
    assert_equal("I am\n very good\n boy" , multi_line_ans.answer_text)

    multi_edu_q = profile_questions(:multi_education_q)
    multi_edu_ans = users(:f_mentor).answer_for(multi_edu_q) || members(:f_mentor).profile_answers.build( :profile_question => multi_edu_q)
    multi_edu_ans.answer_value = [create_education(users(:f_mentor), multi_edu_q), create_education(users(:f_mentor), multi_edu_q)]
    assert_equal("SSV, BTech, IT\n SSV, BTech, IT" , multi_edu_ans.answer_text)

    multi_exp_q = profile_questions(:multi_experience_q)
    multi_exp_ans = users(:f_mentor).answer_for(multi_exp_q) || members(:f_mentor).profile_answers.build( :profile_question => multi_exp_q)
    multi_exp_ans.answer_value = [create_experience(users(:f_mentor), multi_exp_q), create_experience(users(:f_mentor), multi_exp_q)]
    assert_equal("SDE, MSFT\n SDE, MSFT" , multi_exp_ans.answer_text)

    multi_pub_q = profile_questions(:multi_publication_q)
    multi_pub_ans = users(:f_mentor).answer_for(multi_pub_q) || members(:f_mentor).profile_answers.build( :profile_question => multi_pub_q)
    multi_pub_ans.answer_value = [create_publication(users(:f_mentor), multi_pub_q), create_publication(users(:f_mentor), multi_pub_q)]
    assert_equal("Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication" , multi_pub_ans.answer_text)

    manager_q = profile_questions(:manager_q)
    manager_ans = users(:f_mentor).answer_for(manager_q) || members(:f_mentor).profile_answers.build( :profile_question => manager_q)
    manager_ans.answer_value = create_manager(users(:f_mentor), manager_q).full_data
    assert_equal("Manager Name, manager@example.com" , manager_ans.answer_text)

    o = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_choices => ["A","B","C","D"], options_count: 2)
    ans = ProfileAnswer.new(:profile_question => o, ref_obj: members(:f_student))
    ans.answer_value = {answer_text: ["B", "C"], question: o}
    ans.save!
    assert_equal(["B", "C"], ans.answer_value)
    ans.answer_value = {answer_text: "B,C", question: o, from_import: true}
    ans.save!
    assert_equal(["B", "C"], ans.answer_value)
    o.update_attributes!(allow_other_option: true, options_count: 3)
    ans.answer_value = {answer_text: ["B", "Other", "C"], question: o}
    ans.save!
    assert_equal(["B", "Other", "C"], ans.answer_value)
    ans.answer_value = {answer_text: "B,Other2,C", question: o, from_import: true}
    ans.save!
    assert_equal(["B", "Other2", "C"], ans.reload.answer_value)
  end

  def test_should_mark_as_applicable_if_answered
    member = members(:f_student)
    q = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, question_choices: ["A","B","C","D"])
    a = ProfileAnswer.create!(:profile_question => q, :ref_obj => member, :not_applicable => true)
    assert_blank a.answer_value
    assert a.not_applicable
    a.answer_value = ["B", "C"]
    a.save!
    assert_equal(["B", "C"], a.reload.answer_value)
    assert_false a.not_applicable

    file_ans = ProfileAnswer.new(:profile_question => create_question(:question_type => ProfileQuestion::Type::FILE), :ref_obj => member, :not_applicable => true)
    assert file_ans.not_applicable
    assert_blank file_ans.attachment_file_name
    file_ans.answer_value = fixture_file_upload(File.join('files', 'some_file.txt'))
    file_ans.save!
    assert file_ans.attachment?
    assert_equal("some_file.txt", file_ans.attachment_file_name)
    assert_equal file_ans.attachment, file_ans.answer_value
    assert_false file_ans.not_applicable

    multi_line_ans = ProfileAnswer.new(:profile_question => create_question(:question_type => ProfileQuestion::Type::MULTI_STRING), :ref_obj => member, :not_applicable => true)
    assert_blank multi_line_ans.answer_text
    assert multi_line_ans.not_applicable
    multi_line_ans.answer_value = ["I am ", "very good", " boy ", "        "]
    multi_line_ans.save!
    assert_equal("I am\n very good\n boy" , multi_line_ans.answer_text)
    assert_false multi_line_ans.not_applicable

    multi_edu_q = profile_questions(:multi_education_q)
    multi_edu_ans = member.profile_answers.create!(:profile_question => multi_edu_q, :not_applicable => true)
    assert_blank multi_edu_ans.answer_text
    assert multi_edu_ans.not_applicable
    multi_edu_ans.answer_value = [create_education(member, multi_edu_q), create_education(member, multi_edu_q)]
    multi_edu_ans.save!
    multi_edu_ans.reload
    assert_equal("SSV, BTech, IT\n SSV, BTech, IT" , multi_edu_ans.answer_text)
    assert_false multi_edu_ans.not_applicable

    multi_exp_q = profile_questions(:multi_experience_q)
    multi_exp_ans = member.profile_answers.create!(:profile_question => multi_exp_q, :not_applicable => true)
    assert_blank multi_exp_ans.answer_text
    assert multi_exp_ans.not_applicable
    multi_exp_ans.answer_value = [create_experience(member, multi_exp_q), create_experience(member, multi_exp_q)]
    multi_exp_ans.save!
    multi_exp_ans.reload
    assert_equal("SDE, MSFT\n SDE, MSFT" , multi_exp_ans.answer_text)
    assert_false multi_exp_ans.not_applicable

    multi_pub_q = profile_questions(:multi_publication_q)
    multi_pub_ans = member.profile_answers.create!(:profile_question => multi_pub_q, :not_applicable => true)
    assert_blank multi_pub_ans.answer_text
    assert multi_pub_ans.not_applicable
    multi_pub_ans.answer_value = [create_publication(member, multi_pub_q), create_publication(member, multi_pub_q)]
    multi_pub_ans.save!
    multi_pub_ans.reload
    assert_equal("Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication" , multi_pub_ans.answer_text)
    assert_false multi_pub_ans.not_applicable

    manager_q = profile_questions(:manager_q)
    manager_ans = member.profile_answers.create!(:profile_question => manager_q, :not_applicable => true)
    assert_blank manager_ans.answer_text
    assert manager_ans.not_applicable
    manager_ans.answer_value = create_manager(member, manager_q).full_data
    manager_ans.save!
    assert_equal("Manager Name, manager@example.com" , manager_ans.answer_text)
    assert_false manager_ans.not_applicable

    o = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 2, question_choices: ["A","B","C","D"])
    ans = ProfileAnswer.create!(:profile_question => o, :ref_obj => member, :not_applicable => true)
    assert_blank ans.answer_value
    assert ans.not_applicable
    ans.answer_value = {answer_text: {0 => "B", 1 => "C"}, question: o}
    ans.save!
    assert_equal(["B", "C"], ans.answer_value)
    assert_false ans.not_applicable
  end

  def test_should_not_assign_to_answer_if_not_applicable
    q = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, question_choices: ["A","B","C","D"])
    a = ProfileAnswer.new(:profile_question => q, :not_applicable => true)
    assert_blank a.answer_value
  end

  def test_should_assign_to_answer_with_special_characters_in_file_name
    file_ans = ProfileAnswer.new(:profile_question => create_question(:question_type => ProfileQuestion::Type::FILE))
    file_ans.answer_value = fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'))
    assert_equal("SOMEspecialcharacters123_test.txt", file_ans.attachment_file_name)
  end

  def test_answer_should_be_a_split_up_of_answer_text
    member = members(:f_student)
    q = create_question(:question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["A","B","C","D", "X,Y,Z", "'L,M,N'"])

    a = ProfileAnswer.new(:profile_question => q, ref_obj: member)
    a.answer_value = {answer_text: "B, C", from_import: true, question: q }
    a.save!
    assert_equal(["B", "C"], a.answer_value)
    a.answer_value = {answer_text: "'X,Y,Z'", from_import: true, question: q }
    a.save!
    assert_equal(["X,Y,Z"], a.answer_value)
    a.answer_value = {answer_text: "'\'L,M,N\''", from_import: true, question: q }
    a.save!
    assert_equal(["'L,M,N'"], a.answer_value)
    a.answer_value = nil
    a.save!
    assert_equal([], a.answer_value)
  end

  def test_answer_should_be_a_split_up_of_answer_text_multi_line
    q = create_question(:question_type => ProfileQuestion::Type::MULTI_STRING)
    a = ProfileAnswer.new(:profile_question => q)
    a.answer_text = "B\n C"
    assert_equal(["B", "C"], a.answer_value)
    a.answer_text = nil
    assert_equal([], a.answer_value)
  end

  def test_answer_should_be_answer_text_for_non_multichoice_type_questions
    q = create_question
    a = ProfileAnswer.new(:profile_question => q, :answer_text => 'quit123')
    assert_equal('quit123', a.answer_value)
  end

  def test_should_not_save_an_answer_with_an_invalid_answer_for_single_choice_question
    q = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::SINGLE_CHOICE)
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, 'contains an invalid choice') do
      ProfileAnswer.create!(:profile_question => q, :ref_obj => members(:f_student), :answer_value => "Zellow")
    end

    # Do not save empty answer.
    assert_nothing_raised do
      assert_no_difference 'ProfileAnswer.count' do
        ProfileAnswer.create!(:profile_question => q, :ref_obj => members(:f_student), :answer_value => "")
      end
    end
  end

  def test_should_not_save_an_answer_with_an_invalid_answer_for_multi_choice_or_ordered_options_question
    multi_choice_question = create_question(question_choices: ["A","B","C"], question_type: ProfileQuestion::Type::MULTI_CHOICE)
    # Do not save empty answer.
    assert_nothing_raised do
      assert_no_difference 'ProfileAnswer.count' do
        multi_choice_question.profile_answers.create!(ref_obj: members(:f_student), answer_value: {answer_text: "", question: multi_choice_question})
      end
    end

    # Answer with few choices correct and few wrong.
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, 'contains an invalid choice') do
      multi_choice_question.profile_answers.create!(ref_obj: members(:f_student), answer_value: {answer_text: ["B", "hello"], question: multi_choice_question})
    end

    ordered_options_question = create_question(question_choices: ["A","B","C"], question_type: ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 1)
    # Do not save empty answer.
    assert_nothing_raised do
      assert_no_difference 'ProfileAnswer.count' do
        ordered_options_question.profile_answers.create!(ref_obj: members(:f_student), answer_value: {answer_text: "",  question: ordered_options_question})
      end
    end

    # Answer with few choices correct and few wrong.
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, 'contains an invalid choice') do
      ordered_options_question.profile_answers.create!(ref_obj: members(:f_student), answer_value: {answer_text: ["B", "hello"],  question: ordered_options_question})
    end
  end

  def test_destroy
    profile_answer = profile_answers(:multi_choice_ans_1)
    answer_choices_count = profile_answer.answer_choices.size
    assert answer_choices_count > 1
    assert_difference "ProfileAnswer.count", -1 do
      assert_difference "AnswerChoice.count", -1*answer_choices_count do
        profile_answer.destroy
      end
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      profile_answer.reload
    end
    profile_answer = profile_answers(:single_choice_ans_1)
    answer_choices_count = profile_answer.answer_choices.size
    assert answer_choices_count == 1
    assert_difference "ProfileAnswer.count", -1 do
      assert_difference "AnswerChoice.count", -1 do
        profile_answer.destroy
      end
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      profile_answer.reload
    end
  end

  def test_check_text_only_answer
    q = create_question(:question_type => ProfileQuestion::Type::STRING, :text_only_option => true)
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, 'cannot contain digits') do
      ProfileAnswer.create!(:profile_question => q, :ref_obj => members(:f_student), :answer_text => 'quit123')
    end

    assert_difference 'ProfileAnswer.count', 1 do
      ProfileAnswer.create!(:profile_question => q, :ref_obj => members(:f_student), :answer_text => "quit")
    end
  end

  def test_check_date_must_be_valid
    question = profile_questions(:date_question)
    error = assert_raises(ActiveRecord::RecordInvalid) do
      ProfileAnswer.create!(profile_question: question, ref_obj: members(:f_student), answer_text: 'what are you doing')
    end
    assert_equal "Validation failed: One or more of your date answers is invalid", error.message

    assert_difference 'ProfileAnswer.count', 1 do
      ProfileAnswer.create!(profile_question: question, ref_obj: members(:f_student), answer_text: '04/12/12')  
    end
  end

  def test_handle_date_answer
    date_question = profile_questions(:date_question)
    string_question = profile_questions(:string_q)
    member = members(:f_student)

    profile_answer = ProfileAnswer.new(profile_question: string_question, ref_obj: member, answer_text: "")
    profile_answer.expects(:valid_date).times(0)
    profile_answer.save_answer!(string_question, profile_answer.answer_text)

    assert_difference ['ProfileAnswer.count', 'DateAnswer.count'], 1 do
      profile_answer = ProfileAnswer.new(profile_question: date_question, ref_obj: member, answer_text: "01/01/2017")
      profile_answer.save_answer!(date_question, profile_answer.answer_text)
      assert_equal "January 01, 2017", profile_answer.reload.answer_text
      assert_equal Date.parse("01/01/2017"), profile_answer.date_answer.answer
    end

    assert_no_difference ['ProfileAnswer.count', 'DateAnswer.count'] do
      profile_answer.answer_text = "29/05/1996"
      profile_answer.save_answer!(date_question, profile_answer.answer_text)
      assert_equal "May 29, 1996", profile_answer.reload.answer_text
      assert_equal Date.parse("29/05/1996"), profile_answer.date_answer.answer
    end

    assert_no_difference ['ProfileAnswer.count', 'DateAnswer.count'] do
      assert_raise ActiveRecord::RecordInvalid do
        profile_answer = ProfileAnswer.new(profile_question: date_question, ref_obj: members(:f_admin), answer_text: "01/31/2017")
        profile_answer.save_answer!(date_question, profile_answer.answer_text)
      end
    end
  end

  def test_should_not_save_if_answer_is_blank_in_case_required_question
    member = members(:student_8)
    question = create_question(question_choices: ["A","B","C"], required: 1)
    user = member.user_in_program(programs(:albers))

    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
      answer = question.profile_answers.new(profile_question: question, ref_obj: member, answer_value: "")
      answer.user_or_membership_request = user
      assert answer.send(:required_question?)
      answer.save!
    end
  end

  def test_should_not_destroy_answer_for_optional_question_if_not_applicable
    q = create_question(:question_choices => ["A","B","C"])
    user = members(:f_student).user_in_program(programs(:albers))
    answer = ProfileAnswer.create!(:profile_question => q, :ref_obj => members(:f_student), :answer_value => "", :not_applicable => true)
    assert_no_difference 'ProfileAnswer.count' do
      answer.answer_value = ""
      answer.save!
    end
  end

  def test_destroy_answer_for_optional_question_if_update_with_empty
    optional_single_q = create_question(
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A","B","C"])
    optional_multiple_q = create_question(
      :question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["A","B","C"])
    optional_string_q = create_question(:question_type => ProfileQuestion::Type::STRING)
    optional_file_q = create_question(:question_type => ProfileQuestion::Type::FILE)
    required_single_q = create_question(
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_choices => ["A","B","C"], :required => 1)
    required_multiple_q = create_question(
      :question_type => ProfileQuestion::Type::MULTI_CHOICE, :question_choices => ["A","B","C"], :required => 1)
    required_string_q = create_question(:question_type => ProfileQuestion::Type::STRING, :required => 1)
    required_file_q = create_question(:question_type => ProfileQuestion::Type::FILE, :required => 1)
    assert_difference 'ProfileAnswer.count', 8 do
      @ans_1 = ProfileAnswer.create!(:profile_question => optional_single_q, :ref_obj => members(:f_student), :answer_value => "A")
      @ans_2 = ProfileAnswer.create!(:profile_question => optional_multiple_q, :ref_obj => members(:f_student), :answer_value => "A")
      @ans_3 = ProfileAnswer.create!(:profile_question => optional_string_q, :ref_obj => members(:f_student), :answer_text => "A")
      @ans_4 = ProfileAnswer.create!(:profile_question => optional_file_q, :ref_obj => members(:f_student), :attachment => fixture_file_upload(File.join('files', 'some_file.txt')))
      @req_ans_1 = ProfileAnswer.create!(:profile_question => required_single_q, :ref_obj => members(:f_student), :answer_value => "A")
      @req_ans_2 = ProfileAnswer.create!(:profile_question => required_multiple_q, :ref_obj => members(:f_student), :answer_value => "A")
      @req_ans_3 = ProfileAnswer.create!(:profile_question => required_string_q, :ref_obj => members(:f_student), :answer_text => "A")
      @req_ans_4 = ProfileAnswer.create!(:profile_question => required_file_q, :ref_obj => members(:f_student), :attachment => fixture_file_upload(File.join('files', 'some_file.txt')))
    end
    user = members(:f_student).user_in_program(programs(:albers))
    assert_difference 'ProfileAnswer.count', -4 do
      @ans_1.answer_value = ""
      @ans_1.save!
      @ans_2.answer_value = [""]
      @ans_2.save!
      @ans_3.answer_value = ""
      @ans_3.save!
      @ans_4.answer_value = nil
      @ans_4.save!
    end

    assert_no_difference 'ProfileAnswer.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
        @req_ans_1.answer_value = ""
        @req_ans_1.user_or_membership_request = user
        @req_ans_1.save!
      end

      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
        @req_ans_2.answer_value = [""]
        @req_ans_2.user_or_membership_request = user
        @req_ans_2.save!
      end

      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
        @req_ans_3.answer_value = ""
        @req_ans_3.user_or_membership_request = user
        @req_ans_3.save!
      end

      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :attachment, "can't be blank") do
        @req_ans_4.answer_value = nil
        @req_ans_4.user_or_membership_request = user
        @req_ans_4.save!
      end
    end
  end

  def test_answer_unanswered
    ans = ProfileAnswer.create!(:profile_question => create_question, :ref_obj => members(:f_student))
    assert ans.unanswered?

    ans2 = ProfileAnswer.create!(:profile_question => create_question, :ref_obj => members(:f_student), :answer_text => "alsjdad")
    assert !ans2.unanswered?

    file_ans1 = ProfileAnswer.create!(
      :profile_question => create_question(:question_type => ProfileQuestion::Type::FILE),
      :ref_obj => members(:f_student))
    assert file_ans1.unanswered?

    file_ans2 = ProfileAnswer.create!(
      :profile_question => create_question(:question_type => ProfileQuestion::Type::FILE),
      :ref_obj => members(:f_student),
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt')))
    assert !file_ans2.unanswered?
  end

  def test_should_not_save_blank_answers_for_multiple_choice_questions
    q = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::MULTI_CHOICE)
    a = ProfileAnswer.new(:profile_question => q, :ref_obj => members(:f_student))
    a.answer_value = ["A", "B", ""]
    a.save!
    assert_equal(["A", "B"], a.reload.answer_value)
  end

  def test_answered
    ProfileAnswer.destroy_all
    ProfileAnswer.create!(:profile_question => create_question, :ref_obj => members(:f_student))
    ProfileAnswer.create!(:profile_question => create_question, :ref_obj => members(:f_student), :answer_text => '')
    ans2 = ProfileAnswer.create!(:profile_question => create_question, :ref_obj => members(:f_student), :answer_text => "alsjdad")
    ProfileAnswer.create!(
      :profile_question => create_question(:question_type => ProfileQuestion::Type::FILE),
      :ref_obj => members(:f_student))

    file_ans2 = ProfileAnswer.create!(
      :profile_question => create_question(:question_type => ProfileQuestion::Type::FILE),
      :ref_obj => members(:f_student),
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt')))
    assert_equal [ans2, file_ans2], ProfileAnswer.answered
  end

  def test_should_not_create_answer_if_file_size_gt_20mb
    file_question = create_question(:question_type => ProfileQuestion::Type::FILE)
    assert_no_difference("ProfileAnswer.count") do
      answer = file_question.profile_answers.new(
        :ref_obj => members(:f_student), :attachment_file_name => 'temp.txt',
        :attachment_file_size => 21.megabytes)
      answer.save
      assert_equal ["should be within 20 MB"], answer.errors.messages[:attachment_file_size]
    end
  end

  def test_should_not_create_answer_if_content_type_unsupported
    file_question = create_question(:question_type => ProfileQuestion::Type::FILE)
    assert_no_difference("ProfileAnswer.count") do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :attachment) do
        file_question.profile_answers.create!(
          :ref_obj => members(:f_student), :attachment_file_name => 'test_php.php',
          :attachment_content_type => 'application/x-php',
          :attachment_file_size => 1.megabytes)
      end
    end
  end

  def test_should_create_answer_with_file
    file_question = create_question(:question_type => ProfileQuestion::Type::FILE)
    assert_difference("ProfileAnswer.count") do
      file_question.profile_answers.create!(
        :ref_obj => members(:f_student), :attachment_file_name => 'temp.txt',
        :attachment_file_size => 1.megabytes)
    end
  end

  def test_answer_text_not_required_if_file_type
    member = members(:f_student)
    file_question = create_question(question_type: ProfileQuestion::Type::FILE, required: true)
    user = member.user_in_program(programs(:albers))

    assert_no_difference "ProfileAnswer.count" do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :attachment do
        answer = file_question.profile_answers.new(ref_obj: member, answer_text: "test_pic.png")
        answer.user_or_membership_request = user
        answer.save!
      end
    end

    assert_difference "ProfileAnswer.count", 1 do
      assert_nothing_raised do
        answer = file_question.profile_answers.new(ref_obj: member, attachment: fixture_file_upload(File.join('files', 'test_pic.png')))
        answer.user_or_membership_request = user
        answer.save!
      end
    end
  end

  def test_single_choice_answer_should_successfully_compact_answer_on_changing_question_type_to_multi_choice
    q = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::SINGLE_CHOICE)
    a = ProfileAnswer.new(:profile_question => q, :ref_obj => members(:f_student))
    a.answer_value = "A"
    a.save!
    assert_equal("A", a.answer_value)

    q.question_type = ProfileQuestion::Type::MULTI_CHOICE
    q.save!
    assert_equal(["A"], a.reload.answer_value)
  end

  def test_single_choice_answer_compacting
    q = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::SINGLE_CHOICE)
    a = ProfileAnswer.new(:profile_question => q, :ref_obj => members(:f_student))
    a.answer_value = "A"; a.save!
    assert_equal("A", a.reload.answer_value)

    # By adding a choice, the existing answer should not change
    assert_difference("ProfileAnswer.count", 0) do
      q.question_choices.create!(text: "z")
    end
    assert_equal("A", a.reload.answer_value)

    # When removing a choice, the existing answer should be deleted
    assert_difference("ProfileAnswer.count", -1) do
      assert_difference("AnswerChoice.count", -1) do
        q.question_choices.find_by(text: "A").destroy
        q.question_choices.create!(text: "D")
      end
    end
  end

  def test_multi_choice_answer_compacting
    q = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::MULTI_CHOICE)
    a = ProfileAnswer.new(:profile_question => q, :ref_obj => members(:f_student))
    a.answer_value = ["A", "B"]; a.save!
    assert_equal(["A", "B"], a.reload.answer_value)
    current_time = Time.now
    Timecop.freeze(current_time + 12.seconds) do
      # By adding a choice, the existing answer should not change
      assert_difference("ProfileAnswer.count", 0) do
        "Z,Y".split(",") do |text|
          q.question_choices.create!(text: text)
        end
        q.save!
      end
      assert_equal(["A", "B"], a.reload.answer_value)
    end

    Timecop.freeze(current_time + 12.seconds) do
      # When removing a choice, the existing answer choice should be deleted
      assert_difference("ProfileAnswer.count", 0) do
        assert_difference("AnswerChoice.count", -1) do
          q.question_choices.find_by(text: "A").destroy
          q.question_choices.create!(text: "D")
        end
      end
      assert_equal(["B"], a.reload.answer_value)
    end

    # When removing all answer choices, the existing answer should be deleted
    assert_difference("ProfileAnswer.count", -1) do
      assert_difference("AnswerChoice.count", -1) do
        q.question_choices.destroy_all
        "L,M,N".split(",") do |text|
          q.question_choices.create!(text: text)
        end
      end
    end
  end

  def test_answer_choices_to_a
    q = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::MULTI_CHOICE, :allow_other_option => true)
    a = ProfileAnswer.new(:profile_question => q, :ref_obj => members(:f_student))
    assert_equal ["A", "B", "c,F,G", "H,K"], a.choices_to_a(["A", "B", "c,F,G", "H,K", " "])
    assert_equal ["A", "B", "c,F,G", "H,K"], a.choices_to_a("A, B, 'c,F,G', 'H,K',  ", q, true)
    assert_equal ["A", "B'C", "'C,F,G'", "'H,K'"], a.choices_to_a("A, B'C, '\'C,F,G\'', '\'H,K\''", q, true)
    assert_equal ["A", "B", "c,F,G", "H,K"], a.choices_to_a([["A", "B", "c,F,G", "H,K", " "]])
    assert_equal ["A", "B"], a.choices_to_a({"0" => 'A', "1" => "B", "2" => " "})
    a = profile_answers(:single_choice_ans_1)
    assert_equal ["c,F,G"], a.choices_to_a("c,F,G", a.profile_question, true)
  end

  def test_selected_choices_to_str
    question = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::MULTI_CHOICE, :allow_other_option => true)
    a = ProfileAnswer.new(:profile_question => question, :ref_obj => members(:f_student))
    a.answer_value = ["A", "B"]
    assert_equal "A, B", a.selected_choices_to_str

    question = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 3)
    a = ProfileAnswer.new(:profile_question => question, :ref_obj => members(:f_student))
    a.answer_value = ["A", "B"]
    assert_equal "A, B", a.selected_choices_to_str

    question = create_question(:question_choices => ["A","B","C"], :question_type => ProfileQuestion::Type::MULTI_CHOICE, :allow_other_option => true)
    a = ProfileAnswer.new(:profile_question => question, :ref_obj => members(:f_student))
    a.answer_value = ["A", "B"]
    a.save!
    assert_equal "A, B", a.selected_choices_to_str

    run_in_another_locale(:"fr-CA") do
      question.question_choices.first.update_attributes!(text: "FA")
      question.question_choices.second.update_attributes!(text: "FB")
      question.question_choices.last.update_attributes!(text: "FC")
      assert_equal "FA, FB", a.selected_choices_to_str
    end
  end

  def test_selected_choices
    pa = profile_answers(:multi_choice_ans_1)
    assert_equal ["Stand", "Run"], pa.selected_choices
    assert_equal ["Stand", "Run"], pa.selected_choices(pa.profile_question, default_choices: true)
    assert_equal [], pa.selected_choices(pa.profile_question, other_choices: true)
    assert_equal question_choices(:multi_choice_q_1, :multi_choice_q_3), pa.selected_choices(pa.profile_question, collect_records: true)

    o = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_choices => ["A","B","C","D"], options_count: 4, allow_other_option: true)
    opa = ProfileAnswer.new(:profile_question => o, ref_obj: members(:f_student))
    opa.answer_value = {answer_text: ["B", "C", "B", "Other"], question: o}
    opa.save!
    assert_equal ["B", "C", "B", "Other"], opa.selected_choices
    assert_equal ["B", "C", "B"], opa.selected_choices(opa.profile_question, default_choices: true)
    assert_equal ["Other"], opa.selected_choices(opa.profile_question, other_choices: true)
  end

  def test_answer_value_setter_for_choice_based
    pa = profile_answers(:multi_choice_ans_1)
    assert_difference "AnswerChoice.count", 1 do
      pa.answer_value = ["Stand", "Walk", "Run"]
      pa.save!
    end
    assert_equal ["Stand", "Walk", "Run"], pa.answer_value

    assert_difference "ProfileAnswer.count", -1 do
      assert_difference "AnswerChoice.count", -3 do
        pa.answer_value = nil
        pa.save!
      end
    end
    assert_equal [], pa.answer_value
  end

  def test_answer_value_mappings_should_work_if_initial_assignment_is_of_foreign_language
    answer = ProfileAnswer.new(:profile_question => profile_questions(:student_multi_choice_q), :ref_obj => members(:f_student))

    run_in_another_locale(:"fr-CA") do
      answer.answer_value = ["Supporter", "Course"]
      answer.save!
      assert_equal ["Supporter", "Course"], answer.answer_value
    end
    assert_equal ["Stand", "Run"], answer.answer_value
  end

  def test_answer_value_mappings_should_work_if_initial_assignment_is_of_english
    answer = ProfileAnswer.new(:profile_question => profile_questions(:student_multi_choice_q), :ref_obj => members(:f_student))
    answer.answer_value = [["Stand", "Run"]]
    answer.save!

    assert_equal ["Stand", "Run"], answer.answer_value
    run_in_another_locale(:"fr-CA") do
      assert_equal ["Supporter", "Course"], answer.answer_value
    end
  end

  def test_answer_value_should_work_as_expected_for_missing_translations
    question = profile_questions(:student_multi_choice_q)
    run_in_another_locale(:'fr-CA') do
      question.question_choices.first.update_attributes!(text: "Supporter")
      question.question_choices.second.translation.destroy
      question.question_choices.last.update_attributes!(text: "Course")
    end

    # Answer in english
    answer = ProfileAnswer.new(:profile_question => question, :ref_obj => members(:f_student))
    answer.answer_value = ["Walk", "Run"]
    answer.save!
    assert_equal ["Walk", "Run"], answer.answer_value
    run_in_another_locale(:'fr-CA') do
      assert_equal ["Walk", "Course"], answer.answer_value
    end
    answer.destroy

    # Answer in French
    answer = ProfileAnswer.new(:profile_question => question, :ref_obj => members(:f_student))
    answer.answer_value = ["Stand", "Walk"]
    answer.save!
    run_in_another_locale(:'fr-CA') do
      assert_equal ["Supporter", "Walk"], answer.answer_value
    end
    answer.destroy
  end

  def test_copy_from
    q1 = create_common_question
    q2 = create_question

    a1 = CommonAnswer.create!(:answer_text => 'hello', :common_question => q1, :user => users(:f_student))
    a2 = ProfileAnswer.new(:profile_question => q2, :ref_obj => members(:f_mentor_student))

    assert_difference "ProfileAnswer.count" do
      a2.copy_answer_from!(a1)
    end

    assert_equal "hello", a2.answer_text
    assert_equal members(:f_mentor_student), a2.ref_obj
  end

  def test_copy_from_attachement
    q1 = create_common_question(:question_type => ProfileQuestion::Type::FILE)
    q2 = create_question(:question_type => ProfileQuestion::Type::FILE)

    a1 = CommonAnswer.create!(:answer_text => 'hello', :common_question => q1, :user => users(:f_student), :answer_value => fixture_file_upload(File.join('files', 'some_file.txt')))
    a2 = ProfileAnswer.new(:profile_question => q2, :ref_obj => members(:f_mentor_student))

    assert_difference "ProfileAnswer.count" do
      a2.copy_answer_from!(a1)
    end

    assert a2.attachment?
    assert_equal members(:f_mentor_student), a2.ref_obj
  end

  def test_required_question_with_user
    member = members(:f_mentor)
    program_1 = programs(:albers)
    program_2 = programs(:nwen)
    user_1  = member.user_in_program program_1
    user_2 = member.user_in_program program_2
    assert_equal [RoleConstants::MENTOR_NAME], user_1.role_names
    assert_equal [RoleConstants::STUDENT_NAME], user_2.role_names

    profile_question = member.organization.profile_questions.where(question_text: "About Me").first
    program_1_role_question = profile_question.role_questions.where(role_id: program_1.find_role(RoleConstants::MENTOR_NAME).id).first
    program_1_role_question.required = true
    program_1_role_question.save!
    program_2_role_question = profile_question.role_questions.where(role_id: program_2.find_role(RoleConstants::STUDENT_NAME).id).first
    program_2_role_question.required = false
    program_2_role_question.save!

    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
      answer = member.profile_answers.new(profile_question: profile_question)
      answer.user_or_membership_request = user_1
      assert answer.send(:required_question?)
      answer.save!
    end

    assert_nothing_raised do
      answer = member.profile_answers.new(profile_question: profile_question)
      answer.user_or_membership_request = user_2
      assert_false answer.send(:required_question?)
      answer.save!
    end
  end

  def test_required_question_with_membership_request
    organization = programs(:org_primary)
    program = programs(:albers)
    member = members(:f_mentor)

    profile_question = organization.profile_questions.where(question_text: "About Me").first
    role_question = profile_question.role_questions.where(role_id: program.find_role(RoleConstants::MENTOR_NAME).id).first
    role_question.required = true
    role_question.save!

    membership_request = program.membership_requests.new
    membership_request.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
      answer = member.profile_answers.new(profile_question: profile_question)
      answer.user_or_membership_request = membership_request
      assert answer.send(:required_question?)
      answer.save!
    end

    membership_request.role_names = [RoleConstants::STUDENT_NAME]
    assert_nothing_raised do
      answer = member.profile_answers.new(profile_question: profile_question)
      answer.user_or_membership_request = membership_request
      assert_false answer.send(:required_question?)
      answer.save!
    end

    membership_request.role_names = [RoleConstants::MENTOR_NAME]
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :answer_text, "can't be blank") do
      answer = member.profile_answers.new(profile_question: profile_question)
      answer.user_or_membership_request = membership_request
      assert answer.send(:required_question?)
      answer.save!
    end

    role_question.required = false
    role_question.save!
    assert_nothing_raised do
      answer = member.profile_answers.new(profile_question: profile_question)
      answer.user_or_membership_request = membership_request
      assert_false answer.send(:required_question?)
      answer.save!
    end
  end

  def test_belongs_only_to_member
    membership_question = create_membership_profile_question
    request = create_membership_request
    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :ref_obj_type, "is not included in the list") do
      ProfileAnswer.create!(
        :profile_question => membership_question,
        :answer_text => 'hello',
        :ref_obj => request)
    end
  end

  def test_save_answer_should_success
    user = users(:f_student)
    question = profile_questions(:single_choice_q)
    profile_answer = user.member.answer_for(question) || user.member.profile_answers.build(profile_question: question)
    assert profile_answer.save_answer!(question, "opt_2", user), "expected save_answer to success"
    assert_equal "opt_2", user.answer_for(question).answer_value
  end

  def test_save_answer_should_remove_answer
    user = users(:f_student)
    question = profile_questions(:single_choice_q)
    profile_answer = user.member.answer_for(question) || user.member.profile_answers.build(profile_question: question)
    assert_raise ActiveRecord::RecordInvalid do
      assert !profile_answer.save_answer!(question, "aha", user), "expected save_answer to fail"
    end
    assert_nil user.answer_for(question)
  end

  def test_save_answer_should_remove_answer_if_invalid_location
    user = users(:f_mentor)
    question = profile_questions(:profile_questions_3)
    profile_answer = user.member.answer_for(question) || user.member.profile_answers.build(profile_question: question)
    assert_no_difference "Location.count" do
      assert profile_answer.save_answer!(question, "Some Unknown Town", user), "expected save_answer to success"
      assert_nil user.answer_for(question)
    end
  end

  def test_save_answer_should_success_for_existion_location
    user = users(:f_mentor)
    question = profile_questions(:profile_questions_3)
    answer = profile_answers(:location_chennai_ans)
    assert_no_difference "Location.count" do
      assert answer.save_answer!(question, "New Delhi, Delhi, India"), "expected save_answer to success"
      assert_instance_of ProfileAnswer, user.answer_for(question)
      assert_equal "New Delhi, Delhi, India", user.answer_for(question).answer_text
      assert_instance_of Location, user.answer_for(question).location
    end
  end

  def test_save_answer
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    user = users(:mentor_7)
    answer = user.member.profile_answers.build(profile_question: q)

    assert_difference("ProfileAnswer.count") do
      assert answer.save_answer!(q, "Abc")
    end

    ans = ProfileAnswer.last
    assert_equal(q, ans.profile_question)
    assert_equal(user.member, ans.ref_obj)
    assert_equal("Abc", ans.answer_value)

    answer = user.member.profile_answers.build(profile_question: profile_questions(:string_q))
    assert_difference("ProfileAnswer.count") do
      assert answer.save_answer!(profile_questions(:string_q), "Great")
    end

    ans = ProfileAnswer.last
    assert_equal("Great", ans.answer_value)
    assert_equal(profile_questions(:string_q), ans.profile_question)
    assert_equal(ans.ref_obj, user.member)
  end

  def test_save_answer_failure
    member = users(:mentor_5).member
    answer = member.profile_answers.build(profile_question: profile_questions(:multi_choice_q))
    # Answer contains an invalid choice. Answer should not be created
    assert_no_difference("ProfileAnswer.count") do
      assert_raise ActiveRecord::RecordInvalid do
        assert !answer.save_answer!(profile_questions(:multi_choice_q), ["Klm"])
      end
    end
  end

  def test_build_new_education_answers
    profile_answer = profile_questions(:multi_education_q).profile_answers.new
    profile_answer_2 = profile_questions(:multi_education_q).profile_answers.new
    education_attributes = [
      {},
      { school_name: "", major: "" },
      { school_name: "school1", major: "" },
      { school_name: "school2", major: "major2" }
    ]

    assert_empty profile_answer.educations
    profile_answer.build_new_education_answers(education_attributes)

    educations = profile_answer.educations
    assert_equal 2, educations.size
    assert_equal [profile_answer], educations.collect(&:profile_answer).uniq
    assert_equal ["school1", "school2"], educations.collect(&:school_name)
    assert_equal ["", "major2"], educations.collect(&:major)

    assert_empty profile_answer_2.educations
    profile_answer_2.build_new_education_answers(education_attributes, false)

    educations = profile_answer_2.educations
    assert_equal 4, educations.size
    assert_equal [profile_answer_2], educations.collect(&:profile_answer).uniq
    assert_equal [nil, "", "school1", "school2"], educations.collect(&:school_name)
    assert_equal [nil, "", "", "major2"], educations.collect(&:major)
  end

  def test_build_new_experience_answers
    profile_answer = profile_questions(:multi_experience_q).profile_answers.new
    profile_answer_2 = profile_questions(:multi_experience_q).profile_answers.new
    experience_attributes = [
      {},
      { company: "", job_title: "" },
      { company: "company1", job_title: "" },
      { company: "company2", job_title: "job_title2" }
    ]

    assert_empty profile_answer.experiences
    profile_answer.build_new_experience_answers(experience_attributes)
    experiences = profile_answer.experiences
    assert_equal 2, experiences.size
    assert_equal [profile_answer], experiences.collect(&:profile_answer).uniq
    assert_equal ["company1", "company2"], experiences.collect(&:company)
    assert_equal ["", "job_title2"], experiences.collect(&:job_title)

    assert_empty profile_answer_2.experiences
    profile_answer_2.build_new_experience_answers(experience_attributes, false)
    experiences = profile_answer_2.experiences
    assert_equal 4, experiences.size
    assert_equal [profile_answer_2], experiences.collect(&:profile_answer).uniq
    assert_equal [nil, "", "company1", "company2"], experiences.collect(&:company)
    assert_equal [nil, "", "", "job_title2"], experiences.collect(&:job_title)
  end

  def test_build_new_publication_answers
    profile_answer = profile_questions(:multi_publication_q).profile_answers.new
    profile_answer_2 = profile_questions(:multi_publication_q).profile_answers.new
    publication_attributes = [
      {},
      { title: "" },
      { title: "title" }
    ]

    assert_empty profile_answer.publications
    profile_answer.build_new_publication_answers(publication_attributes)

    publications = profile_answer.publications
    assert_equal 1, publications.size
    assert_equal [profile_answer], publications.collect(&:profile_answer).uniq
    assert_equal ["title"], publications.collect(&:title)

    assert_empty profile_answer_2.publications
    profile_answer_2.build_new_publication_answers(publication_attributes, false)

    publications = profile_answer_2.publications
    assert_equal 3, publications.size
    assert_equal [profile_answer_2], publications.collect(&:profile_answer).uniq
    assert_equal [nil, "", "title"], publications.collect(&:title)
  end

  def test_build_new_manager_answers
    profile_answer = profile_questions(:manager_q).profile_answers.new
    profile_answer_2 = profile_questions(:manager_q).profile_answers.new
    manager_attributes = [{ first_name: "" }]

    assert_nil profile_answer.manager

    profile_answer.build_new_manager_answers(manager_attributes)
    assert_nil profile_answer.manager

    profile_answer.build_new_manager_answers(manager_attributes, false)
    assert_equal "", profile_answer.manager.first_name

    manager_attributes = [{ first_name: "First Name", last_name: "Last Name", email: "email" }]
    profile_answer_2.build_new_manager_answers(manager_attributes)
    assert_equal "First Name", profile_answer_2.manager.first_name
    assert_equal "Last Name", profile_answer_2.manager.last_name
    assert_equal "email", profile_answer_2.manager.email
  end

  def test_handle_existing_education_answers
    education = create_education(members(:f_student), profile_questions(:multi_education_q), graduation_year: 2016)
    education_id = education.id.to_s
    profile_answer = education.profile_answer
    existing_education_attributes = { education_id => { school_name: "CEG", degree: "B.Tech", major: "IT", graduation_year: 2016 }}

    profile_answer.handle_existing_education_answers(existing_education_attributes)
    assert_equal [["CEG", "B.Tech", "IT"]], profile_answer.educations.collect {|education| [education.school_name, education.degree, education.major] }
    assert_equal [["CEG", "B.Tech", "IT"]], profile_answer.educations.reload.collect {|education| [education.school_name, education.degree, education.major] }

    existing_education_attributes = { education_id => { school_name: "PSG", degree: "BE", major: "CSE", graduation_year: 2016 }}
    profile_answer.handle_existing_education_answers(existing_education_attributes, false)
    assert_equal [["PSG", "BE", "CSE"]], profile_answer.educations.collect {|education| [education.school_name, education.degree, education.major] }
    assert_equal [["CEG", "B.Tech", "IT"]], profile_answer.educations.reload.collect {|education| [education.school_name, education.degree, education.major] }

    existing_education_attributes = { education_id => { school_name: "", degree: "", major: "" } }

    profile_answer.handle_existing_education_answers(existing_education_attributes, false)
    assert_equal [["", "", ""]], profile_answer.educations.collect {|education| [education.school_name, education.degree, education.major] }
    assert_equal [["CEG", "B.Tech", "IT"]], profile_answer.educations.reload.collect {|education| [education.school_name, education.degree, education.major] }

    profile_answer.handle_existing_education_answers(existing_education_attributes)
    assert_empty profile_answer.educations.reload

    education_2 = create_education(members(:f_student), profile_questions(:multi_education_q), graduation_year: 2016)
    education_3 = create_education(members(:f_student), profile_questions(:multi_education_q), graduation_year: 2016)
    profile_answer = education_2.profile_answer
    existing_education_attributes = {
      education_2.id.to_s => { school_name: "PSG", degree: "BE", major: "CSE" },
      education_3.id.to_s => { school_name: "", degree: "", major: "" }
    }

    profile_answer.reload.handle_existing_education_answers(existing_education_attributes, false)
    assert_equal_unordered [["PSG", "BE", "CSE"], ["", "", ""]], profile_answer.educations.collect {|education| [education.school_name, education.degree, education.major] }

    profile_answer.reload.handle_existing_education_answers(existing_education_attributes)
    assert_equal [["PSG", "BE", "CSE"]], profile_answer.educations.reload.collect {|education| [education.school_name, education.degree, education.major] }
  end

  def test_handle_existing_experience_answers
    experience = create_experience(members(:f_student), profile_questions(:multi_experience_q))
    experience_id = experience.id.to_s
    profile_answer = experience.profile_answer
    existing_experience_attributes = { experience_id => { job_title: "SDE1", company: "CHR" } }

    profile_answer.handle_existing_experience_answers(existing_experience_attributes)
    assert_equal [["SDE1", "CHR"]], profile_answer.experiences.collect {|experience| [experience.job_title, experience.company] }
    assert_equal [["SDE1", "CHR"]], profile_answer.experiences.reload.collect {|experience| [experience.job_title, experience.company] }

    existing_experience_attributes = { experience_id => { job_title: "SDE2", company: "MS"} }
    profile_answer.handle_existing_experience_answers(existing_experience_attributes, false)
    assert_equal [["SDE2", "MS"]], profile_answer.experiences.collect {|experience| [experience.job_title, experience.company] }
    assert_equal [["SDE1", "CHR"]], profile_answer.experiences.reload.collect {|experience| [experience.job_title, experience.company] }

    existing_experience_attributes = { experience_id => { job_title: "", company: "" } }

    profile_answer.handle_existing_experience_answers(existing_experience_attributes, false)
    assert_equal [["", ""]], profile_answer.experiences.collect {|experience| [experience.job_title, experience.company] }
    assert_equal [["SDE1", "CHR"]], profile_answer.experiences.reload.collect {|experience| [experience.job_title, experience.company] }

    profile_answer.handle_existing_experience_answers(existing_experience_attributes)
    assert_empty profile_answer.experiences.reload

    experience_2 = create_experience(members(:f_student), profile_questions(:multi_experience_q))
    experience_3 = create_experience(members(:f_student), profile_questions(:multi_experience_q))
    profile_answer = experience_2.profile_answer
    existing_experience_attributes = {
      experience_2.id.to_s => { job_title: "SDE1", company: "CHR" },
      experience_3.id.to_s => { job_title: "", company: "" }
    }
    profile_answer.reload.handle_existing_experience_answers(existing_experience_attributes, false)
    assert_equal_unordered [["SDE1", "CHR"], ["", ""]], profile_answer.experiences.collect {|experience| [experience.job_title, experience.company] }

    profile_answer.reload.handle_existing_experience_answers(existing_experience_attributes)
    assert_equal [["SDE1", "CHR"]], profile_answer.experiences.reload.collect {|experience| [experience.job_title, experience.company] }
  end

  def test_handle_existing_publication_answers
    publication = create_publication(members(:f_student), profile_questions(:multi_publication_q))
    publication_id = publication.id.to_s
    profile_answer = publication.profile_answer
    existing_publication_attributes = { publication_id => { title: "Title1" } }

    profile_answer.handle_existing_publication_answers(existing_publication_attributes)
    assert_equal [["Title1"]], profile_answer.publications.collect {|publication| [publication.title] }
    assert_equal [["Title1"]], profile_answer.publications.reload.collect {|publication| [publication.title] }

    existing_publication_attributes = { publication_id => { title: "Title" } }
    profile_answer.handle_existing_publication_answers(existing_publication_attributes, false)
    assert_equal [["Title"]], profile_answer.publications.collect {|publication| [publication.title] }
    assert_equal [["Title1"]], profile_answer.publications.reload.collect {|publication| [publication.title] }

    existing_publication_attributes = { publication_id => { title: "" } }

    profile_answer.handle_existing_publication_answers(existing_publication_attributes, false)
    assert_equal [[""]], profile_answer.publications.collect {|publication| [publication.title] }
    assert_equal [["Title1"]], profile_answer.publications.reload.collect {|publication| [publication.title] }

    profile_answer.handle_existing_publication_answers(existing_publication_attributes)
    assert_empty profile_answer.publications.reload

    publication_2 = create_publication(members(:f_student), profile_questions(:multi_publication_q))
    publication_3 = create_publication(members(:f_student), profile_questions(:multi_publication_q))
    profile_answer = publication_2.profile_answer
    existing_publication_attributes = {
      publication_2.id.to_s => { title: "Title2" },
      publication_3.id.to_s => { title: "" }
    }

    profile_answer.reload.handle_existing_publication_answers(existing_publication_attributes, false)
    assert_equal_unordered [["Title2"], [""]], profile_answer.publications.collect {|publication| [publication.title] }

    profile_answer.reload.handle_existing_publication_answers(existing_publication_attributes)
    assert_equal [["Title2"]], profile_answer.publications.reload.collect {|publication| [publication.title] }
  end

  def test_handle_existing_manager_answers
    manager = create_manager(members(:f_student), profile_questions(:manager_q))
    manager_id = manager.id.to_s
    profile_answer = manager.profile_answer
    existing_manager_attributes = { manager_id => { first_name: "FN", last_name: "LN", email: "manager1@example.com" }}

    profile_answer.handle_existing_manager_answers(existing_manager_attributes)
    assert_equal ["FN", "LN", "manager1@example.com"], profile_answer.manager.attributes.values_at("first_name", "last_name", "email")
    assert_equal ["FN", "LN", "manager1@example.com"], profile_answer.manager.reload.attributes.values_at("first_name", "last_name", "email")

    existing_manager_attributes = { manager_id => { first_name: "Firstname", last_name: "Lastname", email: "manager2@example.com" }}
    profile_answer.handle_existing_manager_answers(existing_manager_attributes, false)
    assert_equal ["Firstname", "Lastname", "manager2@example.com"], profile_answer.manager.attributes.values_at("first_name", "last_name", "email")
    assert_equal ["FN", "LN", "manager1@example.com"], profile_answer.manager.reload.attributes.values_at("first_name", "last_name", "email")

    existing_manager_attributes = { manager_id => { first_name: "", last_name: "", email: "" } }

    profile_answer.handle_existing_manager_answers(existing_manager_attributes, false)
    assert_equal ["", "", ""], profile_answer.manager.attributes.values_at("first_name", "last_name", "email")
    assert_equal ["FN", "LN", "manager1@example.com"], profile_answer.manager.reload.attributes.values_at("first_name", "last_name", "email")

    profile_answer.handle_existing_manager_answers(existing_manager_attributes)
    assert_nil members(:f_student).answer_for(profile_questions(:manager_q))
  end

  def test_assign_file_name_and_code
    profile_answer = profile_questions(:mentor_file_upload_q).profile_answers.new
    profile_answer.assign_file_name_and_code("name", "code")
    assert_equal "name", profile_answer.temp_file_name
    assert_equal "code", profile_answer.temp_file_code
  end

  def test_versioning
    q = create_question(role_names: [RoleConstants::MENTOR_NAME])
    member = members(:f_mentor)
    answer = member.profile_answers.build(profile_question: q, answer_value: "abc")
    assert_no_difference "ChronusVersion.count" do
      assert_difference "ProfileAnswer.count" do
        answer.save!
      end
    end
    assert answer.versions.empty?

    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        answer.update_attributes(answer_value: "def")
      end
    end
    assert_equal 1, answer.versions.size

    assert_no_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        answer.update_attributes(answer_value: "def")
      end
    end
    assert_equal 1, answer.versions.size

    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        answer.update_attributes(updated_at: 1.second.from_now)
      end
    end
    assert_equal 2, answer.versions.size
  end

  def test_answer_choices_association
    assert_equal answer_choices(:answer_choices_3, :answer_choices_4), profile_answers(:multi_choice_ans_1).answer_choices
  end

  def test_update_or_destroy_answer_text
    qc = question_choices(:multi_choice_q_1)
    profile_answer = qc.profile_answers.first
    assert_equal "Stand, Run", profile_answer.answer_text
    ProfileAnswer.expects(:es_reindex).with([profile_answer]).once
    qc.translation.update_column(:text, "New multi choice")
    assert_no_difference "AnswerChoice.count" do
      ProfileAnswer.update_or_destroy_answer_text(qc)
    end
    assert_equal "New multi choice, Run", profile_answer.reload.answer_text

    ProfileAnswer.expects(:es_reindex).with([profile_answer]).once
    assert_difference "AnswerChoice.count", -1 do
      ProfileAnswer.update_or_destroy_answer_text(qc, true)
    end
    assert_equal "Run", profile_answer.reload.answer_text

    # For non choice based questions, profile answer should not be destroyed
    ProfileQuestion.any_instance.stubs(:choice_or_select_type?).returns(false)
    ProfileAnswer.expects(:es_reindex).with([profile_answer]).never
    assert_no_difference "ProfileAnswer.count" do
      assert_difference "AnswerChoice.count", -1 do
        ProfileAnswer.update_or_destroy_answer_text(question_choices(:multi_choice_q_2), true)
      end
    end
    assert_equal "Run", profile_answer.reload.answer_text
  end
end