require_relative './../../test_helper.rb'

class FlagViewTest < ActiveSupport::TestCase
  def test_count
    program = programs(:albers)
    pending_flags_view = FlagView::DefaultViews.create_for(program)[0]
    hash = FlagView::DefaultViews::RESOLVED_FLAGS.dup
    hash.delete(:enabled_for)
    attrs = Hash[hash.to_a.map{|k, v| [k, v.call]}].merge(program_id: program.id)
    resolved_flags_view = FlagView.create!(attrs)
    flag = create_flag(content: articles(:economy))
    flag.update_attribute(:status, Flag::Status::ALLOWED)
    assert_equal program.flags.unresolved.count, pending_flags_view.count
    assert_equal program.flags.resolved.count, resolved_flags_view.count
    flag.update_attribute(:status, Flag::Status::EDITED)
    assert_equal program.flags.unresolved.count, pending_flags_view.count
    assert_equal program.flags.resolved.count, resolved_flags_view.count
    flag.update_attribute(:status, Flag::Status::DELETED)
    assert_equal program.flags.unresolved.count, pending_flags_view.count
    assert_equal program.flags.resolved.count, resolved_flags_view.count
    flag.update_attribute(:status, Flag::Status::UNRESOLVED)
    assert_equal program.flags.unresolved.count, pending_flags_view.count
    assert_equal program.flags.resolved.count, resolved_flags_view.count
  end

  def test_default_views_create_for
    program = programs(:albers)
    program.abstract_views.where(type: "FlagView").destroy_all
    pending_flags_view = FlagView::DefaultViews.create_for(program)[0]
    assert_equal_hash({:unresolved=>true}, pending_flags_view.filter_params_hash)
  end

  def test_default_views_create_for_portal
    program = programs(:primary_portal)
    program.abstract_views.where(type: "FlagView").destroy_all
    pending_flags_view = []
    assert_difference 'FlagView.count' do
      pending_flags_view = FlagView::DefaultViews.create_for(program)[0]
    end
    assert_equal_hash({:unresolved=>true}, pending_flags_view.filter_params_hash)
  end

  def test_is_accessible
    prog = programs(:albers)
    prog.enable_feature(FeatureName::FLAGGING)
    assert FlagView.is_accessible?(prog)
    disable_feature(prog, FeatureName::FLAGGING)
    assert_false FlagView.is_accessible?(prog)
  end
end