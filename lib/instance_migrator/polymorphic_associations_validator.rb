 # InstanceMigrator::PolymorphicAssociationsValidator.new.validate_and_print

module InstanceMigrator
  class PolymorphicAssociationsValidator
    attr_accessor :missed_polymorphic_associations, :csv_file_path
    def initialize(csv_file_path = nil)
      self.missed_polymorphic_associations = {}
      self.csv_file_path = csv_file_path || "tmp/missed_polymorphic_associations.csv"
    end

    def validate_and_print
      ApplicationEagerLoader.load
      ActiveRecord::Base.descendants.each do |model|
        next unless model.table_name.present?
        collect_missed_reverse_polymorphic_associations(model)
        missed_polymorphic_associations[model.base_class.name].uniq! if missed_polymorphic_associations[model.base_class.name].present?
      end
      print_report
    end

    def print_report
      csv = CSV.open(csv_file_path, "w")
      csv << ["Model", "Misssing Has Many/Has One Associations"]
      missed_polymorphic_associations.each do |model_name, associations_list|
        csv << [model_name, ""]
        associations_list.each do |association|
          csv << ["", " - #{association[:polymorphic]}"]
          csv << ["", " - #{association[:class_name]}"]
          csv << []
        end
      end
      csv.close
    end

  private

    def get_belongs_to_polymorphic_association(model)
      model.reflect_on_all_associations(:belongs_to).select {|association| association.options[:polymorphic].present? }
    end

    def get_reverse_association(association_type, model_klass, belongs_to_association, parent_model)
      model_klass.reflect_on_all_associations(association_type.to_sym).select {|association| association.options[:as].present? && association.options[:as].to_s == belongs_to_association.name.to_s && association.table_name == parent_model.table_name }
    end

    def collect_all_reverse_associations(association_type, model_klass, belongs_to_association, parent_model)
      reverse_associations = get_reverse_association(association_type, model_klass, belongs_to_association, parent_model)
      model_klass.descendants.each do |subklass|
        reverse_associations << get_reverse_association(association_type, subklass, belongs_to_association, parent_model)
      end
      reverse_associations.flatten.compact
    end

    def collect_missed_reverse_polymorphic_associations(model)
      get_belongs_to_polymorphic_association(model).compact.each do |association|
        model_klass_names = model.pluck(association.foreign_type.to_sym).uniq.compact
        model_klass_names.each do |model_klass_name|
          reverse_associations = collect_all_reverse_associations(:has_many, model_klass_name.constantize, association, model)
          reverse_associations += collect_all_reverse_associations(:has_one, model_klass_name.constantize, association, model)
          if reverse_associations.blank?
            missed_polymorphic_associations[model.base_class.name] ||= []
            missed_polymorphic_associations[model.base_class.name] << {class_name: model_klass_name, polymorphic: association.name}
          end
        end
      end
    end

  end
end
