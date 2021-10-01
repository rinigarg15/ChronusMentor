class TopicImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "hits", "posts_count"]
  CustomAttributes = ["forum_id", "user_id", "body"]
  AssociatedImporters = []
  SalesDemoImporters = ["PostImporter"]
  AssociatedModel = "Topic"
  FileName = 'topic'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_forum_id(forum_id, obj)
    obj.forum_id = self.solution_pack.id_mappings[self.parent_importer.class::AssociatedModel][forum_id.to_i]
  end

  def process_user_id(user_id, obj)
    if self.solution_pack.sales_demo_mapper.present? && self.solution_pack.sales_demo_mapper[:user][user_id.to_i]
      obj.user_id = self.solution_pack.sales_demo_mapper[:user][user_id.to_i]
    else
      obj.user_id = self.solution_pack.program.owner.id
    end
  end

  def process_body(body, obj)
    obj.body = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(self.solution_pack.program, self.solution_pack, body, self.solution_pack.ck_editor_column_names, self.solution_pack.ck_editor_rows)
  end

  def handle_object_creation(obj, old_id, column_names, row)
    obj.save!
    obj
  end
end