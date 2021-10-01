class PostImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "attachment_content_type", "attachment_file_size", "attachment_updated_at"]
  CustomAttributes = ["topic_id", "user_id", "body"]
  AssociatedImporters = []
  AssociatedModel = "Post"
  FileName = 'post'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_topic_id(topic_id, obj)
    obj.topic_id = self.solution_pack.id_mappings[self.parent_importer.class::AssociatedModel][topic_id.to_i]
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
    SolutionPack::AttachmentExportImportUtils.handle_attachment_import(self.solution_pack.post_attachment_base_path, obj, "attachment", obj.attachment_file_name, old_id)
    obj
  end
end