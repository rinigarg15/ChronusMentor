class SolutionPack::Exporter

  include SolutionPack::ExportImportCommonUtils

  attr_accessor :objs, :file_name, :program, :parent_exporter, :solution_pack, :custom_associated_exporters, :skipped_associated_exporters

  AssociatedExporters = []

  def export_associated_content(program)
    self.associated_exporters.each do |ae|
      unless already_exported?(ae)
        next if self.skipped_associated_exporters&.include?(ae)
        obj = ae.constantize.new(program, self)
        obj.skipped_associated_exporters = self.skipped_associated_exporters
        obj.export
      end
    end
  end

  def export
    export_associated_content(self.program)
    file_path = self.solution_pack.base_path+self.file_name+".csv"
    class_name = self.class::AssociatedModel
    objects = self.objs
    additional_attributes = defined?(self.class::AdditionalAttributes) ? self.class::AdditionalAttributes : {}
    file_op = "wb"
    SolutionPack::Exporter.export_contents(file_path, class_name, objects, file_op: file_op, additional_attributes: additional_attributes)
    self.export_ck_editor_related_content if self.solution_pack.is_sales_demo
  end

  def self.export_contents(file_path, class_name, objects, options = {})
    file_op = options[:file_op] || "wb"
    additional_attributes = options[:additional_attributes] || {}
    CSV.open(file_path, file_op) do |csv|
      columns = class_name.constantize.attribute_names
      csv << columns + additional_attributes.keys
      objects.each do |obj|
        attrs = obj.attributes
        data_column = []
        columns.each do |c|
          data_column << self.get_data_column(obj, c, attrs[c], options)
        end
        additional_attributes.each do |additional_attribute, finder_method|
          data_column << obj.send(finder_method)
        end
        csv << data_column
      end
    end
  end

  def self.get_data_column(obj, column, column_value, options)
    return column_value unless options[:from_survey].present?
    if column.to_sym == :question_info
      obj.default_choices.join_by_separator(CommonQuestion::SEPERATOR)
    elsif [:positive_outcome_options, :positive_outcome_options_management_report].include?(column.to_sym)
      nil
    else
      column_value
    end
  end

  def already_exported?(ae)
    ae_klass = ae.constantize
    File.exist?(solution_pack.base_path+ae_klass::FileName+".csv")
  end

  def export_ck_editor_related_content
  end

  def associated_exporters
    if self.custom_associated_exporters.present?
      self.custom_associated_exporters
    elsif self.program.is_a?(CareerDev::Portal) && defined?(self.class::CareerDevAssociatedExporters)
      self.class::CareerDevAssociatedExporters
    elsif self.solution_pack.is_sales_demo && defined?(self.class::SalesDemoExporters)
      self.class::SalesDemoExporters
    else
      self.class::AssociatedExporters
    end
  end

end