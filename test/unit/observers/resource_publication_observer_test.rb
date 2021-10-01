require_relative './../../test_helper.rb'

class ResourcePublicationObserverTest < ActiveSupport::TestCase
  def test_after_save
    program = programs(:albers)
    resource = create_resource(title: "Cercei Lannister", content: "Jaime Lannister")
    AdminView.any_instance.expects(:refresh_user_ids_cache).never
    program.resource_publications.create!(resource: resource, show_in_quick_links: true)

    #cache already present
    all_mentors_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTORS)
    all_mentees_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTEES)
    resource = create_resource(title: "Claire Underwood", content: "Frank Underwood")
    AdminView.any_instance.expects(:refresh_user_ids_cache).never
    program.resource_publications.create!(resource: resource, show_in_quick_links: true, admin_view_id: all_mentors_view.id)

    resource = create_resource(title: "Skyler White", content: "Skyler White")
    AdminView.any_instance.expects(:refresh_user_ids_cache).once
    program.resource_publications.create!(resource: resource, show_in_quick_links: true, admin_view_id: all_mentees_view.id)

    resource = create_resource(title: "New Title", content: "New Content")
    resource_publication = program.resource_publications.create!(resource: resource, show_in_quick_links: true)
    AdminView.any_instance.expects(:refresh_user_ids_cache).never
    resource_publication.update_attributes!(admin_view_id: all_mentors_view.id)
    AdminView.any_instance.expects(:refresh_user_ids_cache).once
    resource_publication.update_attributes!(admin_view_id: all_mentees_view.id)
  end
end