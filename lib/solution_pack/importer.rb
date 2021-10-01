class SolutionPack::Importer

  include SolutionPack::ImporterUtils

  attr_accessor :file_name, :parent_importer, :solution_pack, :access_role_names_hash, :custom_associated_importers, :skipped_associated_importers

  AssociatedImporters = []

  def initialize(parent_importer)
    self.file_name = self.class::FileName
    self.parent_importer = parent_importer
    self.solution_pack = parent_importer.solution_pack
    self.solution_pack.id_mappings[self.class::AssociatedModel] ||= {}
  end

  def import_associated_content(parent_importer, associated_importers)
    associated_importers.each do |ai|
      unless already_imported?(ai)
        next if self.skipped_associated_importers&.include?(ai)
        ai_object = ai.constantize.new(parent_importer)
        ai_object.skipped_associated_importers = self.skipped_associated_importers
        ai_object.import
      end
    end
  end

  def import
    file_name = self.file_name
    base_directory_path = self.solution_pack.base_directory_path
    rows_with_column_names = CSV.read(base_directory_path + file_name + ".csv")
    self.preprocess_import
    populate_objects(rows_with_column_names)
    self.postprocess_import
    File.rename(base_directory_path + file_name + ".csv", base_directory_path + file_name + "-imported.csv")
    import_associated_content(self, self.associated_importers)
  end

  def process_id(old_id, obj)
    self.solution_pack.id_mappings[self.class::AssociatedModel][old_id.to_i] = obj.id
  end

  def register_invalid_ck_assets_in(old_id, obj)
    obj.attributes.each do |attribute, value|
      next if value.blank?

      if value.to_s.match(SolutionPack::CkeditorExportImportUtils::INVALID_URL).present?
        self.solution_pack.invalid_ck_assets_in ||= {}
        self.solution_pack.invalid_ck_assets_in[self.class::AssociatedModel] ||= []
        self.solution_pack.invalid_ck_assets_in[self.class::AssociatedModel] << [old_id.to_i, obj.id]
        obj.send("#{attribute}=", value.gsub(SolutionPack::CkeditorExportImportUtils::INVALID_URL, "#"))
        obj.save!
      end
    end
  end

  def already_imported?(ai)
    File.exist?(self.solution_pack.base_directory_path + ai.constantize::FileName + "-imported.csv")
  end

  def handle_object_creation(obj, old_id, column_names, row)
    obj.save!
    obj
  end

  def postprocess_import
  end

  def fill_access_role_names_hash
    access_role_names_hash = {}
    rows_with_column_names = CSV.read(self.solution_pack.base_directory_path + "role_reference_" + self.file_name + ".csv")
    column_names = rows_with_column_names[0]
    rows = rows_with_column_names[1..-1]
    old_role_id_index = column_names.index('role_id')
    old_obj_id_index = column_names.index('ref_obj_id')
    rows.each do |row|
      old_role_id = row[old_role_id_index].to_i
      new_role_id = self.solution_pack.id_mappings[RoleImporter::AssociatedModel][old_role_id]
      corresponding_role_name = Role.find(new_role_id).name  ## IF this step fails, then roles are not imported.
      old_obj_id = row[old_obj_id_index]
      if access_role_names_hash[old_obj_id].present?
        access_role_names_hash[old_obj_id] << corresponding_role_name
      else
        access_role_names_hash[old_obj_id] = [corresponding_role_name]
      end
    end
    access_role_names_hash
  end

  def preprocess_import
  end

  def associated_importers
    if self.custom_associated_importers.present?
      self.custom_associated_importers
    elsif self.solution_pack.program.is_a?(CareerDev::Portal) && defined?(self.class::CareerDevAssociatedImporters)
      self.class::CareerDevAssociatedImporters
    elsif self.solution_pack.is_sales_demo && defined?(self.class::SalesDemoImporters)
      self.class::SalesDemoImporters
    else
      self.class::AssociatedImporters
    end
  end

  def filter_rows(rows)
    column_names = rows[0]
    return [column_names, rows[1..-1]]
  end

  def process_row(obj, row, column_names)
    old_id = nil
    column_names.each_with_index do |column, index|
      if self.class::NoImportAttributes.include?(column)
      elsif self.class::CustomAttributes.include?(column)
        self.send("process_#{column}", row[index], obj)
      elsif (column == "id")
        old_id = row[index]
      else
        obj.send("#{column}=", row[index])
      end
    end
    return [old_id, obj]
  end

  def populate_objects(rows_with_column_names)
    column_names, rows = filter_rows(rows_with_column_names)
    rows.each do |row|
      obj = self.class::AssociatedModel.constantize.new
      old_id, obj = process_row(obj, row, column_names)
      obj = self.handle_object_creation(obj, old_id, column_names, row)
      if obj.present?
        self.process_id(old_id, obj)
        self.register_invalid_ck_assets_in(old_id, obj)
      end
    end
  end
end
