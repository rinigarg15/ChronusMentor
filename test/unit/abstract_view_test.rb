require_relative './../test_helper.rb'

class AbstractViewTest < ActiveSupport::TestCase
  def test_default
    default_abstract_view = programs(:albers).abstract_views.default.first
    assert default_abstract_view.default?
    assert_false default_abstract_view.editable?
    assert_false default_abstract_view.non_default?
    editable_view = AbstractView.create!(:program => programs(:albers), :title => "New Title", :filter_params => AbstractView.convert_to_yaml({:roles_and_status => {role_filter_1: {type: :include, :roles => nil}}}))
    assert_false editable_view.default?
    assert editable_view.editable?
  end

  def test_defaults_first
    not_default = AbstractView.create!(:program => programs(:albers), :title => "New Title", :filter_params => AbstractView.convert_to_yaml({:roles_and_status => {role_filter_1: {type: :include, :roles => nil}}}))
    programs(:albers).abstract_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS).update_column(:created_at, not_default.created_at + 1.day)
    assert_equal ['All Users', 'New Title'], AbstractView.defaults_first.map(&:title).select{|title| title == 'New Title' || title == 'All Users'}.uniq
  end

  def test_without_metrics
    programs(:albers).abstract_views.without_metrics.each do |v|
      assert_equal 0, v.metrics.count
    end
    new_metric = create_report_metric({ title: "New Mtric", description: "Dark Night Rises", abstract_view_id: programs(:albers).abstract_views.without_metrics.first.id, section_id: programs(:albers).report_sections.first.id })
    assert_false programs(:albers).abstract_views.without_metrics.include?(new_metric.abstract_view_id)
  end

  def test_is_program_view
    assert programs(:albers).abstract_views.first.is_program_view?
    assert_false programs(:org_primary).abstract_views.first.is_program_view?
  end

  def test_is_organization_view
    assert_false programs(:albers).abstract_views.first.is_organization_view?
    assert programs(:org_primary).abstract_views.first.is_organization_view?
  end

  def test_organization
    assert_equal programs(:org_primary), programs(:albers).abstract_views.first.organization
    assert_equal programs(:org_primary), programs(:org_primary).abstract_views.first.organization
  end

  def test_count
    view = AbstractView.new(type: AbstractView.name)
    error = assert_raise(RuntimeError) do
      view.count
    end
    assert_equal "AbstractView count method called, code should not reach here", error.message
  end

  def test_filter_params_hash
    view = MentorRequestView::DefaultViews.create_for(programs(:albers))[0]
    assert_equal_hash({status: AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED]}, view.filter_params_hash)
    assert_equal AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED], view.filter_params_hash[:status]
    assert_equal AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED], view.filter_params_hash["status"]
  end

  def test_without_ongoing_mentoring_style_scope
    program = programs(:albers)
    abstract_views = program.abstract_views.without_ongoing_mentoring_style
    AbstractView::DependentViews::ONGOING_MENTORING.each do |view|
      assert_false abstract_views.collect(&:type).include?(view)
    end
  end
end