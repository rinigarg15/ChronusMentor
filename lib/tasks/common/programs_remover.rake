# USAGE: rake common:programs_remover:remove DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list>
# EXAMPLE: rake common:programs_remover:remove DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1,p2"
# EXAMPLE: rake common:programs_remover:remove DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1,p2" CLONED_SOURCE_DB="cloned_db" SKIP_S3_ASSETS_DELETION=true

namespace :common do
  namespace :programs_remover do
    desc "Remove program(s) from an organization"
    task remove: :environment do
      skip_s3_assets_deletion = ENV["SKIP_S3_ASSETS_DELETION"] || "false"
      Common::RakeModule::Utils.establish_cloned_db_connection(ENV["CLONED_SOURCE_DB"])
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])
      initial_programs_count = organization.programs_count
      programs.each do |program|
        # update and destroy in a transaction prevents counter_culture from updating the counter.
        program.update_column(:active, false)
        ApplicationEagerLoader.load(skip_engines: true)
        parameters = ["Program", program.id, {:operation => OrganizationData::TargetCollection::OPERATION::COLLECT_FOR_PROGRAM_DELETION}]
        model_collection = OrganizationData::TargetCollection.new(*parameters)
        model_collection.collect_data
        model_deletion = OrganizationData::TargetDeletion.new(*parameters[1..-1])
        model_deletion.delete_db_data
        model_deletion.delete_s3_data unless skip_s3_assets_deletion.to_boolean
        Common::RakeModule::Utils.print_error_messages(model_collection.get_errors + model_deletion.get_errors)
        Common::RakeModule::Utils.print_success_messages("Program: #{program.url} removed!")
      end
      # counter_culture_fix_counts will update incorrect values for counter when counter_column refers to its own model in STI. For example: Both Program and Organization belongs to programs table and calculating count of type 'Program' in Organization will give incorrect value.
      programs_count_after_deletion = (initial_programs_count - programs.size)
      if organization.reload.programs_count != programs_count_after_deletion
        organization.update_column(:programs_count, programs_count_after_deletion)
        Common::RakeModule::Utils.print_success_messages("Updated the programs_count of the Organization to #{programs_count_after_deletion}")
      end
      OrganizationData::TargetDeletion.fix_counter_culture_counts
      # Invoke DJ's in dump
      if ENV["CLONED_SOURCE_DB"].present? && last_dj_id = Delayed::Job.last.try(:id)
        rejected_queues = [DjQueues::AWS_ELASTICSEARCH_SERVICE, DjQueues::ES_DELTA, DjQueues::MONGO_CACHE, DjQueues::MONGO_CACHE_HIGH_LOAD].map{|queue| "'#{queue}'"}.join(",")
        Delayed::Job.where("id <= #{last_dj_id} AND (queue NOT IN (?) OR queue IS NULL)", rejected_queues).find_each do |dj|
          dj.invoke_job
          dj.destroy
        end
      end
    end
  end
end

###################################################################################
# Whenever run the program_remover rake in CLONED_SOURCE_DB,
# please add the below code snippet to config/initializers/paperclip_overrides.rb.
# Or else s3 attachments will get deleted in source database.
####################################################################################
# module PaperclipAttachmentOverridesForProgramsRemover
#   def queue_all_for_delete
#     return if ActiveRecord::Base.connection.current_database != ActiveRecord::Base.configurations[Rails.env]["database"]
#     super
#   end
# end
# Paperclip::Attachment.prepend(PaperclipAttachmentOverridesForProgramsRemover)