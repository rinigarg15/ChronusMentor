# == Schema Information
#
# Table name: feed_exporter_configurations
#
#  id                     :integer          not null, primary key
#  feed_exporter_id       :integer
#  enabled                :boolean          default(FALSE)
#  configuration_options  :text
#  type                   :string(255)

class FeedExporter::Configuration < ActiveRecord::Base
  self.table_name = "feed_exporter_configurations"

  belongs_to :feed_exporter

  scope :enabled, -> { where(enabled: true) }

  validates :feed_exporter, :configuration_options, presence: true

  attr_accessor :headers, :profile_question_texts, :member_ids, :member

  after_initialize :load_configurations

  def get_config_options
    return {} if self.configuration_options.blank?
    ActiveSupport::HashWithIndifferentAccess.new(Marshal.load(Base64.decode64(self.configuration_options)))
  end

  def set_config_options!(options)
    return nil if options.blank?
    self.configuration_options = Base64.encode64(Marshal.dump(ActiveSupport::HashWithIndifferentAccess.new(options)))
    self.save!
  end

  def load_configurations
    options = self.get_config_options
    # Set of headers picked from DefaultHeaders to export data
    @headers = options[:headers] || []
    # Set of Profile Question texts to be exported
    @profile_question_texts = options[:profile_question_texts] || []
  end

  protected

  def organization
    @organization ||= self.feed_exporter.organization
  end

  def get_header_text(header_key)
    header_map = self.class::DefaultHeaders::LOCALE_MAP[header_key]
    if header_map[:header_method]
      self.send(header_map[:header_method])
    else
      header_map[:translation_key].translate(get_terms_for_header_text(header_map[:terms]))
    end
  end

  def get_value(header)
    self.send(self.class::DefaultHeaders::METHOD_MAP[header])
  end

  def get_program_term
    @program_term ||= organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term
  end

  def get_connection_customized_term
    @connection_customized_term ||= organization.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
  end

  def get_connection_term
    @connection_term ||= get_connection_customized_term.term
  end

  def get_connection_term_downcase
    @connection_term_downcase ||= get_connection_customized_term.term_downcase
  end

  def populate_default_fields
    default_fields = {}
    default_header_keys.each do |default_header_key|
      header_text = get_header_text(default_header_key)
      default_fields[header_text] = get_value(default_header_key)
    end
    default_fields
  end

  def get_question_text_question_map
    # question_texts are needed for ordering
    @question_text_question_map ||= organization.profile_questions.
      joins(:translations).
      select("profile_questions.id, profile_question_translations.question_text, profile_questions.question_type").
      where(profile_question_translations: { question_text: profile_question_texts, locale: I18n.default_locale } ).
      where.not(profile_questions: { question_type: ProfileQuestion::Type::FILE } ).
      index_by(&:question_text)
  end

  def prepare_profile_answers_map
    return {} unless profile_question_texts.present?

    profile_question_ids = get_question_text_question_map.values.collect(&:id)
    Member.prepare_answer_hash(member_ids, profile_question_ids)
  end

  def construct_profile_answers_map(profile_answers_map)
    return {} if profile_question_texts.blank?
    profile_question_texts.inject({}) do |answers_map, question_text|
      profile_question = get_question_text_question_map[question_text]
      if profile_question.present?
        answer = profile_question.format_profile_answer(profile_answers_map[member.id][profile_question.id].try(:first), csv: true)
        answer = (answer.first.is_a?(Array) ? answer.map { |a| a.join(COMMON_SEPARATOR) }.join("\n") : answer.join(COMMON_SEPARATOR)) if answer.is_a?(Array)
        answers_map[profile_question.question_text] = answer || ""
      end
      answers_map
    end
  end

  private

  def get_terms_for_header_text(terms_method_map)
    terms_map = {}
    (terms_method_map || {}).each do |term, method_name|
      terms_map[term.to_sym] = self.send(method_name.to_sym)
    end
    terms_map
  end
end