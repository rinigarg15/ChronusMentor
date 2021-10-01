class GCCleaner
  ES_MODEL_LIST = ["User"]
  def cleanup_gc_stuffs
    puts "Starting GC Cleanup: #{Time.now}"
    ActionMailer::Base.perform_deliveries = false
    
    ActiveRecord::Base.transaction do
      @commitee_roles = Role.where(:name => RoleConstants::COMMITTEE_MEMBER_NAME)
      @objects_related_to_gc_role = RoleReference.where(:role_id => @commitee_roles.collect(&:id)).group_by(&:ref_obj_type)
      cleanup_gc_objects
      cleanup_roles_and_permissions
      disable_and_remove_feature
    end
    puts "GC Cleanup Complete: #{Time.now}"
  end

  def reindex_es
    @es_indexing_hash.each do |model_name, action|
      model = model_name.constantize
      if action[:to_update]
        DelayedEsDocument.delayed_bulk_update_es_documents(model, action[:to_update])
      elsif action[:to_delete]
        DelayedEsDocument.delayed_bulk_delete_es_documents(model, action[:to_delete])
      end
    end
  end

  private

  def cleanup_gc_objects
    @objects_related_to_gc_role.each_pair do |object_class, references|
      puts "No of Objects to clean for #{object_class}: #{references.size}"
      objects = references.collect(&:ref_obj)
      @es_indexing_hash[object_class] ||= {} if ES_MODEL_LIST.include?(object_class)
      case object_class
      when "ProgramInvitation", "User"
        cleanup_gc_users_or_invitations(object_class, objects)
      when "Announcement"
        cleanup_gc_announcements(object_class, objects)
      else
        raise "Invalid ref object"
      end
    end
  end

  def cleanup_gc_users_or_invitations(object_class, objects)
    objects.each do |object|
      if object.role_names.size > 1
        puts "Demoting #{object_class} object: #{object.id}"
        object.role_names -= [RoleConstants::COMMITTEE_MEMBER_NAME]
        object.save!
        if ES_MODEL_LIST.include?(object_class)
          @es_indexing_hash[object_class][:to_update] ||= []
          @es_indexing_hash[object_class][:to_update] << object.id
        end
      else
        puts "Destorying #{object_class} object: #{object.id}"
        if ES_MODEL_LIST.include?(object_class)
          @es_indexing_hash[object_class][:to_delete] ||= []
          @es_indexing_hash[object_class][:to_delete] << object.id
        end
        object.destroy
      end
    end
  end

  def cleanup_gc_announcements(object_class, objects)
    objects.each do |object|
      if object.recipient_role_names.size > 1
        puts "Demoting #{object_class} object: #{object.id}"
        object.recipient_role_names -= [RoleConstants::COMMITTEE_MEMBER_NAME]
        object.save!
      else
        puts "Destroying #{object_class} object: #{object.id}"
        object.destroy
      end
    end
  end

  def cleanup_roles_and_permissions
    role_permissions = RolePermission.where(:role_id => @commitee_roles.collect(&:id))
    role_permissions.collect(&:destroy)
    @commitee_roles.collect(&:destroy)
  end

  def disable_and_remove_feature
    feature = Feature.where(:name => "governing_committee").first
    org_features = OrganizationFeature.where(:feature_id => feature.id)
    org_features.collect(&:destroy)
    feature.destroy
  end
end

# USAGE:
# rake data_migrator:clear_governing_committee"
namespace :data_migrator do
  desc "Expires the Invitations for Dormant Users and Move unpublished users to Dormant for PNC"
  task :clear_governing_committee => :environment do
    gc_cleaner = GCCleaner.new
    @es_indexing_hash = {}
    DelayedEsDocument.skip_es_delta_indexing do
      gc_cleaner.cleanup_gc_stuffs
    end
  end
end