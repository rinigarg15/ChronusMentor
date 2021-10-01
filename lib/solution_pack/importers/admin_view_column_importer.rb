class AdminViewColumnImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["admin_view_id", "profile_question_id"]

  AssociatedModel = "AdminViewColumn"
  FileName = 'admin_view_column'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_admin_view_id(admin_view_id, obj)
    obj.admin_view_id = self.solution_pack.id_mappings["AdminView"][admin_view_id.to_i]
  end

  def process_profile_question_id(profile_question_id, obj)
    if profile_question_id.nil?
      obj.profile_question_id = nil
      return
    end
    obj.profile_question_id = self.solution_pack.id_mappings["ProfileQuestion"][profile_question_id.to_i]
    if obj.profile_question_id.nil? 
      err = ActiveModel::Errors.new(self.solution_pack)
      err.add(:base, "Error importing admin_view_column. profile question with id #{profile_question_id} not found.")
      self.solution_pack.custom_errors << SolutionPack::Error.new(SolutionPack::Error::TYPE::AdminViewColumn, err)
    end
  end

  def handle_object_creation(obj, old_id, column_names, row)
    return if obj.column_key.blank? && obj.profile_question_id.blank?

    same_column = obj.admin_view.admin_view_columns.where("column_key = ? OR profile_question_id = ?", obj.column_key, obj.profile_question_id).first
    if same_column.present?
      obj = same_column
    else
      obj.save!
    end
    obj
  end 
end
