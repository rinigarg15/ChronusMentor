require_relative './../test_helper.rb'

class EducationTest < ActiveSupport::TestCase

  def test_validate_graduation_year
    education = Education.new(
      school_name: "MIT",
      degree: "B.Tech",
      major: "Information Technology",
      profile_answer: ProfileAnswer.first
    )
    assert education.valid?

    education.graduation_year = ProfileConstants.valid_graduation_years.last + 1
    assert_false education.valid?
    assert_equal ["is not included in the list"], education.errors[:graduation_year]

    education.graduation_year = ProfileConstants.valid_graduation_years.last
    assert education.valid?

    education.graduation_year = ProfileConstants.valid_graduation_years.first - 1
    assert_false education.valid?
    assert_equal ["is not included in the list"], education.errors[:graduation_year]

    education.graduation_year = ProfileConstants.valid_graduation_years.first
    assert education.valid?
  end

  def test_max_count_for_single_answer
    multi_question = profile_questions(:multi_education_q)
    multi_answer_ids = multi_question.profile_answers.collect(&:id)
    question = profile_questions(:education_q)
    answer_ids = question.profile_answers.collect(&:id)

    assert_equal 2, Education.max_count_for_single_answer(multi_answer_ids)
    assert_difference('Education.count') do
      create_education(members(:f_mentor), multi_question, school_name: "MIT",
        degree: "B.Tech",
        major: "Information Technology",
        graduation_year: ProfileConstants.valid_graduation_years.sample)
    end
    assert_equal 3, Education.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Education.max_count_for_single_answer(answer_ids)
    assert_equal 0, Education.max_count_for_single_answer([])

    assert_difference('Education.count') do
      create_education(members(:mentor_3), multi_question, school_name: "MIT",
        degree: "M.Tech",
        major: "Information Technology",
        graduation_year: ProfileConstants.valid_graduation_years.sample)
    end
    assert_equal 3, Education.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Education.max_count_for_single_answer(answer_ids)
    assert_equal 0, Education.max_count_for_single_answer([])

    assert_difference('Education.count') do
      create_education(members(:mentor_3), question, school_name: "IIT",
        degree: "B.Tech",
        major: "Mechanical Engineering",
        graduation_year: ProfileConstants.valid_graduation_years.sample)
    end
    assert_equal 3, Education.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Education.max_count_for_single_answer(answer_ids)
    assert_equal 0, Education.max_count_for_single_answer([])
  end

  def test_create_new_education_should_create_answer
    user = users(:mentor_3)
    question = profile_questions(:education_q)
    user.member.educations.map(&:destroy) # Destroying all educations of user. This will destroy corresponding answers also

    assert_nil user.answer_for(question)

    assert_difference('ProfileAnswer.count') do
      assert_difference('Education.count') do
        create_education(members(:mentor_3), question, school_name: "IIT",
          degree: "B.Tech",
          major: "Mechanical Engineering",
          graduation_year: ProfileConstants.valid_graduation_years.sample)
      end
    end
    assert user.answer_for(question)
    assert_equal 1, user.answer_for(question).educations.count
    education = user.answer_for(question).educations.first
    assert_equal "B.Tech", education.degree
    assert_equal "Mechanical Engineering", education.major
    assert_equal "IIT, B.Tech, Mechanical Engineering", user.answer_for(question).answer_text
  end

  def test_updating_education_attributes_should_change_answer_text_value
    user = users(:mentor_3)
    question = profile_questions(:multi_education_q)
    answer = user.answer_for(question)
    education = answer.educations.first
    assert_equal "Arts", education.degree
    assert_equal "American boys school, Arts, Mechanical",answer.answer_text

    education.update_attributes(degree: "Changed Degree")
    assert_equal "Changed Degree", education.degree
    assert_equal "American boys school, Changed Degree, Mechanical", answer.reload.answer_text
  end

  def test_destroying_education_should_not_destroy_answer_if_it_has_more_educations
    user = users(:f_mentor)
    question = profile_questions(:multi_education_q)
    answer = user.answer_for(question)

    assert_equal 2, answer.educations.count
    education = answer.educations.first

    assert_equal "American boys school, Science, Mechanical\n Indian college, Arts, Computer Engineering", answer.reload.answer_text

    assert_no_difference('ProfileAnswer.count') do
      assert_difference('Education.count', -1) do
        education.destroy
      end
    end
    assert_equal 1, answer.reload.educations.count
    assert_equal "American boys school, Science, Mechanical", answer.reload.answer_text
  end

  def test_destroying_education_should_destroy_educations_if_no_more_educations
    user = users(:f_mentor)
    question = profile_questions(:education_q)
    answer = user.answer_for(question)

    assert_equal 1, answer.educations.count
    education = answer.educations.first

    assert_difference('ProfileAnswer.count', -1) do
      assert_difference('Education.count', -1) do
        education.destroy
      end
    end
    assert_nil user.answer_for(question)
  end

  def test_column_names_for_question_for_non_education_question_empty_case
    question = profile_questions(:profile_questions_1)
    assert_equal [], Education.column_names_for_question(question)
  end

  def test_column_names_for_question_for_multi_education_question
    assert_equal [
      "Education-College/School Name",
      "Education-Degree",
      "Education-Major",
      "Education-Graduation Year",
    ], Education.column_names_for_question(profile_questions(:profile_questions_6))
  end

  def test_column_names_for_question_for_non_education_question
    assert_equal [
      "Current Education-College/School Name",
      "Current Education-Degree",
      "Current Education-Major",
      "Current Education-Graduation Year",
    ], Education.column_names_for_question(profile_questions(:education_q))
  end

  def test_max_count_by_program
    program = programs(:albers)
    assert_equal 2, Education.max_count_by_program(program)

    educations(:edu_2).destroy
    assert_equal 1, Education.max_count_by_program(program)
  end

  def test_max_count_by_program_with_question
    program = programs(:albers)
    assert_equal 2, Education.max_count_by_program(program, profile_questions(:multi_education_q).id)
    assert_equal 1, Education.max_count_by_program(program, profile_questions(:education_q).id)
  end

  def test_versioning
    member = members(:mentor_1)
    question = profile_questions(:education_q)
    assert_nil member.answer_for(question)
    assert_no_difference "ChronusVersion.count" do
      assert_difference "ProfileAnswer.count" do
        assert_difference "Education.count" do
          create_education(members(:mentor_3), question, school_name: "IITB",
            degree: "B.Tech",
            major: "CSE",
            graduation_year: 2012)
        end
      end
    end
    answer = ProfileAnswer.last
    ed = Education.last
    assert answer.reload.versions.empty?
    assert ed.reload.versions.empty?

    assert_difference "ChronusVersion.count", 2 do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Education.count" do
          ed.update_attributes(major: "ECE")
        end
      end
    end
    assert_equal 1, answer.reload.versions.size
    assert_equal 1, ed.reload.versions.size

    # graduation_year is not stored as a part of profile answer
    # so it wont be updated, hence no new version
    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Education.count" do
          ed.update_attributes(graduation_year: 2013)
        end
      end
    end
    assert_equal 1, answer.reload.versions.size
    assert_equal 2, ed.reload.versions.size

    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Education.count" do
          ed.updated_at = 1.second.from_now
          ed.save!
        end
      end
    end
    assert_equal 1, answer.reload.versions.size
    assert_equal 3, ed.reload.versions.size
  end

  def test_versioning_multi
    member = members(:mentor_1)
    multi_question = profile_questions(:multi_education_q)
    assert_nil member.answer_for(multi_question)

    assert_no_difference "ChronusVersion.count" do
      assert_difference "ProfileAnswer.count", 1 do
        assert_difference "Education.count", 1 do
          create_education(member, multi_question, school_name: "MIT",
            degree: "B.Tech",
            major: "Information Technology",
            graduation_year: ProfileConstants.valid_graduation_years.sample)
        end
      end
    end

    answer = ProfileAnswer.last
    ed = Education.last
    assert_equal 0, answer.reload.versions.size
    assert_equal 0, ed.reload.versions.size

    assert_difference "ChronusVersion.count", 2 do
      assert_no_difference "ProfileAnswer.count" do
        assert_difference "Education.count", 1 do
          create_education(member, multi_question, school_name: "MIT",
            degree: "M.Tech",
            major: "Information Technology",
            graduation_year: ProfileConstants.valid_graduation_years.sample)
        end
      end
    end

    assert_equal 2, answer.reload.versions.size
    assert_equal 0, ed.reload.versions.size
  end
end