class MentoringModelLinkImporter < SolutionPack::Importer

  NoImportAttributes = ["updated_at", "created_at"]
  CustomAttributes = ["child_template_id", "parent_template_id"]

  AssociatedModel = "MentoringModel::Link"
  FileName = 'mentoring_model_link'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_child_template_id(child_template_id, obj)
    obj.child_template_id = self.solution_pack.id_mappings[MentoringModelImporter::AssociatedModel][child_template_id.to_i]
  end

  def process_parent_template_id(parent_template_id, obj)
    obj.parent_template_id = self.solution_pack.id_mappings[MentoringModelImporter::AssociatedModel][parent_template_id.to_i]
  end
end