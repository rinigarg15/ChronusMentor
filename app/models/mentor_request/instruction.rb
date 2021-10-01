# == Schema Information
#
# Table name: instructions
#
#  id         :integer          not null, primary key
#  program_id :integer          not null
#  content    :text(65535)
#  created_at :datetime
#  updated_at :datetime
#  type       :string(255)      not null
#

class MentorRequest::Instruction < AbstractInstruction

  sanitize_attributes_content :content

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:content],
    :update => [:content]
  }

  def populate_content_with_default_value_if_nil(locales)
    return unless self.program.engagement_enabled?
    custom_terms = self.program.return_custom_term_hash
    locales.each do |locale|
      translation = self.translations.find_or_initialize_by(locale: locale)
      translation.content = "feature.preferred_mentoring.content.instructions.specify_help_needed_to_mentor_v1".translate(locale: locale, admins: custom_terms[:_admins], mentor: custom_terms[:_mentor], program: custom_terms[:_program]) if translation.content.nil?
      translation.save!
    end
  end

  def self.populate_content_for_language(org, locale)
    org.programs.each do |prog|
      next unless prog.engagement_enabled?
      prog.build_mentor_request_instruction.save! unless prog.mentor_request_instruction.present?
      prog.mentor_request_instruction.populate_content_with_default_value_if_nil([locale])
    end
  end
end
