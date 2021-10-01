class SectionImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["program_id", "position"]
  AssociatedImporters = ["ProfileQuestionImporter"]

  AssociatedModel = "Section"
  FileName = 'section'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.organization.id
  end

  def process_position(position, obj)
    sections = self.solution_pack.program.organization.sections.reload
    last_position = sections.present? ? sections.collect(&:position).uniq.sort.last : 0
    obj.position = last_position + 1
  end

  def handle_object_creation(obj, old_id, column_names, row)
    sections = self.solution_pack.program.organization.sections
    section = sections.where(title: obj.title).first
    if section.blank?
      if sections.present? && obj.default_field.present?
        obj = sections.where(default_field: true).first
      else
        obj.save!
      end
    else
      obj = section
    end
    obj
  end

end