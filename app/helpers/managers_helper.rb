module ManagersHelper
  # Differentiate between new and existing records
  def fields_for_manager(question, manager, &block)
    if manager.new_record?
      fields_for("profile_answers[#{question.id}][new_manager_attributes][]", manager, &block)
    else
      fields_for("profile_answers[#{question.id}][existing_manager_attributes][]", manager, &block)
    end
  end

  def formatted_manager_in_listing(manager)
    manager_content = manager.present? ? "#{h(manager.full_name)} (#{mail_to(manager.email)})".html_safe : ""
    content_tag(:div, raw(manager_content))
  end
end
