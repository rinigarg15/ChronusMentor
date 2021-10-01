# bundle exec rake single_time:reset_terms_and_conditions_acceptance DOMAIN='' SUBDOMAIN=''
namespace :single_time do
desc 'reset terms and conditions acceptance flag for all members'
  task :reset_terms_and_conditions_acceptance => :environment do
    GDPR_ROLLOUT_DATE = Date.parse("18-05-2018").beginning_of_day
    Common::RakeModule::Utils.execute_task do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
      members = organization.members.where("terms_and_conditions_accepted < ? ", GDPR_ROLLOUT_DATE)
      user_ids = members.joins(:users).pluck("users.id")
      members.update_all(terms_and_conditions_accepted: nil, skip_delta_indexing: true)
      DelayedEsDocument.delayed_bulk_update_es_documents(User, user_ids)
    end
  end
end