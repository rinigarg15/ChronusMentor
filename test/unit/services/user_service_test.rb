require_relative './../../test_helper.rb'

class UserServiceTest < ActiveSupport::TestCase
  def test_get_listing_options_with_empty_params
    options = UserService.get_listing_options({})

    assert_equal_unordered [:items_per_page, :page, :sort, :filters], options.keys
    assert_equal_unordered [:search, :role, :program_id], options[:filters].keys
    assert_equal_unordered [:order, :column], options[:sort].keys
    assert_equal 25, options[:items_per_page]
    assert_equal 1, options[:page]
    assert_equal "first_name", options[:sort][:column]
    assert_equal "asc", options[:sort][:order]
    assert_nil options[:filters][:search]
    assert_nil options[:filters][:role]
    assert_nil options[:filters][:program_id]
  end

  def test_get_listing_options_with_params
    params = {
      items_per_page: 50,
      page: 10,
      sort_param: "state",
      sort_order: "desc",
      search_content: "some string",
      filter_role: "mentor",
      filter_program_id: 23
    }

    options = UserService.get_listing_options(params)

    assert_equal_unordered [:items_per_page, :page, :sort, :filters], options.keys
    assert_equal_unordered [:search, :role, :program_id], options[:filters].keys
    assert_equal_unordered [:order, :column], options[:sort].keys
    assert_equal 50, options[:items_per_page]
    assert_equal 10, options[:page]
    assert_equal "state", options[:sort][:column]
    assert_equal "desc", options[:sort][:order]
    assert_equal "some string", options[:filters][:search]
    assert_equal "mentor", options[:filters][:role]
    assert_equal 23, options[:filters][:program_id]
  end

  def test_get_es_search_hash_without_filters
    program = programs(:albers)
    options = UserService.get_listing_options({})
    es_hash = UserService.get_es_search_hash(program, program.organization, options)

    assert_equal_unordered [:per_page, :page, :sort_field, :sort_order, :with, :without], es_hash.keys
    assert_equal 25, es_hash[:per_page]
    assert_equal 1, es_hash[:page]
    assert_equal "name_only.sort", es_hash[:sort_field]
    assert_equal "asc", es_hash[:sort_order]
    assert_equal( { organization_id: program.parent_id }, es_hash[:with])
    assert_equal( { state: Member::Status::SUSPENDED, "users.program_id": program.id }, es_hash[:without])
  end

  def test_get_es_search_hash_with_filters
    program = programs(:albers)
    members(:f_mentor).update_attribute(:state, Member::Status::SUSPENDED)
    options = UserService.get_listing_options( { page: 12, sort_param: "last_name", filter_role: ["63"], filter_program_id: 23 } )
    es_hash = UserService.get_es_search_hash(program, program.organization, options)

    assert_equal_unordered [:per_page, :page, :sort_field, :sort_order, :with, :without], es_hash.keys
    assert_equal 25, es_hash[:per_page]
    assert_equal 12, es_hash[:page]
    assert_equal "last_name.sort", es_hash[:sort_field]
    assert_equal "asc", es_hash[:sort_order]
    assert_equal( { organization_id: program.parent_id, "users.program_id": 23, "users.role_references.role_id": [63] }, es_hash[:with])
    assert_equal( { state: Member::Status::SUSPENDED, "users.program_id": program.id }, es_hash[:without])
  end

  def test_get_es_search_hash_with_dormant_filter
    program = programs(:albers)
    options = UserService.get_listing_options({page: 3, sort_param: "email", filter_role: "Dormant"})
    es_hash = UserService.get_es_search_hash(program, program.organization, options)

    assert_equal_unordered [:per_page, :page, :sort_field, :sort_order, :with, :without], es_hash.keys
    assert_equal 25, es_hash[:per_page]
    assert_equal 3, es_hash[:page]
    assert_equal "email.sort", es_hash[:sort_field]
    assert_equal "asc", es_hash[:sort_order]
    assert_equal( { organization_id: programs(:org_primary).id, state: Member::Status::DORMANT }, es_hash[:with])
    assert_equal( { state: Member::Status::SUSPENDED, "users.program_id": program.id }, es_hash[:without])
  end
end