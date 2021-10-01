class CustomizedTermImporter < SolutionPack::Importer

  NoImportAttributes = ["updated_at", "created_at"]
  CustomAttributes = []

  AssociatedModel = "CustomizedTerm"
  FileName = 'customized_term'

  def initialize(parent_importer)
    super parent_importer
    if parent_importer.class == RoleImporter
      self.file_name = self.class::FileName + "_" + RoleImporter::FileName
    elsif parent_importer.class == ProgramImporter
      self.file_name = self.class::FileName + "_" + ProgramImporter::FileName
    end
  end

  def handle_object_creation(obj, old_id, column_names, row)
    ref_obj_id_column_index = column_names.index('ref_obj_id')
    if parent_importer.class == RoleImporter
      existing_obj = self.solution_pack.program.roles.collect(&:customized_term).find{|r| r.ref_obj_id == self.solution_pack.id_mappings["Role"][row[ref_obj_id_column_index].to_i]}
    else
      existing_obj = self.solution_pack.program.customized_terms.where(term_type: obj.term_type).first
    end
    if existing_obj.present?
      existing_obj.term = obj.term
      existing_obj.term_downcase = obj.term_downcase
      existing_obj.pluralized_term = obj.pluralized_term
      existing_obj.pluralized_term_downcase = obj.pluralized_term_downcase
      existing_obj.articleized_term = obj.articleized_term
      existing_obj.articleized_term_downcase = obj.articleized_term_downcase
      existing_obj.save!
      return existing_obj
    else
      return obj
    end
  end

end