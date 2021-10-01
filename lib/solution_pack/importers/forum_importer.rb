class ForumImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "topics_count"]
  CustomAttributes = ["program_id"]
  AssociatedImporters = []
  SalesDemoImporters = ["TopicImporter"]
  AssociatedModel = "Forum"
  FileName = 'forum'

  def initialize(parent_importer)
    super parent_importer
  end

  def handle_object_creation(obj, old_id, column_names, row)
    obj.access_role_names = access_role_names_hash[old_id]
    obj.save!
    subscribe_the_program_owner(obj)
    obj
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def subscribe_the_program_owner(forum)
    forum.subscribe_user(self.solution_pack.program.owner)
  end

  def preprocess_import
    self.access_role_names_hash = fill_access_role_names_hash
  end
end
