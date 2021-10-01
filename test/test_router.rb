class TestRouter
  def self.load
    ChronusMentorBase::Application.routes.draw do
      namespace :dummy_application do
        get :proper_action
        get :record_not_found_action
        get :error_action
        get :invalid_auth_action
        get :invalid_authenticity_token
        get :unknown_error
        get :action_without_filters
        get :action_skipping_login
        get :org_level_action
        get :export
        get :do_redirect_action
      end

      namespace :dummy_authentication_extensions do
        get :fetch_auth_config
        get :import_data
        get :login_sections
      end

      namespace :dummy_common_controller_usages do
        get :welcome_user
        get :welcome_member
        get :new_external_user
        get :assign_external_params
        get :handle_member
      end

      namespace :dummy_connection_filters do
        get :index
        get :some_action
      end

      namespace :dummy_forum_extensions do
        get :show
        get :index
      end

      namespace :dummy_open_auth_utils do
        get :external_redirect
        get :callback_redirect
        get :validate_state
        get :open_auth_callback_params_in_session
      end

      resources :dummy_abstract_request, only: [:update] do
        member do
          get :get_status_message
        end
      end
    end
  end
end