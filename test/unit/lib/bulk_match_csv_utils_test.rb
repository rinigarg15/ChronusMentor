require_relative './../../test_helper.rb'

class BulkMatchCsvUtilsTest < ActionView::TestCase
  def test_get_options
    bulk_match = BulkMatch.new
    group = groups(:mygroup)
    group.notes = "New notes"
    mentor = group.mentors.first
    student = group.students.first
    mentor_profile_ques_ids = []
    student_profile_ques_ids = []


    BulkMatch.any_instance.expects(:populate_match_config_details).with(mentor, student, mentor_profile_ques_ids, student_profile_ques_ids).returns(["answers_array"])
    options_hash = bulk_match.send(:get_options, student, {group_status: "Selected"}, mentor, {mentor.id => {recommended_count: 1}}, group: group, mentor_profile_ques_ids: [], student_profile_ques_ids: [], bulk_recommendation_flag: true, preference: 0, recommended_count: 1)
    assert_equal "Selected", options_hash[:status]
    assert_equal DateTime.localize(group.created_at, format: :default_dashed), options_hash[:drafted_date]
    assert_equal DateTime.localize(group.published_at, format: :default_dashed), options_hash[:published_at]
    assert_equal "New notes", options_hash[:notes]
    assert_equal 1, options_hash[:preference]
    assert_equal 1, options_hash[:recommended_count]
    assert_equal ["answers_array"], options_hash[:answers]

    BulkMatch.any_instance.expects(:populate_match_config_details).with(mentor, student, mentor_profile_ques_ids, student_profile_ques_ids).returns(["answers_array"])
    options_hash = bulk_match.send(:get_options, student, {group_status: "Selected"}, mentor, {mentor.id => {recommended_count: 1}}, group: nil, mentor_profile_ques_ids: [], student_profile_ques_ids: [], bulk_recommendation_flag: nil, preference: 0, recommended_count: 1)
    assert_equal [:status, :bulk_recommendation_flag, :answers, :ongoing_connections_count], options_hash.keys


    BulkMatch.any_instance.expects(:populate_match_config_details).with(nil, student, mentor_profile_ques_ids, student_profile_ques_ids).returns(["answers_array"])
    options_hash = bulk_match.send(:get_options, student, {group_status: "unmatched"}, nil, {mentor.id => {recommended_count: 1}}, group: group, mentor_profile_ques_ids: [], student_profile_ques_ids: [], bulk_recommendation_flag: true, preference: 0, recommended_count: 1)
    assert_equal "unmatched", options_hash[:status]
    assert_equal true, options_hash[:bulk_recommendation_flag]
    assert_equal ["answers_array"], options_hash[:answers]
    assert_equal [:status, :bulk_recommendation_flag, :answers], options_hash.keys
  end

  def test_get_options_mentor_to_mentee
    bulk_match = programs(:albers).mentor_bulk_match
    group = groups(:mygroup)
    group.notes = "New notes"
    mentor = group.mentors.first
    student = group.students.first
    mentor_profile_ques_ids = []
    student_profile_ques_ids = []


    BulkMatch.any_instance.expects(:populate_match_config_details).with(mentor, student, mentor_profile_ques_ids, student_profile_ques_ids).returns(["answers_array"])
     BulkMatch.any_instance.stubs(:mentor_to_mentee?).returns(true)
    options_hash = bulk_match.send(:get_options, student, {group_status: "Selected"}, mentor, {mentor.id => {recommended_count: 1}, pickable_slots: 2}, group: nil, mentor_profile_ques_ids: [], student_profile_ques_ids: [], bulk_recommendation_flag: nil, preference: 0, recommended_count: 1)
    assert_equal [:status, :bulk_recommendation_flag, :answers, :ongoing_connections_count, :pickable_slots], options_hash.keys

    BulkMatch.any_instance.expects(:populate_match_config_details).with(mentor, student, mentor_profile_ques_ids, student_profile_ques_ids).returns(["answers_array"])
    BulkMatch.any_instance.stubs(:mentor_to_mentee?).returns(false)
    options_hash = bulk_match.send(:get_options, student, {group_status: "Selected"}, mentor, {mentor.id => {recommended_count: 1}, pickable_slots: 2}, group: nil, mentor_profile_ques_ids: [], student_profile_ques_ids: [], bulk_recommendation_flag: nil, preference: 0, recommended_count: 1)
    assert_equal [:status, :bulk_recommendation_flag, :answers, :ongoing_connections_count], options_hash.keys

    BulkMatch.any_instance.expects(:populate_match_config_details).with(mentor, student, mentor_profile_ques_ids, student_profile_ques_ids).returns(["answers_array"])
    BulkMatch.any_instance.stubs(:mentor_to_mentee?).returns(true)
    options_hash = bulk_match.send(:get_options, student, {group_status: "Selected"}, mentor, {}, group: nil, mentor_profile_ques_ids: [], student_profile_ques_ids: [], bulk_recommendation_flag: nil, preference: 0, recommended_count: 1)
    assert_equal [:status, :bulk_recommendation_flag, :answers, :ongoing_connections_count, :pickable_slots], options_hash.keys
  end

  def test_populate_csv_header
    program = programs(:albers)
    bulk_match = BulkMatch.new
    bulk_match.program = program
    csv = []
    bulk_match.send(:populate_csv_header, csv, program, bulk_recommendation_flag: true)
    assert_equal ["Student Name", "Mentor Name", "Match %", "Recommendation preference", "Status", "Ongoing mentoring connections of the mentor", "Number of times recommended"], csv.flatten
    csv = []
    bulk_match.send(:populate_csv_header, csv, program, bulk_recommendation_flag: false)
    assert_equal ["Student Name", "Mentor Name", "Match %", "Status", "Drafted Date", "Note Added", "Published Date", "Ongoing mentoring connections of the mentor"], csv.flatten
  end

  def test_populate_csv
    program = programs(:albers)
    bulk_match = BulkMatch.new
    bulk_match.program = program
    csv = []
    bulk_match.send(:populate_csv, csv, "Mentor", "Mentee", "90%", status: "Selected", drafted_date: "28-Nov-2017", published_at: "28-Nov-2017", notes: "Notes", ongoing_connections_count: 1)
    assert_equal ["Mentee", "Mentor", "90%", "Selected", "28-Nov-2017", "Notes", "28-Nov-2017", 1], csv.flatten
    csv = []
    bulk_match.send(:populate_csv, csv, "Mentor", "Mentee", "90%", status: "Selected", drafted_date: "28-Nov-2017", published_at: "28-Nov-2017", notes: "Notes", ongoing_connections_count: 1, preference: 1, recommended_count: 1, bulk_recommendation_flag: true)    
    assert_equal ["Mentee", "Mentor", "90%", 1, "Selected", 1, 1], csv.flatten
  end

  def test_get_name_and_match_score_header
    headers = ["feature.bulk_match.content.mentee_name".translate(Mentee: _Mentee), 
      "feature.bulk_match.content.mentor_name".translate(Mentor: _Mentor),
      "feature.bulk_match.content.match_percent".translate
    ]

    bulk_match = programs(:albers).student_bulk_match
    assert_equal headers, bulk_match.send(:get_name_and_match_score_header, programs(:albers))
    

    headers[0], headers[1] = headers[1], headers[0]
    headers << "feature.bulk_match.label.available_slots".translate
    bulk_match = programs(:albers).mentor_bulk_match
    assert_equal headers, bulk_match.send(:get_name_and_match_score_header, programs(:albers))
  end

  private

  def _Mentor
    "Mentor"
  end

  def _Mentee
    "Student"
  end
end