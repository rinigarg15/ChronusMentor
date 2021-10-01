# USAGE: rake common:mentoring_model_updater:change_mentoring_period DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOT=<program_root> MENTORING_MODEL_ID=<> MENTORING_PERIOD_UNIT=<> MENTORING_PERIOD_VALUE=<> UPDATE_GROUPS_EXPIRY=<true|false>
# EXAMPLE: rake common:mentoring_model_updater:change_mentoring_period DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOT="p1" MENTORING_MODEL_ID="1" MENTORING_PERIOD_UNIT="1" MENTORING_PERIOD_VALUE="3" UPDATE_GROUPS_EXPIRY=true

# USAGE: rake common:mentoring_model_updater:change_mentoring_model DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOT=<program_root> MENTORING_MODEL_ID=<> NEW_MENTORING_MODEL_ID=<>
# EXAMPLE: rake common:mentoring_model_updater:change_mentoring_model DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOT="p1" MENTORING_MODEL_ID="1" NEW_MENTORING_MODEL_ID="3"

namespace :common do
  namespace :mentoring_model_updater do
    task change_mentoring_period: :environment do
      Common::RakeModule::Utils.execute_task do
        program = Common::RakeModule::Utils::fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]
        mentoring_model = program.mentoring_models.find_by(id: ENV["MENTORING_MODEL_ID"].to_i)
        raise "Invalid mentoring model ID!" if mentoring_model.blank?
        raise "Invalid mentoring period unit/value!" if ENV["MENTORING_PERIOD_UNIT"].blank? || ENV["MENTORING_PERIOD_VALUE"].blank?
        mentoring_model.set_mentoring_period(ENV["MENTORING_PERIOD_UNIT"], ENV["MENTORING_PERIOD_VALUE"])
        mentoring_model.save!

        if ENV["UPDATE_GROUPS_EXPIRY"].to_boolean
          groups = mentoring_model.groups.active.where("TIMESTAMPDIFF(second, groups.published_at, groups.expiry_time) < ?", mentoring_model.mentoring_period)
          groups.find_each do |group|
            group.expiry_time = group.published_at + (mentoring_model.mentoring_period / 1.day).days
            group.skip_observer = true
            group.save!
          end
        end
        Common::RakeModule::Utils.print_success_messages("Duration of Mentoring Model: #{mentoring_model.title} in #{program.url} has been updated!")
      end
    end

    task change_mentoring_model: :environment do
      Common::RakeModule::Utils.execute_task do
        program = Common::RakeModule::Utils::fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]
        mentoring_model = program.mentoring_models.find_by(id: ENV["MENTORING_MODEL_ID"].to_i)
        new_mentoring_model = program.mentoring_models.find_by(id: ENV["NEW_MENTORING_MODEL_ID"].to_i)
        raise "Invalid mentoring model ID!" if mentoring_model.blank? || new_mentoring_model.blank?
        raise "Mentoring Period Differs!" if mentoring_model.mentoring_period != new_mentoring_model.mentoring_period

        mentoring_model.groups.active.each do |group|
          update_groups_mentoring_model(program, group, new_mentoring_model)
        end
        mentoring_model.groups.drafted.update_all(mentoring_model_id: new_mentoring_model.id)

        messages = ["Mentoring Model has been updated for #{new_mentoring_model.groups.active.size} active connections!"]
        messages << "And for #{new_mentoring_model.groups.drafted.size} drafted connections!"
        Common::RakeModule::Utils.print_success_messages(messages)
      end
    end

    # EXAMPLE: rake common:mentoring_model_updater:update_group_mentoring_model DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOT="p1" GROUP_MODEL_MAP="10=>100,20=>50"
    desc "Update mentoring model for groups after publishing. Note: Task links in emails will not be working"
    task update_group_mentoring_model: :environment do
      Common::RakeModule::Utils.execute_task do
        program = Common::RakeModule::Utils::fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]
        group_model_hash = {}

        ENV["GROUP_MODEL_MAP"].split(",").each do |group_model|
          group_id, model_id = group_model.split("=>").map(&:to_i)
          model = program.mentoring_models.find(model_id)
          group = program.groups.find(group_id)
          group_model_hash[group.id] = { group: group, model: model }
          Common::RakeModule::Utils.print_alert_messages("#{group.name} will be mapped to #{model.title}")
        end

        group_model_hash.each { |_group_id, group_model| update_groups_mentoring_model(program, group_model[:group], group_model[:model], skip_expiry_update: true) }
      end
    end

    private

    def update_groups_mentoring_model(program, group, new_mentoring_model, options = {})
      group.object_role_permissions.destroy_all
      group.mentoring_model_tasks.destroy_all
      group.mentoring_model_milestones.destroy_all
      group.mentoring_model_goals.destroy_all

      Group::MentoringModelCloner.new(group, program, new_mentoring_model).copy_mentoring_model_objects

      unless options[:skip_expiry_update]
        old_expiry_time = group.expiry_time
        group.update_attribute(:expiry_time, old_expiry_time)
      end

      Common::RakeModule::Utils.print_success_messages("Mentoring model updated successfully for group ID: #{group.id}")
    end
  end
end