class CreateProgramDomains< ActiveRecord::Migration[4.2]
  def change
    create_table :program_domains do |t|
      t.belongs_to :program
      t.string :domain, limit: UTF8MB4_VARCHAR_LIMIT, null: false
      t.string :subdomain, limit: UTF8MB4_VARCHAR_LIMIT
      t.boolean :is_default, null: false, default: true

      t.timestamps null: false
    end

    add_index :program_domains, [:domain, :subdomain]

    Organization.select("id, domain, subdomain").all.each do |org|
      dom = org.program_domains.new(is_default: true)
      dom.domain = org.attributes["domain"]
      dom.subdomain = org.attributes["subdomain"]
      dom.save!
    end
  end
end
