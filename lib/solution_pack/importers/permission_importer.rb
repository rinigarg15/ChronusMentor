class PermissionImporter < SolutionPack::Importer

  NoImportAttributes = []
  CustomAttributes = []

  AssociatedModel = "Permission"
  FileName = 'permission'

  def initialize(parent_importer)
    super parent_importer
  end

  def handle_object_creation(obj, old_id, column_names, row)
    name_column_index = column_names.index('name')
    existing_obj = Permission.find_by(name: row[name_column_index])
    if existing_obj.present?
      return existing_obj
    else
      obj.save!
      return obj
    end
  end
end