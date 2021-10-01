require_relative './../../../../test_helper'

class ResourceElasticsearchQueriesTest < ActiveSupport::TestCase
  
  def test_get_es_resources
    options = {:filter=>{"resource_publications.program_id"=>13}, :admin_view_check=>true, :current_user_role_ids=>[37], :page=>1, :per_page=>10}
    results = Resource.get_es_resources("",options)

    assert_equal_unordered Role.find(37).users.first.accessible_resources(admin_view: true).collect(&:id), results.collect(&:id)
    
    results = Resource.get_es_resources("crucial partner", options)
    assert_equal 4, results.total_entries
    
    options[:sort] = {"title.sort"=>"asc"}
    results = Resource.get_es_resources("", options)

    assert_not_equal Role.find(37).users.first.accessible_resources(admin_view: true).collect(&:id), results.collect(&:id)
    assert_equal Role.find(37).users.first.accessible_resources(admin_view: true).sort_by(&:title).collect(&:id), results.collect(&:id)
    
    results = Resource.get_es_resources("<html>", options)
    assert_equal [], results.collect(&:id)

    results = Resource.get_es_resources("encyclopedia", options)
    assert_equal [], results.collect(&:id)

    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    s1 = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id

    r2 = create_resource(programs: {programs(:albers) => [m1]}, title: "encyclopedia" )
    r3 = create_resource(programs: {programs(:albers) => [s1]}, title: "encyclopedia",  content: "internship is fun")

    reindex_documents(created: r2)
    reindex_documents(created: r3)

    options = {:filter=>{"resource_publications.program_id"=>6}, :admin_view_check=>false, :current_user_role_ids=>[m1], :page=>1, :per_page=>10}
    results = Resource.get_es_resources("encyclopedia", options)
    assert_equal [r2.id], results.collect(&:id)
    options[:current_user_role_ids] = [m1, s1]
    results = Resource.get_es_resources("encyclopedia", options)
    assert_equal_unordered [r2.id, r3.id], results.collect(&:id)
 
    reindex_documents(deleted: r2)
    results = Resource.get_es_resources("encyclopedia", options)
    assert_equal [r3.id], results.collect(&:id)

  end



end
