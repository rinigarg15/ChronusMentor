require_relative './../../../test_helper'

class SqlGeneratorTest < ActiveSupport::TestCase
  def setup
    super
    @migrator = InstanceMigrator::SqlGenerator.new("source", "target", "source_environment", "source_seed")
    @migrator.load_models!
    @migrator.init_domain!
    @migrator.populate_domain!
  end

  def test_common_tables_have_new_associations
    assert_equal ["organization_languages", "member_languages"], Language.reflections.keys
    assert_equal ["role_permissions", "roles"], Permission.reflections.keys
    assert_equal ["organization_features"], Feature.reflections.keys
    assert_equal ["program", "programs"], Theme.reflections.keys
    assert_equal ["taggings"], ActsAsTaggableOn::Tag.reflections.keys
    assert_equal ["object_role_permissions"], ObjectPermission.reflections.keys
    assert_equal ["profile_answers", "location_lookups", "preference_based_mentor_lists"], Location.reflections.map { |klass, association| klass if association.options[:through].blank? }.compact
  end

  def test_generate_insert_sql_statement
    # STI where same column is associated to two different models
    table = "connection_private_notes"
    output = @migrator.generate_insert_sql_statement("#{table}", "source.#{table}.id != @source_max_#{table}_id")
    expected = "INSERT INTO target.connection_private_notes (`id`, `text`, `attachment_file_name`, `attachment_content_type`, `attachment_file_size`, `attachment_updated_at`, `created_at`, `updated_at`, `ref_obj_id`, `type`, `source_audit_key`) SELECT  id + @target_max_connection_private_notes_id, `text`, `attachment_file_name`, `attachment_content_type`, `attachment_file_size`, `attachment_updated_at`, `created_at`, `updated_at`, CASE `type` WHEN 'Connection::PrivateNote' THEN ref_obj_id + @target_max_connection_memberships_id WHEN 'PrivateMeetingNote' THEN ref_obj_id + @target_max_member_meetings_id END, `type`, CONCAT('source_environment_source_seed_', id) FROM source.connection_private_notes  WHERE source.connection_private_notes.id != @source_max_connection_private_notes_id;"
    assert_equal expected, output

    # global models
    table = "organization_languages"
    output = @migrator.generate_insert_sql_statement("#{table}", "source.#{table}.id != @source_max_#{table}_id")
    expected = "INSERT INTO target.organization_languages (`id`, `enabled`, `language_id`, `organization_id`, `default`, `created_at`, `updated_at`, `title`, `display_title`, `language_name`, `source_audit_key`) SELECT  id + @target_max_organization_languages_id, `enabled`, j0.target_j_id, IF(`organization_id` = 0 OR `organization_id` = NULL, `organization_id`, `organization_id` + @target_max_programs_id), `default`, `created_at`, `updated_at`, `title`, `display_title`, `language_name`, CONCAT('source_environment_source_seed_', id) FROM source.organization_languages LEFT JOIN temp_common_join_table as j0 ON j0.source_j_id = source.organization_languages.language_id AND j0.table_name = 'languages' WHERE source.organization_languages.id != @source_max_organization_languages_id;"

    assert_equal expected, output

    # polymorphic models
    table = "role_references"
    output = @migrator.generate_insert_sql_statement("#{table}", "source.#{table}.id != @source_max_#{table}_id")
    expected = "INSERT INTO target.role_references (`id`, `ref_obj_id`, `ref_obj_type`, `role_id`, `created_at`, `updated_at`, `source_audit_key`) SELECT  id + @target_max_role_references_id, `ref_obj_id` + t0.target_max_id, `ref_obj_type`, IF(`role_id` = 0 OR `role_id` = NULL, `role_id`, `role_id` + @target_max_roles_id), `created_at`, `updated_at`, CONCAT('source_environment_source_seed_', id) FROM source.role_references LEFT JOIN temp_model_table_map as t0 ON source.role_references.ref_obj_type = t0.model_name WHERE source.role_references.id != @source_max_role_references_id;"
    assert_equal expected, output

    table = "cm_campaign_message_jobs"
    output = @migrator.generate_insert_sql_statement("#{table}", "source.#{table}.id != @source_max_#{table}_id")
    expected = "INSERT INTO target.cm_campaign_message_jobs (`id`, `campaign_message_id`, `abstract_object_id`, `created_at`, `updated_at`, `run_at`, `failed`, `type`, `abstract_object_type`, `source_audit_key`) SELECT  id + @target_max_cm_campaign_message_jobs_id, IF(`campaign_message_id` = 0 OR `campaign_message_id` = NULL, `campaign_message_id`, `campaign_message_id` + @target_max_cm_campaign_messages_id), `abstract_object_id` + t0.target_max_id, `created_at`, `updated_at`, `run_at`, `failed`, `type`, `abstract_object_type`, CONCAT('source_environment_source_seed_', id) FROM source.cm_campaign_message_jobs LEFT JOIN temp_model_table_map as t0 ON source.cm_campaign_message_jobs.abstract_object_type = t0.model_name WHERE source.cm_campaign_message_jobs.id != @source_max_cm_campaign_message_jobs_id;"
    assert_equal expected, output

    # generic usecase
    table = "user_stats"
    output = @migrator.generate_insert_sql_statement("#{table}", "source.#{table}.id != @source_max_#{table}_id")
    expected = "INSERT INTO target.user_stats (`id`, `user_id`, `average_rating`, `rating_count`, `created_at`, `updated_at`, `source_audit_key`) SELECT  id + @target_max_user_stats_id, IF(`user_id` = 0 OR `user_id` = NULL, `user_id`, `user_id` + @target_max_users_id), `average_rating`, `rating_count`, `created_at`, `updated_at`, CONCAT('source_environment_source_seed_', id) FROM source.user_stats  WHERE source.user_stats.id != @source_max_user_stats_id;"
    assert_equal expected, output
  end
end