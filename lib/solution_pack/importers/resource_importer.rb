class ResourceImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "view_count"]
  CustomAttributes = ["program_id", "content"]

  AssociatedImporters = ["ResourcePublicationImporter"]

  AssociatedModel = "Resource"
  FileName = 'resource'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(program_id, obj)
    if self.solution_pack.sales_demo_mapper.present? && self.solution_pack.sales_demo_mapper[:organization][program_id.to_i]
      obj.program_id = self.solution_pack.sales_demo_mapper[:organization][program_id.to_i]
    else
      obj.program_id = self.solution_pack.program.id
    end
  end

  def process_content(content, obj)
    updated_content = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(solution_pack.program, solution_pack, content, solution_pack.ck_editor_column_names, solution_pack.ck_editor_rows)
    obj.content = updated_content
  end

  def handle_object_creation(obj, old_id, column_names, row)
    if self.solution_pack.sales_demo_mapper && self.solution_pack.sales_demo_mapper[:resource][old_id.to_i]
      return Resource.find_by(id: self.solution_pack.sales_demo_mapper[:resource][old_id.to_i])
    else
      obj.save!
      self.solution_pack.program.organization.resources.default.find_by(title: obj.title).try(:destroy) if obj.default && self.solution_pack.program.standalone?
      return obj
    end
  end

  def process_id(old_id, obj)
    if self.solution_pack.sales_demo_mapper && self.solution_pack.sales_demo_mapper[:resource][old_id.to_i]
      self.solution_pack.id_mappings[self.class::AssociatedModel][old_id.to_i] = self.solution_pack.sales_demo_mapper[:resource][old_id.to_i]
    else
      self.solution_pack.id_mappings[self.class::AssociatedModel][old_id.to_i] = obj.id
      self.solution_pack.sales_demo_mapper && self.solution_pack.sales_demo_mapper[:resource][old_id.to_i] = obj.id
    end
  end
end