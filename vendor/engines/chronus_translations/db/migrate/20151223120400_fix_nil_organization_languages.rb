class FixNilOrganizationLanguages < ActiveRecord::Migration[4.2]

  def up
    org_languages = OrganizationLanguage.where("language_name is NULL OR title is NULL OR display_title is NULL")
    org_languages.each do |org_languages|
      org_languages.title = org_languages.language.title if org_languages.title.nil?
      org_languages.display_title = org_languages.language.display_title if org_languages.display_title.nil?
      org_languages.language_name = org_languages.language.language_name if org_languages.language_name.nil?
      org_languages.save!
    end
  end

end
