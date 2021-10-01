class CreateCustomizedTermsTable< ActiveRecord::Migration[4.2]
  def change
    create_table :customized_terms do |t|
      t.integer :ref_obj_id, :null => false
      t.string :ref_obj_type, :null => false, limit: UTF8MB4_VARCHAR_LIMIT
      t.string :term_type
      t.string :term, :null => false
      t.string :term_downcase, :null => false
      t.string :pluralized_term, :null => false
      t.string :pluralized_term_downcase, :null => false
      t.string :articleized_term, :null => false
      t.string :articleized_term_downcase, :null => false
      t.timestamps null: false
    end
    add_index :customized_terms, [:ref_obj_id, :ref_obj_type], :name => "index_customized_terms_on_ref_obj_id_and_ref_obj_type"
  end
end
