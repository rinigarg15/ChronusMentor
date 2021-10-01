class PopulateCareerDevelopmentTermInCustomizedTerm< ActiveRecord::Migration[4.2]
  def up
    Organization.find_each do |org|
      org.customized_terms.new.save_term("feature.custom_terms.career_development".translate, CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM)
    end
  end

  def down
    CustomizedTerm.where(term_type: CustomizedTerm::TermType::CAREER_DEVELOPMENT_TERM).destroy_all
  end
end
