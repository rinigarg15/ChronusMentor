# USAGE: rake single_time:sales_demo_improvements:perform DOMAIN="chronus.com" SUBDOMAIN="ap15951.demo"
# DETAILS: AP-15951

class SalesDataUpdater
  def initialize(domain, subdomain)
    @domain, @subdomain = domain, subdomain
    @organization = Common::RakeModule::Utils.fetch_programs_and_organization(@domain, @subdomain)[1]
    @programs = @organization.programs
  end

  def update
    perform(:update_root_for_basic_program)
    perform(:update_member_time_zone)
    perform(:disable_ongoing_mentoring_for_flash_program)
    perform(:fix_broken_links)
    perform(:scrap_and_generate_zip)
    perform(:reindex_models)
  end

  private

  def perform(method_name)
    time_then = Time.now
    Common::RakeModule::Utils.print_success_messages("[#{time_then}] Performing: #{method_name}")
    send(method_name)
    Common::RakeModule::Utils.print_success_messages("#{method_name} completed in #{Time.now - time_then} seconds")
  end

  def update_root_for_basic_program
    basic_program = @programs.find { |program| program.root == "basic" }
    url_updater_params = {
      domain: @domain,
      subdomain: @subdomain,
      root: "basic",
      new_root: "flash-mentoring"
    }

    basic_program.root = "flash-mentoring"
    basic_program.save!
    @programs.collect(&:reload)

    url_updater = UrlUpdater.new(url_updater_params)
    url_updater.update_all_urls_of_an_organization(@organization)

    campaign_emails = basic_program.program_invitation_campaign.campaign_messages.collect(&:emails).flatten
    campaign_emails.each {|campaign_emails| campaign_emails.source.gsub!("/p/basic", "/p/flash-mentoring") }
  end

  def update_member_time_zone
    @organization.members.update_all(time_zone: "America/Los_Angeles", skip_delta_indexing: true)
  end

  def disable_ongoing_mentoring_for_flash_program
    flash_program = @programs.find { |program| program.root == "flash-mentoring" }
    flash_program.groups.destroy_all
    flash_program.mentor_requests.destroy_all
    flash_program.mentor_offers.destroy_all

    flash_program.engagement_type = Program::EngagementType::CAREER_BASED
    flash_program.save!
    program.update_default_abstract_views_for_program_management_report
    remove_ongoing_mentoring_related_permissions(flash_program)
  end

  def remove_ongoing_mentoring_related_permissions(program)
    permissions_to_be_removed = RoleConstants::MENTOR_REQUEST_PERMISSIONS + ["offer_mentoring"]
    program.roles.each do |role|
      permissions_to_be_removed.each { |permission_name| role.remove_permission(permission_name) }
    end
  end

  def fix_broken_links
    @programs.each do |program|
      task_template_ids = program.mentoring_model_tasks.pluck(:mentoring_model_task_template_id)
      MentoringModel::TaskTemplate.includes(:mentoring_model_tasks).where(id: task_template_ids).each do |task_template|
        task_template.mentoring_model_tasks.each do |task|
          task.update_attribute(:description, task_template.description)
        end
      end
    end
  end

  def scrap_and_generate_zip
    sales_data_scrapper = SalesDemo::SalesDataScrapper.new(subdomain: @subdomain, domain: @domain, programs: @programs.collect(&:root))
    sales_data_scrapper.scrap
    Common::RakeModule::Utils.print_success_messages("Demo Program has been scrapped successfully!! Download the scrapped zip file from #{Rails.root + 'demo/data.zip'}")
  end

  def reindex_models
    ElasticsearchReindexing.indexing_flipping_deleting([Member.name], true)
  end
end

namespace :single_time do
  namespace :sales_demo_improvements do
    desc "Changes to sales demo data as specified in AP-15951"
    task :perform => :environment do
      ActionMailer::Base.perform_deliveries = false
      sales_data_updater = SalesDataUpdater.new(ENV["DOMAIN"], ENV["SUBDOMAIN"])
      sales_data_updater.update
    end
  end
end
