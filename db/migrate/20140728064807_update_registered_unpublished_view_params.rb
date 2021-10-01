class UpdateRegisteredUnpublishedViewParams< ActiveRecord::Migration[4.2]
  def up
    AbstractView.where(default_view: AbstractView::DefaultType::REGISTERED_BUT_NOT_ACTIVE).find_each do |abstract_view|
      abstract_view.filter_params = AbstractView.convert_to_yaml( {"roles_and_status"=>{"roles"=>"#{[RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].join(',')}", "state"=>{"pending"=>"#{User::Status::PENDING}"}, "signup_state"=>{"signed_up_users"=>"#{AdminView::RolesStatusQuestions::SIGNED_UP}"}}, "connection_status"=>{"status"=>"", "draft_status"=>"", "availability"=>{"operator"=>"", "value"=>""}, "meeting_requests"=>{"request_1"=>{"question"=>"", "operator"=>"", "value"=>"", "start_value"=>"", "end_value"=>""}}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} )
      abstract_view.save!
    end
  end

  def down
    AbstractView.where(default_view: AbstractView::DefaultType::REGISTERED_BUT_NOT_ACTIVE).find_each do |abstract_view|
      abstract_view.filter_params = AbstractView.convert_to_yaml( {"roles_and_status"=>{"roles"=>"#{[RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].join(',')}", "signup_state"=>{"added_not_signed_up_users"=>"#{AdminView::RolesStatusQuestions::ADDED_NOT_SIGNED_UP}"}}, "connection_status"=>{"status"=>"", "draft_status"=>"", "availability"=>{"operator"=>"", "value"=>""}, "meeting_requests"=>{"request_1"=>{"question"=>"", "operator"=>"", "value"=>"", "start_value"=>"", "end_value"=>""}}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}} )
      abstract_view.save!
    end
  end
end
