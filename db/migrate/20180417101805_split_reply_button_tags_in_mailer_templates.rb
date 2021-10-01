class SplitReplyButtonTagsInMailerTemplates < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Mailer::Template::Translation.joins(:globalized_model).where("mailer_templates.uid IN ('f57py6o7', 'vbs60t0y') AND mailer_template_translations.source like '%{{reply_button}}%'").each do |translation|
        mailer_source = translation.source
        mailer_source.gsub!("{{reply_button}}", "{{reply_button}}{{reply_button_help_text}}")
        translation.update_attributes!(source: mailer_source)
      end
    end
  end

  def down
    #Do nothing
  end
end
