ChronusMentorApi::Engine.routes.draw do
  namespace :api do
    namespace :v2 do
      resources :connections, except: [:new, :edit]
      resources :users, except: [:new, :edit, :show, :update] do
        collection do
          put :update_status
        end
      end
      resources :connection_profile_fields, only: [:index]
      resources :profile_fields, only: [:index]
      resources :mentoring_templates, only: [:index]
      resources :members, except: [:new, :edit] do
        collection do 
          get :get_uuid
          put :update_status
          get :profile_updates
        end
      end
    end
  end

  namespace :mobile_api do
    namespace :v1 do
      # https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS#Preflighted_requests
      match '*path' => 'basic#catch_all_options', via: [ :post, :options]
      defaults(format: :json) do
        resources :groups, only: [:show] do
          resources :tasks do
            member do
              put :set_status
              get :edit_due_date_assignee
              put :update_due_date_assignee
            end
            resources :comments, only: [:create, :destroy], controller: "tasks/comments"
          end
          resources :scraps, except: [:edit]
        end
        delete '/logout' => 'sessions#destroy', :as => :logout
        resources :users, only: [:index, :show] do
          member do
            get :dashboard
          end
        end
        resources :mentoring_templates, only: [:index]
        resources :resources, only: [:index, :show]

        resources :sessions, only: [:create] do
          collection do
            get :verify_organization
          end
        end
        resources :passwords, only: :create
        resources :messages, except: [:edit]
        resources :admin_messages, only: :create
        resources :organizations, only: [] do
          collection do
            get :setup
          end
        end
        resources :languages, only: :index do
          collection do
            put :set_member_language
          end
        end
        resources :programs, only: :index do
          collection do
            get :select
            get :enrollable_list
            get :published_list
          end
        end
        resources :mentor_requests, only: [:index, :new, :create, :update, :show]
        resources :members do
          collection do
            get :auto_complete_for_name
          end
        end
        resources :announcements, only: [:index, :show]
        resources :vanilla_calls, only: [:index]
      end
    end
  end
end
