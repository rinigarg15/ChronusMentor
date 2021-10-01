require_relative './../test_helper.rb'
require 'date'

class PublicationTest < ActiveSupport::TestCase
  def test_max_count_for_single_answer

    multi_question = profile_questions(:multi_publication_q)
    multi_answer_ids = multi_question.profile_answers.collect(&:id)
    question = profile_questions(:publication_q)
    answer_ids = question.profile_answers.collect(&:id)


    assert_equal 2, Publication.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Publication.max_count_for_single_answer(answer_ids)
    assert_equal 0, Publication.max_count_for_single_answer([])

    assert_difference('Publication.count') do
      create_publication(members(:f_mentor), multi_question)
    end

    assert_equal 3, Publication.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Publication.max_count_for_single_answer(answer_ids)
    assert_equal 0, Publication.max_count_for_single_answer([])

    assert_difference('Publication.count') do
      create_publication(members(:mentor_3), multi_question)
    end
    assert_equal 3, Publication.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Publication.max_count_for_single_answer(answer_ids)
    assert_equal 0, Publication.max_count_for_single_answer([])

    assert_difference('Publication.count') do
      create_publication(members(:mentor_3), question)
    end

    assert_equal 3, Publication.max_count_for_single_answer(multi_answer_ids)
    assert_equal 1, Publication.max_count_for_single_answer(answer_ids)
    assert_equal 0, Publication.max_count_for_single_answer([])
  end

  def test_create_new_publication_should_create_answer
    user = users(:mentor_3)
    question = profile_questions(:publication_q)
    user.member.publications.each{|e| e.destroy} # Destroying all publications of user. This will destroy corresponding answers also

    assert_nil user.answer_for(question)

    assert_difference('ProfileAnswer.count') do
      assert_difference('Publication.count') do
        create_publication(user.member, question, :title => "Pub1",
          :publisher => "Chronus", :year => 2005)
      end
    end
    assert user.answer_for(question)
    assert_equal 1, user.answer_for(question).publications.count
    publication = user.answer_for(question).publications.first
    assert_equal "Chronus", publication.publisher
    assert_equal "Pub1", publication.title
    assert_equal "Pub1, Chronus, http://public.url, Author, Very useful publication",user.answer_for(question).answer_text
  end

  def test_updating_publcation_attributes_should_change_answer_text_value
    user = users(:mentor_3)
    question = profile_questions(:multi_publication_q)
    answer = user.answer_for(question)
    publication = answer.publications.first

    assert_equal "Third publication", publication.title
    assert_equal "Third publication, Publisher, http://publication.url, mentor_d chronus, Very useful publication",answer.answer_text

    publication.update_attributes(:title => "Changed Title")

    assert_equal "Changed Title", publication.title
    assert_equal "Changed Title, Publisher, http://publication.url, mentor_d chronus, Very useful publication", answer.reload.answer_text
  end

  def test_destroying_publication_should_not_destroy_answer_if_it_has_more_publications
    user = users(:f_mentor)
    question = profile_questions(:multi_publication_q)
    answer = user.answer_for(question)

    assert_equal 2, answer.publications.count
    publication = publications(:pub_1)
    assert answer.publications.include? publication

    assert_no_difference('ProfileAnswer.count') do
      assert_difference('Publication.count', -1) do
        publication.destroy
      end
    end

    assert_equal 1, answer.reload.publications.count
    assert_equal "Mentor publication, Publisher, http://publication.url, Good unique name, Very useful publication", answer.reload.answer_text
  end

  def test_destroying_publication_should_destroy_publications_if_no_more_publications
    user = users(:f_mentor)
    question = profile_questions(:publication_q)
    answer = user.answer_for(question)

    assert_equal 1, answer.publications.count
    publication = answer.publications.first

    assert_difference('ProfileAnswer.count', -1) do
      assert_difference('Publication.count', -1) do
        publication.destroy
      end
    end

    assert_nil user.answer_for(question)
  end

  def test_column_names_for_question_for_non_publication_question
    question = profile_questions(:profile_questions_1)
    assert_equal [], Publication.column_names_for_question(question)
  end

  def test_column_names_for_question_for_multi_publication_question
    question = profile_questions(:multi_publication_q)
    expected = [
      "New Publication-Title",
      "New Publication-Publication/Publisher",
      "New Publication-Publication Date",
      "New Publication-Publication URL",
      "New Publication-Author(s)",
      "New Publication-Description"
    ]
    assert_equal expected, Publication.column_names_for_question(question)
  end

  def test_column_names_for_question_for_single_publication_question
    question = profile_questions(:publication_q)
    expected = [
      "Current Publication-Title",
      "Current Publication-Publication/Publisher",
      "Current Publication-Publication Date",
      "Current Publication-Publication URL",
      "Current Publication-Author(s)",
      "Current Publication-Description"
    ]
    assert_equal expected, Publication.column_names_for_question(question)
  end

  def test_add_url_protocol
    question = profile_questions(:multi_publication_q)
    publication = create_publication(members(:mentor_3), question, :title => "Pub1", :url => "google.com")
    assert_equal 'http://google.com', publication.url

    publication = create_publication(members(:mentor_3), question, :title => "Pub2", :url => "https://google.com")
    assert_equal 'https://google.com', publication.url

    publication = create_publication(members(:mentor_3), question, :title => "Pub3", :url => "http://google.com")
    assert_equal 'http://google.com', publication.url
  end

  def test_formatted_date
    publication = Publication.new(:title => "Publication")
    # Year blank
    assert_blank publication.formatted_date
    # Only year
    publication.year = 2010
    assert_equal '2010', publication.formatted_date
    # Year and month
    publication.month = 2
    assert_equal 'February 2010', publication.formatted_date
    # Year, month and day
    publication.day = 2
    assert_equal 'February 02, 2010', publication.formatted_date
    # February and wrong day
    publication.day = 30
    assert_equal 'March 02, 2010', publication.formatted_date
    # February, leap year and wrong day
    publication.year = 1956
    publication.day = 29
    assert_equal 'February 29, 1956', publication.formatted_date
  end

  def test_prepare_day_and_month
    publication = Publication.new(:title => "Publication")
    # Right day
    publication.year = 2013
    publication.month = 9
    publication.day = 30
    assert_equal [30, 9], publication.prepare_day_and_month
    # Wrong day in September
    publication.day = 31
    assert_equal [1, 10], publication.prepare_day_and_month
    # Wrong day in February
    publication.month = 2
    assert_equal [3, 3], publication.prepare_day_and_month
  end

  def test_versioning
    member = members(:mentor_1)
    question = profile_questions(:publication_q)
    assert_nil member.answer_for(question)
    assert_no_difference "ChronusVersion.count" do
      assert_difference "ProfileAnswer.count" do
        assert_difference "Publication.count" do
          create_publication(member, question, :title => "Pub1",
          :publisher => "Chronus", :year => 2005)
        end
      end
    end
    answer = ProfileAnswer.last
    pub = Publication.last
    assert answer.versions.empty?
    assert pub.versions.empty?

    assert_difference "ChronusVersion.count", 2 do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Publication.count" do
          pub.update_attributes(title: "Pub2")
        end
      end
    end
    answer = ProfileAnswer.last
    pub = Publication.last
    assert_equal 1, answer.versions.size
    assert_equal 1, pub.versions.size

    # year is not stored as a part of profile answer
    # so it wont be updated, hence no new version
    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Publication.count" do
          pub.update_attributes(year: 2013)
        end
      end
    end
    answer = ProfileAnswer.last
    pub = Publication.last
    assert_equal 1, answer.versions.size
    assert_equal 2, pub.versions.size

    assert_difference "ChronusVersion.count" do
      assert_no_difference "ProfileAnswer.count" do
        assert_no_difference "Publication.count" do
          pub.updated_at = 1.second.from_now
          pub.save!
        end
      end
    end
    answer = ProfileAnswer.last
    pub = Publication.last
    assert_equal 1, answer.versions.size
    assert_equal 3, pub.versions.size
  end
end
