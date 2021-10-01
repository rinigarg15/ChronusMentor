require_relative './../../../../test_helper'

class GroupElasticsearchQueriesTest < ActiveSupport::TestCase
  def test_get_filtered_groups
    es_options = { search_conditions: { search_text: "project_b", fields: ["name"] }, must_filters: { program_id: programs(:pbe).id } }
    assert_equal [groups(:group_pbe_1).id], Group.get_filtered_groups(es_options).map(&:id)

    # sort
    es_options[:search_conditions][:search_text] = ""
    es_options[:sort] = { "name.sort" => "asc" }
    assert_equal (groups(:drafted_pbe_group, :rejected_group_1, :proposed_group_3, :proposed_group_4, :withdrawn_group_1, :rejected_group_2) + (0..4).map { |i| groups("group_pbe_#{i}") } + groups(:group_pbe, :proposed_group_1, :proposed_group_2)).map(&:id),  Group.get_filtered_groups(es_options).map(&:id)

    # pagination
    es_options.merge!(page: 1, per_page: 2)
    assert_equal groups(:drafted_pbe_group, :rejected_group_1).map(&:id), Group.get_filtered_groups(es_options).map(&:id)
    es_options.merge!(page: 2, per_page: 2)
    assert_equal groups(:proposed_group_3, :proposed_group_4).map(&:id), Group.get_filtered_groups(es_options).map(&:id)
  end

  def test_get_ids_of_groups_active_between
    nested_es_query_mock = mock
    NestedEsQuery::ActiveGroups.expects(:new).once.with("program", "start_time", "end_time", options: "options").returns(nested_es_query_mock)
    nested_es_query_mock.expects(:get_filtered_ids).once.returns("filtered_group_ids")
    assert_equal "filtered_group_ids", Group.get_ids_of_groups_active_between("program", "start_time", "end_time", options: "options")
  end

  def test_get_filtered_groups_with_sort_mentoring_model
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    group = create_group(program: program, mentoring_model: mentoring_model, students: program.users.students.first, mentors: program.users.mentors.first)
    reindex_documents(created: group)
    es_options = { search_conditions: { search_text: "" }, sort: { "mentoring_model.title.sort" => "asc" }, includes_list: [:mentoring_model], must_filters: { program_id: program.id } }
    assert_equal [mentoring_model.id, program.default_mentoring_model.id], Group.get_filtered_groups(es_options).map(&:mentoring_model_id).uniq

    es_options = { search_conditions: { search_text: "" }, sort: { "mentoring_model.title.sort" => "desc" }, includes_list: [:mentoring_model], must_filters: { program_id: program.id } }
    assert_equal [program.default_mentoring_model.id, mentoring_model.id], Group.get_filtered_groups(es_options).map(&:mentoring_model_id).uniq
  end

  def test_get_filtered_groups_with_sort_tasks
    program = programs(:pbe)
    group = program.groups.first
    create_mentoring_model_task(group: group, user: group.mentors.first, due_date: 3.weeks.ago, required: true)
    reindex_documents(updated: group)
    es_options = { search_conditions: { search_text: "" }, sort: { "tasks_overdue_count" => "asc" }, must_filters: { program_id: program.id } }
    assert_equal [0, 1], Group.get_filtered_groups(es_options).map { |g| g.mentoring_model_tasks.overdue.count }.uniq

    create_mentoring_model_task(group: group, user: group.mentors.first, required: true)
    reindex_documents(updated: group)
    es_options = { search_conditions: { search_text: ""}, sort: { "tasks_pending_count" => "desc" }, must_filters: { program_id: program.id } }
    assert_equal [1, 0], Group.get_filtered_groups(es_options).map { |g| g.mentoring_model_tasks.pending.count }.uniq

    create_mentoring_model_task(group: group, user: group.mentors.first, required: true, status: MentoringModel::Task::Status::DONE)
    reindex_documents(updated: group)
    es_options = { search_conditions: { search_text: "" }, sort: { "tasks_completed_count" => "asc" }, must_filters: { program_id: program.id } }
    assert_equal [0, 1], Group.get_filtered_groups(es_options).map { |g| g.mentoring_model_tasks.status(MentoringModel::Task::Status::DONE).count }.uniq
  end

  def test_get_filtered_groups_with_login_activity
    program = programs(:pbe)
    group = program.groups.first
    group.memberships.each do |membership|
      membership.login_count = 100
      membership.save
    end
    reindex_documents(updated: group)
    es_options = { search_conditions: { search_text: "" }, sort: { "get_rolewise_login_activity_for_group.mentor" => "asc" }, must_filters: { program_id: program.id } }
    assert_equal group.id, Group.get_filtered_group_ids(es_options).last
    es_options = { search_conditions: { search_text: "" }, sort: { "get_rolewise_login_activity_for_group.mentor" => "desc" }, must_filters: { program_id: program.id } }
    assert_equal group.id, Group.get_filtered_group_ids(es_options).first
    es_options = { search_conditions: { search_text: "" }, sort: { "get_rolewise_login_activity_for_group.student" => "desc" }, must_filters: { program_id: program.id } }
    assert_equal group.id, Group.get_filtered_group_ids(es_options).first
  end

  def test_get_filtered_groups_with_messages_activity
    program = programs(:albers)
    group = groups(:group_5)
    create_scrap(group: group, sender: group.mentors.first.member)
    reindex_documents(updated: group)
    es_options = { search_conditions: { search_text: "" }, sort: {"get_rolewise_messages_activity_for_group.mentor" => "asc" }, must_filters: { program_id: program.id } }
    assert_equal [2, 4, 6, 9, 10, 11, 12, 5, 3, 1], Group.get_filtered_group_ids(es_options)
    es_options = { search_conditions: { search_text: "" }, sort: {"get_rolewise_messages_activity_for_group.mentor" => "desc" }, must_filters: { program_id: program.id } }
    assert_equal [1, 3, 5, 2, 4, 6, 9, 10, 11, 12], Group.get_filtered_group_ids(es_options)

    group.scraps.destroy_all
    reindex_documents(updated: group)
    assert_equal [1, 3, 2, 4, 6, 9, 10, 11, 12, 5], Group.get_filtered_group_ids(es_options)
    es_options = { search_conditions: { search_text: "" }, sort: { "get_rolewise_messages_activity_for_group.mentor" => "asc" }, must_filters: { program_id: program.id } }
    assert_equal [2, 4, 6, 9, 10, 11, 12, 5, 3, 1], Group.get_filtered_group_ids(es_options)
  end

  def test_get_filtered_groups_with_survey_responses
    group = groups(:mygroup)
    program = group.program
    create_survey_answer(group: group)
    reindex_documents(updated: group)
    es_options = { search_conditions: { search_text: "" }, sort: { "survey_responses_count" => "asc" }, must_filters: { program_id: program.id } }
    assert_equal [2, 3, 4, 5, 6, 9, 10, 11, 12, 1], Group.get_filtered_group_ids(es_options)
    es_options = { search_conditions: { search_text: "" }, sort: { "survey_responses_count" => "desc" }, must_filters: { program_id: program.id } }
    assert_equal [1, 2, 3, 4, 5, 6, 9, 10, 11, 12], Group.get_filtered_group_ids(es_options)
  end

  def test_get_filtered_group_ids
    es_options = { search_conditions: { search_text: "", fields: ["name"] }, must_filters: { program_id: programs(:pbe).id } }
    assert_equal_unordered ((0..4).map { |i| groups("group_pbe_#{i}") } + groups(:drafted_pbe_group, :rejected_group_1, :proposed_group_3, :proposed_group_4, :withdrawn_group_1, :rejected_group_2, :group_pbe, :proposed_group_1, :proposed_group_2)).map(&:id), Group.get_filtered_group_ids(es_options)
  end

  def test_get_filtered_groups_count
    es_options = { search_conditions: { search_text: "", fields: ["name"] }, must_filters: { program_id: programs(:pbe).id } }
    assert_equal 14, Group.get_filtered_groups_count(es_options)
  end
end