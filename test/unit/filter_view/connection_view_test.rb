require_relative './../../test_helper.rb'

class ConnectionViewTest < ActiveSupport::TestCase
  def test_count # some updates need to be done
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    program.abstract_views.where(type: "ConnectionView").destroy_all
    ConnectionView::DefaultViews.create_for(program)
    connections_never_got_going_view = program.abstract_views.where(default_view: AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING).first
    active_but_behind_view = program.abstract_views.where(default_view: AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS).first
    inactive_connections_view = program.abstract_views.where(default_view: AbstractView::DefaultType::INACTIVE_CONNECTIONS).first
    drafted_connections_view = program.abstract_views.where(default_view: AbstractView::DefaultType::DRAFTED_CONNECTIONS).first
    assert_equal program.groups.where(status: Group::Status::ACTIVE).select{|grp| grp.connection_activities.size > 0}.size, active_but_behind_view.count
    assert_equal program.groups.active.select{|grp| grp.connection_activities.size > 0}.size, inactive_connections_view.count
    assert_equal program.groups.active.select{|grp| grp.connection_activities.size == 0}.size, connections_never_got_going_view.count
    assert_equal program.groups.drafted.size, drafted_connections_view.count
  end

  def test_default_views_create_for_V2
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    program.abstract_views.where(type: "ConnectionView").destroy_all
    ConnectionView::DefaultViews.create_for(program)
    connections_never_got_going_view = program.abstract_views.where(default_view: AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING).first
    active_but_behind_view = program.abstract_views.where(default_view: AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS).first
    inactive_connections_view = program.abstract_views.where(default_view: AbstractView::DefaultType::INACTIVE_CONNECTIONS).first
    drafted_connections_view = program.abstract_views.where(default_view: AbstractView::DefaultType::DRAFTED_CONNECTIONS).first
    assert_equal_hash({"params"=>{"sub_filter"=>{"not_started"=>10}, "tab"=>0}, "search_filter_key"=> 15 }, connections_never_got_going_view.filter_params_hash)
    assert_equal_hash({"params"=>{"sub_filter"=>{"active"=>0}, "search_filters"=>{"v2_tasks_status"=>"mentoring_connections_overdue"}, "tab"=>0}, "search_filter_key"=> 17}, active_but_behind_view.filter_params_hash)
    assert_equal_hash({"params"=>{"sub_filter"=>{"inactive"=>1}, "tab"=>0}, "search_filter_key"=> 16}, inactive_connections_view.filter_params_hash)
    assert_equal_hash({"params"=>{"tab"=> Group::Status::DRAFTED}, "search_filter_key"=> AbstractView::DefaultType::DRAFTED_CONNECTIONS}, drafted_connections_view.filter_params_hash)
  end

  def test_all_view
    assert_equal_unordered [ConnectionView::DefaultViews::CONNECTIONS_NEVER_GOT_GOING, ConnectionView::DefaultViews::INACTIVE_CONNECTIONS, ConnectionView::DefaultViews::ACTIVE_BEHIND_CONNECTIONS, ConnectionView::DefaultViews::DRAFTED_CONNECTIONS], ConnectionView::DefaultViews.all
  end

  def test_default_views_create_for_portal
    program = programs(:primary_portal)
    program.abstract_views.where(type: "ConnectionView").destroy_all
    assert_no_difference 'ConnectionView.count' do
      ConnectionView::DefaultViews.create_for(program)
    end
  end

end