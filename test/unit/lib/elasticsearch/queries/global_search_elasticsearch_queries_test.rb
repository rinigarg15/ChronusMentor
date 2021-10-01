  require_relative './../../../../test_helper'

class GlobalSearchElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_search
    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: {}, classes: [Group])
    assert_equal_unordered [
      { "_type" => "group", active_record: groups(:no_mreq_group) },
      { "_type" => "group", active_record: groups(:group_2) },
      { "_type" => "group", active_record: groups(:group_3) },
      { "_type" => "group", active_record: groups(:group_4) }
    ], formatted_results(results)
    assert_equal 4, results.total_entries

    albers_student_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { role_ids: [albers_student_role.id] }, classes: [Group, User])
    assert_equal_unordered [
      { "_type" => "user", active_record: users(:f_mentor_student) },
      { "_type" => "group", active_record: groups(:group_2) },
      { "_type" => "group", active_record: groups(:group_3) },
      { "_type" => "group", active_record: groups(:group_4) }
    ], formatted_results(results)
    assert_equal 4, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { role_ids: [1, 2] }, classes: [Group, User])
    assert_empty results
    assert_equal 0, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { program_id: programs(:no_mentor_request_program).id }, classes: [Group], page: 1, per_page: 2)
    assert_equal [ { "_type"=>"group", active_record: groups(:no_mreq_group) } ], formatted_results(results)
    assert_equal 1, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { program_id: programs(:no_mentor_request_program).id }, classes: [Group, User], page: 1, per_page: 4)
    assert_equal_unordered [
      { "_type"=>"user", active_record: users(:no_mreq_mentor) },
      { "_type"=>"user", active_record: users(:no_mreq_admin) },
      { "_type"=>"user", active_record: users(:no_mreq_student) },
      { "_type"=>"group", active_record: groups(:no_mreq_group) }
    ], formatted_results(results)
    assert_equal 4, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { program_id: programs(:no_mentor_request_program).id, group_status: 1 }, classes: [Group, User])
    assert_equal_unordered [
      { "_type"=>"user", active_record: users(:no_mreq_mentor) },
      { "_type"=>"user", active_record: users(:no_mreq_admin) },
      { "_type"=>"user", active_record: users(:no_mreq_student) }
    ], formatted_results(results)
    assert_equal 3, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { program_id: programs(:no_mentor_request_program).id, group_status: 1 }, classes: [Group, User], page: 2, per_page: 2)
    assert_equal 1, results.size

    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { program_id: programs(:no_mentor_request_program).id }, classes: [Group], page: 1, per_page: 2)
    assert_equal [ { "_type"=>"group", active_record: groups(:no_mreq_group) } ], formatted_results(results)
    assert_equal 1, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("", with: { program_id: programs(:albers).id }, classes: [Group], page: 1, per_page: 2)
    assert formatted_results(results).all? { |result| result[:active_record].is_a?(Group) && result[:active_record].program_id == programs(:albers).id }
    assert_equal 2, results.size
    assert_equal programs(:albers).groups.count, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("", with: { program_id: programs(:albers).id, role_ids: [38, 39] }, classes: [Resource], page: 1, per_page: 2, admin_view_check: true)

    assert formatted_results(results).all? { |result| result[:active_record].is_a?(Resource) && result[:active_record].resource_publications.collect(&:program_id).include?(programs(:albers).id) }
    assert_equal 2, results.size
    assert_equal programs(:albers).resource_publications.count, results.total_entries

    topic_11 = create_topic(body: 'the mentor is a user')
    topic_21 = create_topic(body: 'the mentee is a user')
    reindex_documents(created: topic_11)
    reindex_documents(created: topic_21)
    
    results = GlobalSearchElasticsearchQueries.new.search("mentor", with: { program_id: topic_11.program.id, role_ids: [38, 39] }, classes: [Topic], page: 1, per_page: 2, admin_view_check: true)
    assert_equal 1, results.total_entries

    results = GlobalSearchElasticsearchQueries.new.search("user", with: { program_id: topic_11.program.id, role_ids: [38, 39] }, classes: [Topic], page: 1, per_page: 2, current_user_role_ids: [38],  admin_view_check: true)
    assert_equal 2, results.total_entries

    forum_1 = create_forum()
    forum_2 = create_forum(program: programs(:ceg))
    topic_12 = create_topic(forum: forum_1 ,body: 'mentor is a user')
    topic_22 = create_topic(forum: forum_2, body: 'mentee is a user', user: users(:ceg_admin))
    reindex_documents(created: topic_12)
    reindex_documents(created: topic_22)
    
    results = GlobalSearchElasticsearchQueries.new.search("mentee", with: { program_id: programs(:albers).id, role_ids: [38, 39] }, classes: [Topic], admin_view_check: true, current_user_role_ids:[38], page: 1, per_page: 2)
    assert_equal_unordered [
      { "_type"=>"topic", active_record: topic_21 }
    ], formatted_results(results)   

    results = GlobalSearchElasticsearchQueries.new.search("", with: { program_id: 13, role_ids: [38, 39] }, classes: [Resource], page: 1, per_page: 2, admin_view_check: false)
    assert_equal 0, results.size
    
    results = GlobalSearchElasticsearchQueries.new.search("", with: { program_id: programs(:albers).id }, classes: [])
    assert_empty results
  end

  def test_search_count
    albers_student_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    assert_equal 4, GlobalSearchElasticsearchQueries.new.count("mentor", with: {}, classes: [Group], page: 1, per_page: 2)
    assert_equal 4, GlobalSearchElasticsearchQueries.new.count("mentor", with: { role_ids: [albers_student_role.id] }, classes: [Group, User], page: 1, per_page: 2)
    assert_equal 0, GlobalSearchElasticsearchQueries.new.count("mentor", with: { role_ids: [1, 2] }, classes: [Group, User], page: 1, per_page: 2)
    assert_equal 1, GlobalSearchElasticsearchQueries.new.count("mentor", with: { program_id: programs(:no_mentor_request_program).id }, classes: [Group], page: 1, per_page: 2)
    assert_equal 4, GlobalSearchElasticsearchQueries.new.count("mentor", with: { program_id: programs(:no_mentor_request_program).id }, classes: [Group, User], page: 1, per_page: 2)
    assert_equal 4, GlobalSearchElasticsearchQueries.new.count("mentor", with: { program_id: programs(:no_mentor_request_program).id }, classes: [Group, User], page: 2, per_page: 2)
    assert_equal 3, GlobalSearchElasticsearchQueries.new.count("mentor", with: { program_id: programs(:no_mentor_request_program).id, group_status: 1 }, classes: [Group, User], page: 2, per_page: 2)
    assert_equal 1, GlobalSearchElasticsearchQueries.new.count("mentor", with: { program_id: programs(:no_mentor_request_program).id }, classes: [Group], page: 1, per_page: 2)
    assert_equal 10, GlobalSearchElasticsearchQueries.new.count("", with: { program_id: programs(:albers).id }, classes: [Group], page: 1, per_page: 2) 
    assert_equal 3, GlobalSearchElasticsearchQueries.new.count("mentor", with: {program_id: programs(:no_mentor_request_program).id, role_ids: [38,39]}, classes: [Resource], admin_view_check: true, page: 1, per_page: 2)
    assert_equal 0, GlobalSearchElasticsearchQueries.new.count("mentor", with: {program_id: programs(:no_mentor_request_program).id, role_ids: [38,39]}, classes: [Resource], page: 1, per_page: 2)
    assert_equal 1, GlobalSearchElasticsearchQueries.new.count("mentor", with: {program_id: programs(:no_mentor_request_program).id}, classes: [Group, Resource], page: 1, per_page: 2)
  end

  private

  def formatted_results(results)
    results.map { |result| result.pick("_type", :active_record) }
  end
end