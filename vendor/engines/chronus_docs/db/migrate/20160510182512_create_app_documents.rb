class CreateAppDocuments < ActiveRecord::Migration[4.2]

  def change
    create_table :chronus_docs_app_documents do |t|
      t.text :description
      t.text :title
      t.datetime :created_at
      t.datetime :updated_at
      t.string SOURCE_AUDIT_KEY.to_sym, :limit => UTF8MB4_VARCHAR_LIMIT
    end
  end
end
