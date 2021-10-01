class PopulateMentoringInCustomizedTermsTable< ActiveRecord::Migration[4.2]
  def change
    Organization.includes(:programs).find_each do |organization|
      CustomizedTerm.transaction do
        say organization.name
        organization.customized_terms.new.save_term("feature.custom_terms.mentoring".translate, CustomizedTerm::TermType::MENTORING_TERM)
        organization.programs.each do |program|
          program.customized_terms.new.save_term("feature.custom_terms.mentoring".translate, CustomizedTerm::TermType::MENTORING_TERM)
        end
      end
    end
  end
end