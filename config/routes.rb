ChronusMentorBase::Application.routes.draw do
  filter :program_prefix
  mount Ckeditor::Engine => '/ckeditor'
  mount ChronusMentorApi::Engine => "/"
  mount Split::Dashboard, :at => 'split'
  mount Split::Countersdashboard, :at => 'splitcounters'
  match "/dj/delayed_job" => DelayedJobWeb, :anchor => false, via: [:get, :post]
  match 'feedbacks' => 'feedbacks#create', :as => :feedback, via: [:post]
  match 'feedbacks/new' => 'feedbacks#new', :as => :new_feedback, via: [:get]
  root :to => 'home#default', :constraints => {:subdomain => /^#{DEFAULT_SUBDOMAIN}$/, :domain => /^#{DEFAULT_DOMAIN_NAME}$/}
  match '/' => 'demo_programs#new', :constraints => {:subdomain => /^#{DEFAULT_DEMO_SUBDOMAIN}$/, :domain => /^#{DEFAULT_DOMAIN_NAME}$/}, via: [:get]
  match '/orgs' => 'home#organizations', :as => :organizations, via: [:get]
  match '/deactivate' => 'home#deactivate', :as => :deactivate, via: [:get]
  match '/new_theme' => 'themes#new_theme', :as => :automate_theme, via: [:get]
  match '/csreport' => 'home#csreport', :as => :csreport, via: [:get]
  match '/inline_edit_organizations' => 'home#inline_edit_organizations', via: [:post]
  match '/feature_report' => 'home#feature_report', :as => :feature_report, via: [:get]
  match '/export_admins' => 'home#export_admins', :as => :export_admins, via: [:get]
  match '/solution_packs' => 'home#solution_packs', :as => :solution_packs, via: [:get]
  match '/upgrade_browser' => 'home#upgrade_browser', :as => :upgrade_browser, via: [:get]
  match '/notify_new_timezone' => 'home#notify_new_timezone', :as => :notify_new_timezone, via: [:get]
  match '/incoming_mails' => 'incoming_mails#create', constraints: { subdomain: /^#{EMAIL_HOST_SUBDOMAIN}$/, domain: /^#{DEFAULT_DOMAIN_NAME}$/ }, via: [:post]
  match 'users/bulk_match' => 'bulk_matches#bulk_match', :as => :bulk_match, via: [:get]
  match 'users/bulk_recommendation' => 'bulk_recommendations#bulk_recommendation', :as => :bulk_recommendation, via: [:get]
  match '/calendar_sync_instructions' => 'meetings#get_calendar_sync_instructions_page', :as => :calendar_sync_instructions, via: [:get]
  match 'users/new_user_with_invite' => 'registrations#new', via: [:get] # For backward compatibility
  match 'membership_requests/new' => 'membership_requests#new', via: [:post]

  match '/mailgun_webhook_handlers' => 'mailgun_webhook_handlers#handle_events', constraints: { subdomain: /^#{EMAIL_HOST_SUBDOMAIN}$/, domain: /^#{DEFAULT_DOMAIN_NAME}$/ }, via: [:post]
  # Mailgun was initially wrongly configured to use the subdomain 'productioneu' instead of EMAIL_HOST_SUBDOMAIN
  # To support older mails which have links of 'productioneu' subdomain, the below route is necessary.
  if Rails.env.productioneu?
    match '/mailgun_webhook_handlers' => 'mailgun_webhook_handlers#handle_events', constraints: { subdomain: /^productioneu$/, domain: /^#{DEFAULT_DOMAIN_NAME}$/ }, via: [:post]
  end

  # outlook and office365 don't allow subdomain in redirect url for localhost. This is a workaround for that.
  # match '/authorize_outlook' => 'o_auth_credentials#redirect_to_secure', via: [:get]

  get '/o_auth_credentials/redirect'
  get '/o_auth_credentials/callback'
  get '/o_auth_credentials/disconnect'

  resources :group_checkins, path: 'group_checkins'

  resources :file_uploads, only: [:create]

  resources :sanitizations, :only => :none do
    collection do
      post :preview_sanitized_content
      post :compare_content_before_and_after_sanitize
    end
  end

  resources :translations, only: [:index, :update] do
    collection do
      get :show_category_content
      get :expand_category
      get :edit_content
      get :export_csv
      post :import_csv
      post :update_content
      post :update_images
    end
  end

  namespace :campaign_management do
    resources :user_campaigns, :program_invitation_campaigns, :survey_campaigns do
      collection do
        get :export_csv
        post :import_csv
      end
      member do
        get :clone_popup
        post :clone
        patch :start
        get :disable
        get :details
      end
      resources :abstract_campaign_messages do
        collection do
          get :auto_complete_for_name
          post :send_test_email
        end
      end
    end
  end

  resources :mentoring_models do
    member do
      post :upload_from_templates
      get :setup
      post :create_template_objects
      # The below actions, duplicate_new and duplicate_create, are actually there to build the duplicate templates feature.
      # These should not be mistaken to be the "duplicate" actions of the new/create :)
      get :duplicate_new
      post :duplicate_create
      post :make_default
      get :export_csv
      get :view
      patch :update_duration
      get :preview
      get :fetch_tasks
    end
    resources :task_templates, controller: "mentoring_model/task_templates" do
      member do
        post :update_positions
      end

      collection do
        patch :check_chronological_order_is_maintained
      end
    end
    resources :goal_templates, controller: "mentoring_model/goal_templates"
    resources :facilitation_templates, controller: "mentoring_model/facilitation_templates" do
      collection do
        post :preview_email
      end
    end
    resources :milestone_templates, controller: "mentoring_model/milestone_templates", except: [:index] do
      collection do
        patch :reorder_milestones
        get :validate_milestones_order
      end
    end
  end

  resources :goal_templates, controller: "program/goal_templates"

  namespace :report do
    resources :sections, only: [] do
      resources :metrics, except: :index do
        resources :alerts, except: :index
      end
    end
  end

  resources :members do
    collection do
      get :auto_complete_for_name
      get :auto_complete_for_name_or_email
      post :invite_to_program
      get :account_lockouts
      get :answer_mandatory_qs
      patch :update_mandatory_answers
    end
    member do
      get :get_invite_to_program_roles
      patch :update_answers
      post :reactivate_account
      patch :update_state
      post :add_member_as_admin
      patch :update_settings
      patch :update_notifications
      get :destroy_prompt
      post :upload_answer_file
      patch :update_time_zone
      patch :skip_answer
      get :fill_section_profile_detail
    end
    resource :profile_picture, :only => [:create, :edit, :update] do
      member do
        get :crop
      end
    end
    resources :mentoring_slots
  end

  resources :themes do
    member do
      get :global_confirm_popup
    end
  end
  resources :resources do
    collection do
      patch :reorder
    end
    member do
      get :rate
      get :show_question
    end
  end

  resources :coverages do
    collection do
      get :get_coverage
    end
  end

  resources :explicit_user_preferences do
    collection do
      delete :bulk_destroy
    end
    member do
      patch :change_weight
    end
  end

  resources :organization_admins
  resources :pages do
    member do
      patch :publish
    end
    collection do
      post :sort
      get :programs
      get :programs_reordering
      patch :reorder_programs
      get :mobile_prompt
    end
  end

  resources :sections
  resources :passwords
  resources :api_tests, :only => [:index]
  resource :session do
    collection do
      get :refresh
      get :zendesk
      post :register_device_token
      get :oauth_callback
    end
  end

  resources :locations do
    collection do
      get :get_filtered_locations_for_autocomplete
    end
  end

  resources :registrations do
    collection do
      get :new_admin
      post :new_admin
      post :create_admin
      get :terms_and_conditions_warning
      patch :accept_terms_and_conditions
      post :create_enrollment
    end
  end

  resources :chronus_sessions, :only => [:new, :create, :destroy]
  resources :match_configs do
    collection do
      get :play
      get :compute_fscore
      get :question_template
      post :refresh_scores
      get :question_choices
    end
  end

  resources :membership_requests, :except => [:destroy, :show] do
    collection do
      post :bulk_update
      post :new_bulk_action
      get :select_all_ids
      get :export
      post :export
      get :signup_instructions
      post :apply
      get :resend_signup_mail
      get :signup_options
    end
  end

  resources :groups do
    collection do
      post :assign_from_match
      get :assign_match_form
      get :save_as_draft
      get :fetch_bulk_actions
      post :fetch_bulk_actions
      post :update_bulk_actions
      post :edit_columns
      get :select_all_ids
      get :index_mobile
      get :mobile_connections_badge_count
      get :find_new
      get :fetch_survey_questions
      get :fetch_survey_answers
      get :fetch_custom_task_status_filter
      get :reset_task_options_for_custom_task_status_filter
      get :auto_complete_for_name
      get :get_similar_circles
    end
    member do
      get :edit_answers
      get :more_activities
      get :export
      get :profile
      get :leave_connection
      get :fetch_notes
      get :setup_meeting
      get :fetch_terminate
      get :fetch_reactivate
      get :fetch_publish
      get :fetch_discard
      get :fetch_withdraw
      get :set_expiry_date
      get :get_activity_details
      get :add_members
      patch :add_new_member
      patch :remove_new_member
      patch :replace_member
      patch :update_notes
      patch :update_expiry_date
      patch :reactivate
      patch :update_answers
      patch :publish
      patch :discard
      patch :withdraw
      patch :update_members
      get :update_view_mode_filter
      get :fetch_owners
      patch :update_owners
      get :survey_response
      get :get_users_of_role
      get :edit_join_settings
      patch :update_join_settings
      get :clone
      get :get_edit_start_date_popup
    end
    namespace :mentoring_model do
      resources :goals do
        resources :activities, only: [:create, :new]
      end
      resources :milestones do
        member do
          get :fetch_tasks
        end
        collection do
          get :fetch_completed_milestones
        end
      end
      resources :tasks do
        member do
          post :set_status
          get :setup_meeting
          post :update_positions
          get :edit_assignee_or_due_date
          patch :update_assignee_or_due_date
        end
        collection do
          get :fetch_section_tasks
        end
      end
    end
    resources :tasks, :except => :index
    resources :scraps do
      collection do
        get :get_scraps_for_homepage
      end
    end
    resources :coaching_goals do
      member do
        get :more_activities
      end
      resources :coaching_goal_activities, :only => [:new, :create]
    end
    resources :connection_private_notes, :controller => "connection/private_notes"
  end

  resources :abstract_messages do
    member do
      get :show_receivers
      get :show_detailed
      get :show_collapsed
    end
  end
  resources :admin_messages do
    collection do
      post :new_bulk_admin_message
    end
  end
  resources :messages
  resources :questions do
    collection do
      post :sort
      post :update_profile_summary_fields
    end
  end

  resources :profile_questions do
    collection do
      get :preview
      get :export
      post :import
    end
    member do
      post :update_for_all_roles
      get :get_role_question_settings
    end
  end
  resource :profile_question do
    get :get_conditional_options
    patch :update_profile_question_section
  end

  resources :role_questions do
    collection do
      post :update_profile_summary_fields
    end
  end

  resources :meetings do
    member do
      get :update_from_guest, :get_destroy_popup, :edit_state, :update_state, :survey_response
    end
    collection do
      get :mini_popup, :select_meeting_slot, :validate_propose_slot, :new_connection_widget_meeting
      post :valid_free_slots
      post :valid_free_slots_for_range
    end
    resources :scraps
    resources :private_meeting_notes
  end

  resources :meeting_requests, only: [:index, :new, :create] do
    member do
      get :update_status
      get :propose_slot_popup
      post :update_status
      post :reject_with_notes
    end
    collection do
      get :manage
      post :manage
      get :select_all_ids
      post :fetch_bulk_actions
      post :update_bulk_actions
    end
  end

  resources :flags do
    collection do
      get :content_related
    end
  end
  resources :program_events do
    member do
      get :more_activities
      get :update_invite
      get :update_reminder
      post :publish
      post :add_new_invitees
    end
    collection do
      post :send_test_emails
    end
  end
  resources :event_invites

  resources :bulk_matches do
    collection do
      get :bulk_match
      get :update_bulk_match_pair
      get :fetch_summary_details
      get :fetch_settings
      get :update_settings
      get :preview_view_details
      get :fetch_notes
      get :alter_pickable_slots
      get :refresh_results
      get :groups_alert
      get :change_match_orientation
      post :bulk_update_bulk_match_pair
      post :update_notes
      post :export_all_pairs
      post :export_csv
    end
  end

  resources :bulk_recommendations do
    collection do
      get :fetch_settings
      get :update_settings
      get :refresh_results
      get :fetch_summary_details
      get :alter_pickable_slots
      get :update_bulk_recommendation_pair
      post :bulk_update_bulk_recommendation_pair
    end
  end

  resources :languages do # TODO Why not in engine?
    collection do
      #we are doing both put and get, because, if opened in new tab, the method taken will be get and not put
      patch :set_current
      get :set_current
      patch :set_current_non_org
      get :set_current_non_org
    end
  end

  resources :app_documents

  resources :demo_programs, only: [:create, :new] do
    collection do
      get :check_status
    end
  end

  resources :organization_languages, except: [:update, :create, :destroy] do# TODO Why not in engine?
    collection do
      post :update_status
    end
  end

  resources :data_imports
  resources :customized_terms do
    collection do
      patch :update_all
    end
  end
  resources :scraps do
    member do
      get :reply
    end
  end
  namespace :mentoring_model do
    namespace :task do
      resources :comments, only: [:create, :destroy]
    end
  end
  match '/about' => 'pages#index', :as => :about, via: [:get]
  delete '/logout' => 'sessions#destroy', :as => :logout
  get '/saml_slo' => 'sessions#saml_slo', :as => :saml_slo
  match '/login' => 'sessions#new', :as => :login, via: [:get]
  match '/forgot_password' => 'passwords#new', :as => :forgot_password, via: [:get]
  match '/change_password' => 'passwords#reset', :as => :change_password, via: [:get]
  match '/update_password' => 'passwords#update_password', :as => :update_with_reset_code, :via => [:post]
  match '/new_program' => 'programs#new', :as => :new_program, via: [:get]
  match '/programs' => 'programs#create', :as => :create_program, :via => [:post]
  match '/terms' => 'home#terms', :as => :terms, via: [:get]
  match '/privacy_policy' => 'home#privacy_policy', :as => :privacy_policy, via: [:get]
  match '/handle_redirect' => 'home#handle_redirect', :as => :handle_redirect, via: [:get]
  match '/new_member_auto_complete_field' => 'groups#new_member_auto_complete_field', :as => :new_member_auto_complete_field, via: [:get]
  match '/sl' => 'chronus_sessions#new', :as => :super_login, :via => [:get]
  delete '/slout' => 'chronus_sessions#destroy', :as => :super_logout
  match '/users/new_mentor_followup' => 'users#new_user_followup', :as => :new_mentor_followup, via: [:get]
  match '/account_settings' => 'members#account_settings', :as => :account_settings, via: [:get]
  match '/search' => 'programs#search', :as => :search, via: [:get]
  match '/mentor_handbook' => 'handbooks#show', :as => :mentor_handbook, :role => RoleConstants::MENTOR_NAME, via: [:get]
  match '/student_handbook' => 'handbooks#show', :as => :student_handbook, :role => RoleConstants::STUDENT_NAME, via: [:get]
  match '/import_linkedin_data' => 'linkedin_import#data', :as => :import_linkedin_data, :via => [:post]
  match '/linkedin_callback' => 'linkedin_import#callback', :as => :linkedin_callback, via: [:get]
  match '/linkedin_callback_success' => 'linkedin_import#callback_success', :as => :linkedin_callback_success, via: [:get]
  match '/linkedin_login' => 'linkedin_import#login', :as => :linkedin_login, via: [:get]
  match '/contact_admin' => 'admin_messages#new', :as => :contact_admin, via: [:get]
  match '/mentoring_sessions' => 'meetings#mentoring_sessions', :as => :mentoring_sessions, via: [:get, :post]
  match '/calendar_sessions' => 'meetings#calendar_sessions', :as => :calendar_sessions, via: [:get, :post]
  match '/all_users' => 'admin_views#show', :as => :admin_view_all_users, :default_view => AbstractView::DefaultType::ALL_USERS, via: [:get]
  match '/mentors' => 'admin_views#show', :as => :admin_view_mentors, :default_view => AbstractView::DefaultType::MENTORS, via: [:get]
  match '/mentees' => 'admin_views#show', :as => :admin_view_students, :default_view => AbstractView::DefaultType::MENTEES, via: [:get]
  match '/teachers' => 'admin_views#show', :as => :admin_view_teachers, :default_view => AbstractView::DefaultType::TEACHERS, via: [:get]
  match '/employees' => 'admin_views#show', :as => :admin_view_employees, :default_view => AbstractView::DefaultType::EMPLOYEES, via: [:get]
  match '/all_members' => 'admin_views#show', :as => :admin_view_all_members, :default_view => AbstractView::DefaultType::ALL_MEMBERS, via: [:get]
  match '/active_licenses' => 'admin_views#show', as: :admin_view_active_licenses, default_view: AbstractView::DefaultType::LICENSE_COUNT, via: [:get]
  match '/admins' => 'admin_views#show', :as => :admin_view_all_admins, :default_view => AbstractView::DefaultType::ALL_ADMINS, via: [:get]
  match '/build_new' => 'themes#build_new', :as => :build_new_themes, via: [:post]
  match 'membership_requests/filter_index' => 'membership_requests#index', :as => :filter_membership_requests, via: [:post] # For Filters

  #For ICS calendar accessed via API call and export all meetings
  match '/calendar/:calendar_api_key/event.:format' => 'meetings#ics_api_access', :as => :api_access_ics_calendar, via: [:get]

  match '/calendar_sync' => 'meetings#update_meeting_notification_channel', :as => :calendar_sync, via: [:post]
  match '/calendar_rsvp' => 'meetings#calendar_rsvp', :as => :calendar_rsvp, via: [:post]
  match '/calendar_rsvp_program_event' => 'program_events#calendar_rsvp_program_event', :as => :calendar_rsvp_program_event, via: [:post]

  with_options(organization_level: true, constraints: SubProgram::OrganizationLevelConstraint.new) do |organization|
    organization.match '/' => 'organizations#show', :as => :root_organization, via: [:get]
    organization.match '/get_global_dashboard_program_info_box_stats' => 'organizations#get_global_dashboard_program_info_box_stats', as: :get_global_dashboard_program_info_box_stats, via: [:get]
    organization.match '/get_global_dashboard_org_current_status_stats' => 'organizations#get_global_dashboard_org_current_status_stats', as: :get_global_dashboard_org_current_status_stats, via: [:get]
    organization.match '/edit' => 'organizations#edit', :as => :edit_organization, via: [:get]
    organization.match '/update' => 'organizations#update', :as => :update_organization, :via => [:patch]
    organization.match '/manage' => 'organizations#manage', :as => :manage_organization, via: [:get]
    organization.match '/inactive' => 'organizations#inactive', :as => :inactive_organization, via: [:get]
    organization.match '/enrollment' => 'organizations#enrollment', :as => :enrollment, via: [:get]
    organization.match '/enrollment_popup' => 'organizations#enrollment_popup', :as => :enrollment_popup, via: [:get]
  end

  namespace :career_dev do
    resources :portals
  end

  namespace :three_sixty do
    resources :competencies
    resources :questions do
      collection do
        post :create_and_add_to_survey
      end
    end
    resources :surveys do
      member do
        get :add_questions
        get :add_assessees
        get :preview
        patch :publish
        patch :reorder_competencies
      end
      collection do
        get :dashboard
      end
      resources :assessees, :controller => "survey_assessees" do
        member do
          get :add_reviewers
          get :notify_reviewers
          delete :destroy_published
          get :survey_report
        end
        resources :reviewers, :controller => "survey_reviewers" do
          collection do
            get :show_reviewers
            post :answer
          end
        end
      end
      resources :competencies, :controller => "survey_competencies" do
        member do
          patch :reorder_questions
        end
      end
      resources :questions, :controller => "survey_questions"
    end
    resources :reviewer_groups
    match 'my_surveys' => 'survey_assessees#index', :as => :my_surveys, via: [:get]
  end

  resources :users, :except => [:update] do
    collection do
      post :create_from_other_program
      get :hide_item
      get :matches_for_student
      get :new_user_followup
      get :mentoring_calendar
      get :auto_complete_for_name
      get :auto_complete_user_name_for_meeting
      get :new_from_other_program
      get :select_all_ids
      post :bulk_confirmation_view
      get :new_preference
      get :validate_email_address
      get :add_user_options_popup
    end
    member do
      post :work_on_behalf
      post :change_user_state
      get :edit_answers
      get :fetch_change_roles
      post :change_roles
      post :add_role
      get :add_role_popup
      patch :update_tags
      get :destroy_prompt
      get :hovercard
      get :reviews
      get :pending_requests_popup
      get :match_details
      get :favorite_mentors
    end
  end

  resources :admin_views, :except => [:index] do
    member do
      get :toggle_favourite
      get :select_all_ids
      get :get_invite_to_program_roles
      get :on_remove_user_completion
      post :remove_user
      post :suspend_membership
      post :reactivate_membership
      post :add_role
      post :add_or_remove_tags
      post :export_csv
      post :bulk_confirmation_view
      post :invite_to_program
      post :add_to_program
      post :resend_signup_instructions
      post :suspend_member_membership
      post :reactivate_member_membership
      post :remove_member
    end
    collection do
      get :get_add_to_program_roles
      get :auto_complete_for_name
      get :fetch_admin_view_details
      get :preview_view_details
      get :locations_autocomplete
      get :fetch_survey_questions
      get :bulk_add_users_to_project
    end
  end

  resources :announcements do
    member do
      get :mark_viewed
    end
    collection do
      post :send_test_emails
    end
  end

  resources :mentor_requests do
    collection do
      get :select_all_ids
      post :fetch_bulk_actions
      post :update_bulk_actions
      post :export
      get :manage
      post :manage
    end
  end

  resources :project_requests do
    collection do
      get :manage
      post :manage
      get :select_all_ids
      post :fetch_actions
      post :update_actions
    end
  end

  resources :mentor_offers do
    collection do
      get :select_all_ids
      post :fetch_bulk_actions
      post :update_bulk_actions
      post :export
      get :manage
      post :manage
    end
  end

  resources :mentoring_tips do
    collection do
      post :update_all
    end
  end

  resources :qa_questions do
    member do
      post :follow
    end
    resources :qa_answers do
      member do
        post :helpful
      end
    end
  end

  resources :articles do
    collection do
      get :auto_complete_for_title
      get :new_list_item
    end
    member do
      post :rate
    end
    resources :comments
  end

  resources :forums do
    member do
      get :subscription
    end
    resources :topics, except: [:new] do
      member do
        post :follow
        post :set_sticky_position
        get :fetch_all_comments
        get :mark_viewed
      end
      resources :posts do
        member do
          post :moderate_publish
          get :moderate_decline
        end
      end
    end
  end

  resources :user_favorites do
    collection do
      post :sort
    end
  end

  resources :ignore_preferences, :only => [:create, :destroy]
  resources :favorite_preferences, :only => [:create, :destroy, :index]

  resources :one_time_flags
  resources :membership_request_instructions, :controller => "membership_request/instructions" do
    collection do
      get :get_instruction_form
    end
  end
  resources :mentor_request_instructions, :controller => "mentor_request/instructions"
  resources :contact_admin_settings, :only => [:create, :index, :update]
  resources :surveys do
    member do
      get :publish
      get :report
      post :report
      get :edit_answers
      patch :update_answers
      post :clone
      get :destroy_prompt
      get :edit_columns
      get :export_questions
      get :reminders
    end
    resources :survey_questions, :except => [:edit] do
      collection do
        patch :sort
      end
    end
    resources :responses, :except => [:new, :create, :edit, :update, :delete], :controller => "survey_responses" do
      collection do
        get :data
        get :select_all_ids
        post :download
        post :email_report
        get :email_report_popup
        get :export_as_xls
      end
      member do
        post :email_response
      end
    end
  end

  resources :confidentiality_audit_logs
  resources :membership_questions do
    collection do
      post :sort
      get :update_role_questions
      get :preview
    end
  end

  resources :connection_questions, :controller => "connection/questions" do
    collection do
      patch :sort
    end
  end

  resources :program_invitations, only: [:index, :create, :new] do
    collection do
      get :select_all_ids
      post :bulk_confirmation_view
      post :bulk_update
      delete :bulk_destroy
      post :export_csv
    end
  end
  resources :feedback_responses, :controller => 'feedback/responses'

  resources :mailer_templates do
    member do
      patch :update_status
      post :preview_email
    end

    collection do
      get :category_mails
    end
  end

  resources :rollout_emails do
    member do
      get :rollout_popup
      post :rollout_keep_current_content
      post :rollout_switch_to_default_content
      post :rollout_dismiss_popup_by_admin
    end
    collection do
      patch :update_all
      patch :dismiss_rollout_flash_by_admin
    end
  end

  resources :mailer_widgets
  resources :progress_statuses, :only => [:show]

  resources :group_views, :only => [:update]
  resources :ck_attachments, :only => [:show]
  resources :ck_pictures, :only => [:show]
  resources :ab_tests, :only => [:index] do
    collection do
      post :update_for_program
    end
  end

  resources :csv_imports, :only => [:new, :create, :edit, :update, :destroy] do
    member do
      get :validation_information
      get :validation_data_popup
      get :import_data
      get :completed
      get :records
      get :map_csv_columns
      post :create_mapping
    end
    collection do
    end
  end

  resources :auth_configs, only: [:index, :edit, :update, :destroy] do
    member do
      get :edit_password_policy
      patch :update_password_policy
      patch :toggle
    end
  end
  resources :auth_config_settings, only: [:index, :update]
  namespace :saml_auth_config do
    get :saml_sso
    get :generate_sp_metadata
    get :download_idp_metadata
    get :download_idp_certificate
    post :upload_idp_metadata
    post :setup_authconfig
    post :update_certificate
  end

  namespace :engagement_index do
    post :track_activity
  end

  resources :global_reports do
    collection do
      get :overall_impact
      post :overall_impact
      get :overall_impact_survey_satisfaction_configurations
      get :edit_overall_impact_survey_satisfaction_configuration
      put :update_overall_impact_survey_satisfaction_configuration
    end
  end
  resources :diversity_reports

  resources :reports, only: [:index] do
    collection do
      get :categorized
    end
  end

  resources :dashboard_report_sub_sections, only: [] do
    collection do
      get :tile_settings
      post :update_tile_settings
      get :scroll_survey_responses
    end
  end

  resources :match_reports, :only => [:index] do
    collection do
      get :edit_section_settings
      patch :update_section_settings
      get :preview_view_details
      get :show_discrepancy_graph_or_table
      get :get_discrepancy_table_data
      get :refresh_top_mentor_recommendations
    end
  end

  resources :preference_based_mentor_lists, only: [:index] do
    collection do
      put :ignore
    end
  end

  match '/invite_users' => 'program_invitations#new', :as => :invite_users, via: [:get]
  match '/view_other_invitations' => 'program_invitations#index', :as => :view_other_invitations, :other_invitations => true, via: [:get]
  match '/exit_wob' => 'users#exit_wob', :as => :exit_wob, :via => [:post]
  match '/send_invites' => 'program_invitations#create', :as => :send_invites, :via => [:post]
  match '/manage' => 'programs#manage', :as => :manage_program, via: [:get]
  match '/edit' => 'programs#edit', :as => :edit_program, via: [:get]
  match '/update' => 'programs#update', :as => :update_program, via: [:patch]
  match '/disable_profile_update_prompt' => 'programs#disable_profile_update_prompt', :as => :disable_profile_update_prompt, via: [:get]
  match '/ar/:code' => 'membership_requests#index', :as => :approve_requests, :code => nil, via: [:get]
  match 'surveys/:id/participate' => 'surveys#edit_answers', :as => :participate_survey, :id => nil, via: [:get]
  match '/reports/executive_summary' => 'reports#executive_summary', :as => :executive_summary, via: [:get, :post]
  match '/reports/health_report' => 'reports#health_report', :as => :health_report, via: [:get, :post]
  match '/reports/management_report' => 'reports#management_report', :as => :management_report, via: [:get, :post]
  match '/reports/management_report_async_loading' => 'reports#management_report_async_loading', :as => :management_report_async_loading, via: [:get, :post]
  match '/match_reports/match_report_async_loading' => 'match_reports#match_report_async_loading', :as => :match_report_async_loading, via: [:get, :post]
  match '/reports/filter_management_report' => 'reports#filter_management_report', :as => :filter_management_report, via: [:get, :post]
  match '/reports/outcomes_report' => 'reports#outcomes_report', :as => :outcomes_report, via: [:get, :post]
  match '/reports/detailed_user_outcomes_report' => 'reports#detailed_user_outcomes_report', :as => :detailed_user_outcomes_report, via: [:get, :post]
  match '/reports/detailed_connection_outcomes_report' => 'reports#detailed_connection_outcomes_report', :as => :detailed_connection_outcomes_report, via: [:get, :post]
  match '/reports/groups_report' => 'reports#groups_report', :as => :groups_report, via: [:get, :post]
  match '/reports/activity_report' => 'reports#activity_report', :as => :activity_report, via: [:get, :post]
  match '/reports/demographic_report' => 'reports#demographic_report', :as => :demographic_report, via: [:get, :post]
  match '/reports/edit_groups_report_view' => 'reports#edit_groups_report_view', :as => :edit_groups_report_view, :via => [:get, :post]
  match '/report/alerts/get_filters' => 'report/alerts#get_filters', :as => :get_filters_report_alert, :via => [:get, :post]
  match '/report/alerts/get_options' => 'report/alerts#get_options', :as => :get_options_report_alert, :via => [:get, :post]
  match '/reactivate_account' => 'passwords#reactivate_account', :as => :reactivate_account, via: [:get]
  match '/' => 'programs#show', :as => :program_root, via: [:get]
  match '/programs' => 'programs#index', :as => :programs_list, :constraints => {:subdomain => /^#{DEFAULT_SUBDOMAIN}$/}, via: [:get]
  match '/programs' => 'programs#index', via: [:get]
  match '/edit_analytics' => 'programs#edit_analytics', :as => :edit_analytics, via: [:get]
  match '/update_analytics' => 'programs#update_analytics', :as => :update_analytics, :via => [:patch]
  match '/get_program_ra' => 'programs#show_activities', :as => :get_program_ra, :via => [:get]
  match '/get_organization_ra' => 'organizations#show_activities', :as => :get_organization_ra, :via => [:get]
  match '/announcements_widget' => 'programs#announcements_widget', :as => :announcements_widget, :via => [:get]
  match '/update_prog_home_tab_order' => 'programs#update_prog_home_tab_order', :as => :update_prog_home_tab_order, :via => [:get]
  match '/quick_connect_box' => 'programs#quick_connect_box', :as => :quick_connect_box, :via => [:get]
  match '/home_page_widget' => 'programs#home_page_widget', :as => :home_page_widget, :via => [:get]
  match '/mentoring_connections_widget' => 'programs#mentoring_connections_widget', :as => :mentoring_connections_widget, :via => [:get]
  match '/mentoring_community_widget' => 'programs#mentoring_community_widget', :as => :mentoring_community_widget, :via => [:get]
  match '/flash_meetings_widget' => 'programs#flash_meetings_widget', :as => :flash_meetings_widget, :via => [:get]
  match '/publish_circles_widget' => 'programs#publish_circles_widget', :as => :publish_circles_widget, :via => [:get]
  match '/remove_circle_from_publish_circle_widget' => 'programs#remove_circle_from_publish_circle_widget', :as => :remove_circle_from_publish_circle_widget, :via => [:get]
  match '/meeting_feedback_widget' => 'programs#meeting_feedback_widget', :as => :meeting_feedback_widget, :via => [:get]
  match '/unsubscribe_from_weekly_update_mail' => 'programs#unsubscribe_from_weekly_update_mail', :as => :unsubscribe_from_weekly_update_mail, :via => [:get]
  match '/moderatable_posts' => 'posts#moderatable_posts', :as => :moderatable_posts, :via => [:get]
  match '/update_three_sixty_settings' => 'organizations#update_three_sixty_settings', :via => [:post]
  match '/deactivated' => 'organizations#deactivate', :as => :deactivate_organization, :via => [:post]
  match '/program_edit' => "programs#edit", :constraints => {:subdomain => /^#{DEFAULT_SUBDOMAIN}$/, :domain => /^#{DEFAULT_DOMAIN_NAME}$/}, via: [:get]
  match '/export_solution_pack' => 'programs#export_solution_pack', via: [:post]
  match '/documents' => 'app_documents#index', :as => :documents, via: [:get, :post]

  match '/outcomes_report/detailed_users_outcomes_report_data' => 'outcomes_report#detailed_users_outcomes_report_data', :as => :detailed_users_outcomes_report_data, via: [:get]
  match '/outcomes_report/detailed_connection_outcomes_report_group_data' => 'outcomes_report#detailed_connection_outcomes_report_group_data', :as => :detailed_connection_outcomes_report_group_data, via: [:get]
  match '/outcomes_report/detailed_connection_outcomes_report_user_data' => 'outcomes_report#detailed_connection_outcomes_report_user_data', :as => :detailed_connection_outcomes_report_user_data, via: [:get]

  # Outcomes Report Paths
  [
    {key: :user_outcomes_report}, {key: :connection_outcomes_report}, {key: :update_positive_outcomes_options, method: :post},
    {key: :positive_outcomes_options_popup}, {key: :meeting_outcomes_report}, {key: :filter_users_on_profile_questions}, {key: :get_filtered_users, method: :post}, {key: :detailed_connection_outcomes_report_non_table_data}
  ].each do |info|
    match "/outcomes_report/#{info[:key]}" => "outcomes_report##{info[:key]}", as: info[:key], via: (info[:method] || :get)
  end

  if Rails.env.test?
    require "#{Rails.root}/test/test_router"
    TestRouter.load
  end
end
