Rails.application.routes.draw do
  get "/mobile_v2/home/verify_organization" => "mobile_v2/home#verify_organization", :as => "mobile_v2_verify_organization"
  get "/mobile_v2/home/validate_organization" => "mobile_v2/home#validate_organization", :as => "mobile_v2_validate_organization"
  get "/mobile_v2/home/fakedoor" => "mobile_v2/home#fakedoor", :as => "mobile_v2_fakedoor"
  namespace :mobile_v2 do
    match 'home/global_member_search' => 'home#global_member_search', via: [:post]
    match 'home/validate_member' => 'home#validate_member', via: [:post]
    match 'home/finish_mobile_app_login_experiment' => 'home#finish_mobile_app_login_experiment', via: [:post]
  end
end
