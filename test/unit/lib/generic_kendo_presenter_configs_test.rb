require_relative './../../test_helper.rb'

class GenericKendoPresenterConfigsTest  < ActiveSupport::TestCase
  def test_program_invitations_grid_filter_settings
    config = GenericKendoPresenterConfigs::ProgramInvitationGrid::CONFIG
    attributes_config = config[:attributes]
    assert attributes_config[:sent_to][:filterable]
    assert attributes_config[:expires_on][:filterable]
    assert attributes_config[:sent_on][:filterable]
    assert attributes_config[:statuses][:filterable]
    assert attributes_config[:roles_name][:filterable]
    assert attributes_config[:sender][:filterable]
  end

  def test_program_invitations_grid_field_types
    config = GenericKendoPresenterConfigs::ProgramInvitationGrid::CONFIG
    attributes_config = config[:attributes]

    assert_equal :string, attributes_config[:sent_to][:type]
    assert_equal :datetime, attributes_config[:expires_on][:type]
    assert_equal :datetime, attributes_config[:sent_on][:type]
    assert_nil attributes_config[:statuses][:type]
    assert_nil attributes_config[:roles_name][:type]
    assert_nil attributes_config[:sender][:type]
  end

  def test_program_invitations_grid_custom_filters_and_sorts
    config = GenericKendoPresenterConfigs::ProgramInvitationGrid::CONFIG
    attributes_config = config[:attributes]

    ProgramInvitation::KendoScopes.expects(:status_filter)
    attributes_config[:statuses][:custom_filter].call("x")

    ProgramInvitation::KendoScopes.expects(:roles_filter)
    attributes_config[:roles_name][:custom_filter].call("x")

    ProgramInvitation::KendoScopes.expects(:sender_filter)
    attributes_config[:sender][:custom_filter].call("x")

    ProgramInvitation::KendoScopes.expects(:sender_sort)
    attributes_config[:sender][:custom_sort].call("x")

    ProgramInvitation::KendoScopes.expects(:roles_sort)
    attributes_config[:roles_name][:custom_sort].call("x")
  end

  def test_get_config_should_return_default_scope_based_on_sent_by_admin_param
    program = programs(:albers)
    config = GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(program)
    assert_equal [program_invitations(:student).id], config[:default_scope].collect(&:id)

    config = GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(program, true)
    assert_equal [program_invitations(:mentor).id], config[:default_scope].collect(&:id)    
  end
end