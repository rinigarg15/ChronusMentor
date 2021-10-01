require_relative './../test_helper.rb'

class BulkMatchTest < ActiveSupport::TestCase

  def test_associations
    program = programs(:nwen)

    assert_empty program.bulk_matches

    bulk_match = create_bulk_match(program: program)
    assert_equal [bulk_match], program.reload.bulk_matches

    assert_equal [], bulk_match.groups
    group = program.groups.first
    group.bulk_match = bulk_match
    group.save!
    assert_equal [group], bulk_match.reload.groups
  end

  def test_default_settings
    bulk_match = bulk_matches(:bulk_match_1)
    assert_false bulk_match.show_drafted
    assert_false bulk_match.show_published
    assert bulk_match.request_notes
    assert_nil bulk_match.sort_value
    assert_equal true, bulk_match.sort_order
  end

  def test_generate_csv
    bulk_match = bulk_matches(:bulk_match_1)
    group = groups(:mygroup)
    group.bulk_match = bulk_match
    group.published_at = nil
    group.save!

    csv = bulk_match.generate_csv_for_drafted_pairs(bulk_match.groups.drafted, {group.students.first.id => {group.mentors.first.id => 80}}, [group.students.first.id], [group.mentors.first.id])
    csv_response = csv.split("\n")
    assert_equal 1, csv_response.size
    assert_match "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]

    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.published_at = nil
    group.save!
    csv = bulk_match.reload.generate_csv_for_drafted_pairs(bulk_match.groups.drafted, {group.students.first.id => {group.mentors.first.id => 80}}, [group.students.first.id], [group.mentors.first.id])

    csv_response = csv.split("\n")
    assert_equal 2, csv_response.size
    assert_match "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_equal "#{group.students.first.name},#{group.mentors.first.name},80,Drafted,#{group.created_at.strftime("%d-%b-%Y")},,,0", csv_response[1]
  end

  def test_generate_csv_for_all_pairs
    bulk_match = mock
    BulkMatch.expects(:new).returns(bulk_match)
    bulk_match.expects(:generate_csv_for_all_pairs)
    BulkMatch.generate_csv_for_all_pairs(nil, nil, nil, {})
  end

  def test_generate_csv_with_match_configs
    bulk_match = bulk_matches(:bulk_match_1)    
    group = groups(:mygroup)
    group.bulk_match = bulk_match
    group.status = Group::Status::DRAFTED
    group.published_at = nil
    group.created_by = users(:f_admin)
    group.save!

    program = programs(:albers)
    prof_q = create_profile_question(:organization => programs(:org_primary))
    mentor_question = create_role_question(:program => program, :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)
    student_question = create_role_question(:program => program, :role_names => [RoleConstants::STUDENT_NAME], :profile_question => prof_q)
    MatchConfig.create!(
        :program => program,
        :mentor_question => mentor_question,
        :student_question => student_question)

    csv = bulk_match.reload.generate_csv_for_drafted_pairs(bulk_match.groups.drafted, {group.students.first.id => {group.mentors.first.id => 80}}, [group.students.first.id], [group.mentors.first.id])
    csv_response = csv.split("\n")
    assert_equal 2, csv_response.size
    assert_equal "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor,||,Student's Answer for : Whats your age?,Mentor's Answer for : Whats your age?", csv_response[0]
    assert_equal "#{group.students.first.name},#{group.mentors.first.name},80,Drafted,#{group.created_at.strftime("%d-%b-%Y")},,,0,||,\"\",\"\"", csv_response[1]

    ProfileAnswer.create!(:answer_text => '25',:profile_question => prof_q, :ref_obj => group.students.first.member)
    ProfileAnswer.create!(:answer_text => '50',:profile_question => prof_q, :ref_obj => group.mentors.first.member)
    csv = bulk_match.reload.generate_csv_for_drafted_pairs(bulk_match.groups.drafted, {group.students.first.id => {group.mentors.first.id => 80}}, [group.students.first.id], [group.mentors.first.id])
    csv_response = csv.split("\n")
    assert_equal 2, csv_response.size
    assert_equal "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor,||,Student's Answer for : Whats your age?,Mentor's Answer for : Whats your age?", csv_response[0]
    assert_equal "#{group.students.first.name},#{group.mentors.first.name},80,Drafted,#{group.created_at.strftime("%d-%b-%Y")},,,0,||,25,50", csv_response[1]
  end

  def test_generate_csv_should_call_globalize_answers
    bulk_match = bulk_matches(:bulk_match_1)    
    group = groups(:mygroup)
    group.bulk_match = bulk_match
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.published_at = nil
    group.save!

    program = programs(:albers)
    prof_q = create_profile_question(:organization => programs(:org_primary))
    mentor_question = create_role_question(:program => program, :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)
    student_question = create_role_question(:program => program, :role_names => [RoleConstants::STUDENT_NAME], :profile_question => prof_q)
    MatchConfig.create!(
        :program => program,
        :mentor_question => mentor_question,
        :student_question => student_question)

    bulk_match.expects(:get_globalized_answer).times(2)    
    csv = bulk_match.reload.generate_csv_for_drafted_pairs(bulk_match.groups.drafted, {group.students.first.id => {group.mentors.first.id => 80}}, [group.students.first.id], [group.mentors.first.id])
  end

  def test_mentor_to_mentee
    bulk_match = programs(:albers).mentor_bulk_match
    assert bulk_match.send(:mentor_to_mentee?)

    bulk_match = programs(:albers).student_bulk_match
    assert_false bulk_match.send(:mentor_to_mentee?)
  end

  private

  def _Mentor
    "Mentor"
  end

  def _Mentee
    "Student"
  end
end