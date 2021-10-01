#usage rake single_time:remove_duplicate_milestones DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOT=<root>

namespace :single_time do
  desc "Remove duplicate milestones from groups"
  task remove_duplicate_milestones: :environment do
    Common::RakeModule::Utils.execute_task do
      program = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]
      mentoring_model_ids = program.mentoring_models.pluck(:id)
      mentoring_model_milestones_templtaes_with_duplicates = ActiveRecord::Base.connection.exec_query(MentoringModel::MilestoneTemplate.where(mentoring_model_id: mentoring_model_ids).joins(:mentoring_model_milestones).select("mentoring_model_milestone_templates.id, group_id, COUNT(*) as count").group("group_id, mentoring_model_milestone_templates.id").having("count > 1").to_sql).rows
      groups = Group.where(id: mentoring_model_milestones_templtaes_with_duplicates.collect(&:second)).includes(mentoring_model_milestones: :mentoring_model_tasks).index_by(&:id)
      mentoring_model_milestones_templtaes_with_duplicates.each do |mentoring_model_milestones_templtae_id_with_duplicate, group_id, _|
        duplicate_milestones = groups[group_id].mentoring_model_milestones.select{ |mm| mm.mentoring_model_milestone_template_id == mentoring_model_milestones_templtae_id_with_duplicate }
        duplicate_milestones = duplicate_milestones.sort{ |m1, m2| [m1.mentoring_model_tasks.size, m1.mentoring_model_tasks.collect(&:completed_by).compact.size] <=> [m2.mentoring_model_tasks.size, m2.mentoring_model_tasks.collect(&:completed_by).compact.size] }
        duplicate_milestones[0..duplicate_milestones.size-2].map(&:destroy)
      end
    end
  end
end


