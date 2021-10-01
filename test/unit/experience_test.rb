require_relative './../test_helper.rb'
require 'date'

class ExperienceTest < ActiveSupport::TestCase

  def test_validate_start_year
    experience = Experience.new(
      job_title: "SDE",
      company: "Chronus",
      profile_answer: ProfileAnswer.first
    )
    assert experience.valid?

    experience.start_year = ProfileConstants.valid_years.first - 1
    assert_false experience.valid?
    assert_equal ["is not included in the list"], experience.errors[:start_year]

    experience.start_year = ProfileConstants.valid_years.first
    assert experience.valid?

    experience.start_year = ProfileConstants.valid_years.last + 1
    assert_false experience.valid?
    assert_equal ["is not included in the list"], experience.errors[:start_year]

    experience.start_year = ProfileConstants.valid_years.last
    assert experience.valid?
  end

  def test_validate_end_year
    experience = Experience.new(
      job_title: "SDE",
      company: "Chronus",
      start_year: ProfileConstants.valid_years.last,
      profile_answer: ProfileAnswer.first
    )
    assert experience.valid?

    experience.end_year = ProfileConstants.valid_years.last + 1
    assert_false experience.valid?
    assert_equal ["is not included in the list"], experience.errors[:end_year]

    experience.end_year = ProfileConstants.valid_years.last - 1
    assert_false experience.valid?
    assert_equal ["end year comes before start year"], experience.errors[:base]
    assert_empty experience.errors[:end_year]

    experience.start_year = ProfileConstants.valid_years.last - 1
    experience.end_year = ProfileConstants.valid_years.last
    assert experience.valid?
  end

  def test_check_start_and_end_month
    experience = Experience.new(
      job_title: "SDE",
      company: "Chronus",
      start_year: ProfileConstants.valid_years.sample,
      start_month: 15,
      end_month: -5
    )
    assert_false experience.valid?
    assert experience.errors[:start_month]
    assert experience.errors[:end_month]
  end

  def test_max_count_for_single_answer
    multi_question = profile_questions(:multi_experience_q)
    multi_answer_ids = multi_question.profile_answers.collect(&:id)
    question = profile_questions(:experience_q)
    answer_ids = question.profile_answers.collect(&:id)

    assert_equal 2, Experience.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Experience.max_count_for_single_answer(answer_ids)
    assert_equal 0, Experience.max_count_for_single_answer([])

    assert_difference('Experience.count') do
      create_experience(members(:f_mentor), multi_question)
    end
    assert_equal 3, Experience.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Experience.max_count_for_single_answer(answer_ids)
    assert_equal 0, Experience.max_count_for_single_answer([])

    assert_difference('Experience.count') do
      create_experience(members(:mentor_3), multi_question)
    end
    assert_equal 3, Experience.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Experience.max_count_for_single_answer(answer_ids)
    assert_equal 0, Experience.max_count_for_single_answer([])

    assert_difference('Experience.count') do
      create_experience(members(:mentor_3), question)
    end
    assert_equal 3, Experience.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Experience.max_count_for_single_answer(answer_ids)
    assert_equal 0, Experience.max_count_for_single_answer([])
  end

  def test_dates_present
    experience = Experience.new(
      job_title: "SDE",
      company: "Chronus"
    )

    assert_false experience.dates_present?

    experience.start_year = 2010
    assert experience.dates_present?

    experience.end_year = 2005
    assert experience.dates_present?

    experience.start_year = nil
    assert experience.dates_present?

    experience.end_year = nil
    experience.start_month = 5
    assert_false experience.dates_present?

    experience.start_month = nil
    experience.end_month = 2
    assert_false experience.dates_present?
  end

  def test_create_new_experience_should_create_answer
    user = users(:mentor_3)
    question = profile_questions(:experience_q)
    user.member.experiences.each{|e| e.destroy} # Destroying all experiences of user. This will destroy corresponding answers also

    assert_nil user.answer_for(question)

    assert_difference('ProfileAnswer.count') do
      assert_difference('Experience.count') do
        create_experience(user.member, question, job_title: "SDE",
          company: "Chronus", start_year: 2005,
          end_year: 2008)
      end
    end
    assert user.answer_for(question)
    assert_equal 1, user.answer_for(question).experiences.count
    experience = user.answer_for(question).experiences.first
    assert_equal "Chronus", experience.company
    assert_equal "SDE", experience.job_title
    assert_equal "SDE, Chronus",user.answer_for(question).answer_text
  end

  def test_updating_experience_attributes_should_change_answer_text_value
    user = users(:mentor_3)
    question = profile_questions(:multi_experience_q)
    answer = user.answer_for(question)
    experience = answer.experiences.first
    assert_equal "Chief Software Architect And Programming Lead", experience.job_title
    assert_equal "Chief Software Architect And Programming Lead, Mannar",answer.answer_text

    experience.update_attributes(job_title: "Changed Title")
    assert_equal "Changed Title", experience.job_title
    assert_equal "Changed Title, Mannar", answer.reload.answer_text
  end

  def test_destroying_experience_should_not_destroy_answer_if_it_has_more_experiences
    user = users(:f_mentor)
    question = profile_questions(:multi_experience_q)
    answer = user.answer_for(question)

    assert_equal 2, answer.experiences.count
    experience = answer.experiences.first
    assert_equal "Lead Developer, Microsoft\n Chief Software Architect And Programming Lead, Mannar", answer.reload.answer_text

    assert_no_difference('ProfileAnswer.count') do
      assert_difference('Experience.count', -1) do
        experience.destroy
      end
    end
    assert_equal 1, answer.reload.experiences.count
    assert_equal "Chief Software Architect And Programming Lead, Mannar", answer.reload.answer_text
  end

  def test_destroying_experience_should_destroy_experiences_if_no_more_experiences
    user = users(:f_mentor)
    question = profile_questions(:experience_q)
    answer = user.answer_for(question)

    assert_equal 1, answer.experiences.count
    experience = answer.experiences.first

    assert_difference('ProfileAnswer.count', -1) do
      assert_difference('Experience.count', -1) do
        experience.destroy
      end
    end
    assert_nil user.answer_for(question)
  end

  def test_column_names_for_question_for_non_experience_question
    assert_empty Experience.column_names_for_question(profile_questions(:profile_questions_1))
  end

  def test_column_names_for_question_for_multi_experience_question
    assert_equal [
      "Work-Job Title",
      "Work-Start year",
      "Work-End year",
      "Work-Company/Institution",
    ], Experience.column_names_for_question(profile_questions(:profile_questions_7))
  end

  def test_column_names_for_question_for_single_experience_question
    assert_equal [
      "Current Experience-Job Title",
      "Current Experience-Start year",
      "Current Experience-End year",
      "Current Experience-Company/Institution",
    ], Experience.column_names_for_question(profile_questions(:experience_q))
  end

  def test_valid_months_array
    valid_months_array = [["Month", 0], ["Jan", 1], ["Feb", 2], ["Mar", 3], ["Apr", 4], ["May", 5], ["Jun", 6], ["Jul", 7], ["Aug", 8], ["Sep", 9], ["Oct", 10], ["Nov", 11], ["Dec", 12]]
    assert_equal valid_months_array, Experience.valid_months_array
  end

  def test_versioning
    member = members(:mentor_1)
    question = profile_questions(:experience_q)
    assert_nil member.answer_for(question)

    assert_no_difference "ChronusVersion.count" do
      assert_difference "ProfileAnswer.count" do
        assert_difference "Experience.count" do
          create_experience(member, question, job_title: "SDE",
          company: "Chronus", start_year: 2005,
          end_year: 2008)
        end
      end
    end
    answer = ProfileAnswer.last
    experience = Experience.last
    assert answer.versions.empty?
    assert experience.versions.empty?

    assert_difference "ChronusVersion.count", 2 do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Experience.count" do
          experience.update_attributes(job_title: "SDE II")
        end
      end
    end
    answer = ProfileAnswer.last
    experience = Experience.last
    assert_equal 1, answer.versions.size
    assert_equal 1, experience.versions.size

    # start_year, start_month, end_year, end_month, current_job is not stored as a
    # part of profile answer so it wont be updated, hence no new version
    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Experience.count" do
          experience.update_attributes(start_year: 2001)
        end
      end
    end
    answer = ProfileAnswer.last
    experience = Experience.last
    assert_equal 1, answer.versions.size
    assert_equal 2, experience.versions.size

    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Experience.count" do
          experience.update_attributes(current_job: true)
        end
      end
    end
    answer = ProfileAnswer.last
    experience = Experience.last
    assert_equal 1, answer.versions.size
    assert_equal 3, experience.versions.size

    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Experience.count" do
          experience.updated_at = 1.second.from_now
          experience.save!
        end
      end
    end
    answer = ProfileAnswer.last
    experience = Experience.last
    assert_equal 1, answer.versions.size
    assert_equal 4, experience.versions.size
  end
end