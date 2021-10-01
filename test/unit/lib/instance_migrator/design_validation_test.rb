require_relative './../../../test_helper'
class DesignValidationTest < ActiveSupport::TestCase
  def test_design
    ApplicationEagerLoader.load
    model_to_associations_validations = all_model_association_and_validations
    invalid_belongs_to_associations = get_invalid_belongs_to_associations(model_to_associations_validations)
    missing_model_associations = get_belongs_to_associations_without_inverse_association(model_to_associations_validations)
    table_int_columns = get_integer_columns
    integer_columns_without_assoc = integer_columns_without_associations(table_int_columns, model_to_associations_validations)
    foreign_keys_wo_column = foreign_keys_without_column(table_int_columns, model_to_associations_validations)
    models_to_ignore = ["Delayed::Backend::ActiveRecord::Job", "ActiveRecord::SessionStore::Session", "SimpleCaptcha::SimpleCaptchaData", "ChronusDocs::AppDocument", "ArticleContent", "ReceivedMail", "ActiveRecord::SchemaMigration", "ChrRakeTasks", "SchedulingAccount", "CalendarSyncErrorCases", "CalendarSyncRsvpLogs"]
    common_tables = ["ObjectPermission", "Language", "Feature", "Location", "Permission", "ActsAsTaggableOn::Tag"]
    unclassified_integer_columns = YAML.load(IO.read(Rails.root.to_s + "/test/fixtures/files/instance_migrator/unclassified_integer_columns.ym"))
    assert_compare_hash({}, foreign_keys_wo_column, "There are associations without a column. Please add the column or remove the association.")
    assert_compare_hash(unclassified_integer_columns, integer_columns_without_assoc, "There are new unclassified integer columns. Please add association if appropriate or add the column to test/fixtures/files/instance_migrator/unclassified_integer_columns.ym")
    assert_compare_hash({}, missing_model_associations, "Please add corresponding has_many/has_one association for the belongs_to associations")
    assert_compare_hash({"AbstractNote"=>{"ref_obj_id"=>["connection_membership", "member_meeting"]}, "Rating"=>{"user_id"=>["user", "member"]}}, get_belongs_to_association_for_comparison(invalid_belongs_to_associations), "A column can be associated only to multiple objects of similar type. If necessary, use polymorphism.")
    assert_compare_hash({}, get_belongs_to_association_with_non_integer_foreign_keys(model_to_associations_validations), "foreign_key has to be on integer column.")
    assert_compare_array((common_tables + models_to_ignore), get_common_tables(model_to_associations_validations), "If this is a common table please add them to InstanceMigrator::SqlGenerator::COMMON_TABLES and its associated models in InstanceMigrator::SqlGenerator::COMMON_TABLE_ASSOCIATION")
  end

  private

  def get_belongs_to_association_for_comparison(associations)
    comparison_hash = {}
    associations.each do |model_name, column_name_associations|
      comparison_hash[model_name] = {}
      column_name_associations.each do |column_name, associations|
        comparison_hash[model_name][column_name] = associations.collect(&:name).collect(&:to_s)
      end
    end
    return comparison_hash
  end

  def get_common_tables(model_to_associations_validations)
    common_tables = []
    model_to_associations_validations.each do |model_name, associations_list|
      common_tables << model_name if associations_list.blank? || associations_list["belongs_to"].blank?
    end
    common_tables
  end

  def assert_compare_hash(a, b, message)
    a_minus_b = (a.to_a - b.to_a).to_h
    b_minus_a = (b.to_a - a.to_a).to_h
    assert_equal a, b, "#{message} \nAdditions: #{a_minus_b} \nRemovals: #{b_minus_a} \nDiscuss with Architecture team for further details.\n"
  end

  def assert_compare_array(a, b, message)
    a_minus_b = (a.to_a - b.to_a)
    b_minus_a = (b.to_a - a.to_a)
    array_diff = a_minus_b + b_minus_a
    assert array_diff.length == 0, "#{message} \nAdditions: #{a_minus_b} \nRemovals: #{b_minus_a} \nDiscuss with Architecture team for further details.\n"
  end

  def get_belongs_to_association_with_non_integer_foreign_keys(model_to_associations_validations)
    belongs_to_association_with_non_integer_foreign_keys = {}
    model_to_associations_validations.keys.each do |model_name|
      next if model_to_associations_validations[model_name].blank?
      belongs_to_association_with_non_integer_foreign_keys[model_name] = []
      model_to_associations_validations[model_name]["belongs_to"].each do |assoc|
        unless model_name.constantize.type_for_attribute(assoc.foreign_key.to_s).is_a?(ActiveRecord::Type::Integer)
          belongs_to_association_with_non_integer_foreign_keys[model_name] << assoc.foreign_key.to_s
        end
      end
    end
    return belongs_to_association_with_non_integer_foreign_keys.reject{|k, v| v.blank?}
  end

  # Gets the models which have 2 belongs_to associations on the same column to different models.
  def get_invalid_belongs_to_associations(model_to_associations_validations)
    invalid_belongs_to_associations = {}
    model_to_associations_validations.keys.each do |model_name|
      associations = model_to_associations_validations[model_name]["belongs_to"].group_by{|assoc| assoc.foreign_key.to_s}.select do |key, value|
        value.size > 1 && !value.any?{|v| v.options[:polymorphic] == true } && value.collect(&:klass).collect(&:base_class).uniq.size > 1
        end
      invalid_belongs_to_associations[model_name] = associations
    end
    return invalid_belongs_to_associations.reject{|k, v| v.blank?}
  end

  # Gets the belongs_to associations which do not have a corresponding has_many or has_one inverse association
  # Does not work on polymorphic association
  def get_belongs_to_associations_without_inverse_association(model_to_associations_validations)
    missing_model_associations = {}
    model_to_associations_validations.keys.each do |model_name|
      next if model_to_associations_validations[model_name].blank?
      missing_model_associations[model_name] = {}

      model_to_associations_validations[model_name]["belongs_to"].each do |assoc|
        next if assoc.options[:polymorphic]
        if model_to_associations_validations[assoc.klass.base_class.name].present?
          # Check if any of the has_many/has_one reflection has the same base class as the current one and the same foreign key
          inverse_associations = model_to_associations_validations[assoc.klass.base_class.name]["has_many_one"].reject{|hmo| hmo.is_a?(ActiveRecord::Reflection::ThroughReflection)}.select{|hmo| hmo.klass.base_class == model_name.constantize.base_class && hmo.foreign_key.to_s == assoc.foreign_key.to_s}
        end
        unless inverse_associations.present?
          (missing_model_associations[model_name][assoc.foreign_key.to_s] ||= []).push([assoc.name, assoc.klass.name])
          missing_model_associations[model_name][assoc.foreign_key.to_s].uniq!
        end
      end
    end
    return missing_model_associations.reject{|k, v| v.blank?}
  end

  def integer_columns_without_associations(table_int_columns, model_to_associations_validations)
    table_int_columns = table_int_columns.deep_dup
    model_to_associations_validations.keys.each do |model_name|
      t_name = model_name.constantize.table_name
      next unless table_int_columns[t_name].present?
      table_int_columns[t_name] -= model_to_associations_validations[model_name]["belongs_to"].collect(&:foreign_key).collect(&:to_s)
      table_int_columns[t_name] -= model_to_associations_validations[model_name]["inclusion"]
    end
    return table_int_columns.reject{|k, v| v.blank?}
  end

  def foreign_keys_without_column(table_int_columns, model_to_associations_validations)
    model_to_foreign_key_mapping = {}
    model_to_associations_validations.keys.each do |model_name|
      t_name = model_name.constantize.table_name
      next unless table_int_columns[t_name].present?
      foreign_keys = model_to_associations_validations[model_name]["belongs_to"].collect(&:foreign_key).collect(&:to_s)
      model_to_foreign_key_mapping[t_name] = foreign_keys - table_int_columns[t_name]
    end
    return model_to_foreign_key_mapping.reject{|k, v| v.blank?}
  end

  def get_integer_columns
    tables = ActiveRecord::Base.connection.execute("show tables;").to_a.flatten
    table_int_columns = {}
    tables.each do |table|
      columns = ActiveRecord::Base.connection.execute("desc #{table};").to_a
      table_int_columns[table] = []
      columns.each do |column|
        next if column[0] == "id" || column[0].end_with?("_file_size") || column[0] == "position" || column[0].end_with?("_count")
        table_int_columns[table] << column[0] if column[1].match(/int/) && !column[1].match(/tinyint\(1\)/)
      end
    end
    return table_int_columns.reject{|k, v| v.blank?}
  end

  def all_model_association_and_validations
    visited = []
    model_to_associations_validations = {}
    ActiveRecord::Base.descendants.each do |model|
      next if model.name.in?(visited)
      visited << model.name
      next if model.table_name.blank?
      model_to_associations_validations[model.name] = {"belongs_to" => [], "has_many_one" => [], "inclusion" => []}
      (model.descendants + [model]).each {|klass| model_association_and_validations(klass, model.name, model_to_associations_validations)}
      visited += model.descendants.collect(&:name)
    end
    return model_to_associations_validations
  end

  def model_association_and_validations(model, model_name, model_to_associations_validations)
    model_to_associations_validations[model_name]["belongs_to"]   += model.reflect_on_all_associations(:belongs_to)
    model_to_associations_validations[model_name]["has_many_one"] += model.reflect_on_all_associations(:has_many)
    model_to_associations_validations[model_name]["has_many_one"] += model.reflect_on_all_associations(:has_one)
    model_to_associations_validations[model_name]["inclusion"]    += model.validators.select{|v| v.class == ActiveModel::Validations::InclusionValidator}.collect(&:attributes).flatten.collect(&:to_s)
  end
end