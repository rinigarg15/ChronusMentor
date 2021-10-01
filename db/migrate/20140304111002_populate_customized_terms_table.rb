class PopulateCustomizedTermsTable< ActiveRecord::Migration[4.2]
  def up
    Organization.all.each do |org|
      org.populate_default_customized_terms
    end

    Program.all.each do |prog|
      prog.populate_default_customized_terms
      prog.roles.each do |role|
        role.set_default_customized_term
      end
    end
  end

  def down
  end
end