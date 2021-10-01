# usage cap production deploy:invoke task="single_time:migrate_question_info_to_question_choice"
namespace :single_time do
  desc 'Migrate question_info to question_choices'
  task :migrate_question_info_to_question_choice => :environment do
    start_time = Time.now

    translations = get_question_info_translations
    import_question_choice(translations)
    translations_with_order = get_translations_with_order(translations)
    import_question_choice_translations(translations_with_order, get_choice_info)
    update_timestamps

    puts Time.now - start_time
  end

  task verify_question_info_migration: :environment do
    start_time = Time.now

    question_info_translations = get_question_info_translations
    question_choice_translations = get_question_choices_translations

    compare_existing_and_migrated(question_info_translations, question_choice_translations)

    compare_answer_choices(question_choice_translations)

    compare_conditional_match_choice_migrations
  end

  def compare_conditional_match_choice_migrations
    existing = ProfileQuestion.where.not(conditional_match_text: nil, conditional_question_id: nil).includes(:translations).where("profile_question_translations.locale = ?", I18n.default_locale).pluck(:id, :conditional_question_id, "profile_question_translations.conditional_match_text")
    migrated = ConditionalMatchChoice.includes(question_choice: :translations).where("question_choice_translations.locale = ?", I18n.default_locale).pluck(:profile_question_id, :ref_obj_id, "question_choice_translations.text")

    existing = existing.group_by{|e| e[0]}
    migrated = migrated.group_by{|e| e[0]}

    missing_migrations = []

    existing.each do |e, values|
      existing_texts = values.transpose[2].first.split(",").map(&:strip).map(&:downcase)
      next if existing_texts.blank? && migrated[e].blank?
      if migrated[e].blank?
        missing_migrations << e
        next
      end
      migrated_texts = migrated[e].transpose[2].map(&:strip).map(&:downcase)
      if ((migrated_texts - existing_texts) + (existing_texts - migrated_texts)).present?
        missing_migrations << e
      end
    end

    puts "Missing Condtional Match Text: #{missing_migrations.join(",")}"

  end

  def compare_answer_choices(question_choices)
    choice_info = get_choice_info_id # hash with profile_question_id as the key and another hash(key: question_choice_id, value: array of all locale texts) as value
    ordered_options_type_questions = ProfileQuestion.where(question_type: ProfileQuestion::Type::ORDERED_OPTIONS).pluck(:id)

    missing_answer_text = []
    extra_answer_choice = []

    question_choices.keys.in_groups_of(1000, false) do |profile_question_id_batch|
      profile_answers = Hash[ProfileAnswer.where(profile_question_id: profile_question_id_batch).pluck(:id, :answer_text, :profile_question_id).map{|e| [e[0], e[1..2]]}]


      answer_choices = AnswerChoice.where(ref_obj_id: profile_answers.keys).pluck(:ref_obj_id, :question_choice_id, :id)


      answer_choices.each do |answer_choice|
        answer_text, profile_question_id = profile_answers[answer_choice[0].to_i]
        all_locale_values = choice_info[profile_question_id.to_i][answer_choice[1].to_i].transpose[1].map(&:downcase).map{|text| I18n.transliterate(text)}
        delimitor = profile_question_id.to_i.in?(ordered_options_type_questions) ? "|" : ","
        existing_choices = answer_text.split(delimitor).map(&:strip).map(&:downcase).map{|text| I18n.transliterate(text)}
        unless(all_locale_values & existing_choices).present?
          extra_answer_choice << answer_choice[2]
        end
      end

      answer_choices = answer_choices.group_by{|ac| ac[0]}
      profile_answers.each do |id, values|
        # id is profile_answer_id, values is [answer_text, profile_question_id]
        next if values[0].blank? && answer_choices[id].blank?
        if answer_choices[id].blank?
          missing_answer_text << id
          next
        end
        question_choice_ids = answer_choices[id].transpose[1] # getting the middle element 'question_choice_id'
        profile_question_id = values[1].to_i
        delimitor = profile_question_id.in?(ordered_options_type_questions) ? "|" : ","
        existing_selected_choices = values[0].split(delimitor).map(&:strip).map(&:downcase).delete_if{|choice| choice.blank?}.map{|text| I18n.transliterate(text)}
        migrated_choices = question_choice_ids.map{|choice| choice_info[profile_question_id][choice].transpose[1]}.flatten.map(&:downcase).map{|text| I18n.transliterate(text)}
        if(existing_selected_choices - migrated_choices).present?
          missing_answer_text << id
        end
      end
    end

    actual_missing_answer_text = []
    profile_answers = ProfileAnswer.where(id: missing_answer_text).includes(:profile_question => [{:default_question_choices => :translations}, :translations])
    profile_answers.each do |ans|
      question = ans.profile_question
      delimiter = question.ordered_options_type? ? "|" : ","
      next if(ans.answer_text.split(delimiter).map(&:strip).map(&:downcase).map{|text| I18n.transliterate(text)} - question.question_info.split(",").map(&:strip).map(&:downcase).map{|text| I18n.transliterate(text)}).present? && !question.allow_other_option
      # We have removed answers which have an unmigrated answer text but the profile quesiton does not allow other option
      actual_missing_answer_text << [ans.id, ans.answer_text, ans.profile_question.default_choices.join(',')]
    end

    puts "Extra Answer Choice: #{extra_answer_choice.join(",")}"
    puts "Missing Answer Text: #{actual_missing_answer_text.join(",")}"
  end

  def compare_existing_and_migrated(existing, migrated)
    unmigrated = Hash[*(
      (existing.size > migrated.size)    \
          ? existing.to_a - migrated.to_a \
          : migrated.to_a - existing.to_a
      ).flatten]
    unmigrated.keys.each do |profile_question_id|
      existing[profile_question_id].each do |locale, values|
        e = (values || "").split(",").uniq
        m = (migrated[profile_question_id].try(:[], locale) || "").split(",").uniq
        unmigrated[profile_question_id].delete(locale) if (e-m).blank?
      end
      unmigrated.delete(profile_question_id) if unmigrated[profile_question_id].blank?
    end
    raise Exception.new("Unmigrated question info found: #{unmigrated}") if unmigrated.size > 0
  end

  def get_question_choices_translations
    question_choice_translations = QuestionChoice::Translation.includes(:globalized_model).where('question_choices.is_other' => false).pluck('question_choices.ref_obj_id', :locale, 'question_choice_translations.text', :question_choice_id)
    hsh = question_choice_translations.group_by{|translation| translation[0]}
    hsh.each do |element_0, element|
      hsh[element_0] = element.map{|ele| ele[1..3]}.group_by{|ele| ele[0]}
      question_choice_ids = hsh[element_0]["en"].transpose[2].sort
      hsh[element_0]["en"] = hsh[element_0]["en"].map{|v| v[1]}.join(",")
      hsh[element_0].each do |locale, values|
        next if locale == 'en'
        hsh[element_0][locale] = question_choice_ids.collect{|choice_id| values.find{|v| v[2] == choice_id}.try(:[], 1) || "" }.join(",")
      end
    end
    return hsh
  end

  def get_question_info_translations
    choice_based_question_types = [ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::RATING_SCALE, ProfileQuestion::Type::ORDERED_SINGLE_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]
    profile_question_ids = ProfileQuestion.where(question_type: choice_based_question_types).pluck(:id)
    translations = ProfileQuestion::Translation.where(profile_question_id: profile_question_ids).pluck(:profile_question_id, :locale, :question_info)
    build_hash(translations)
  end

  def get_choice_info_id
    question_choice_translations = QuestionChoice::Translation.includes(:globalized_model).pluck(:ref_obj_id, :question_choice_id, :text)
    hsh = question_choice_translations.group_by{|translation| translation[0]}
    hsh.each do |element_0, element|
      hsh[element_0] = element.map{|ele| ele[1..2]}.group_by{|ele| ele[0]}
    end

    return(hsh)
  end

  def get_choice_info
    choice_info = QuestionChoice.where(ref_obj_type: "ProfileQuestion").pluck(:ref_obj_id, :text, :id)
    build_hash(choice_info)
  end

  def build_hash(array)
    hsh = array.group_by{|element| element[0]}
    hsh.each do |element_0, element|
      hsh[element_0] = Hash[element.map{|ele| ele[1..2]}]
    end
    return hsh
  end

  def import_question_choice(translations)
    all_choices = []
    translations.each do |profile_question_id, question_info|
      split_choices = ProfileQuestion.split_by_separator(question_info[I18n.default_locale.to_s])
      next if split_choices.blank?
      index = 0
      existing_choices = []
      all_choices += split_choices.map do |choice|
        choice.strip!
        next if choice.blank? || choice.in?(existing_choices)
        index += 1
        existing_choices << choice
        QuestionChoice.new(text: choice, ref_obj_id: profile_question_id, ref_obj_type: "ProfileQuestion", position: index)
      end.compact
    end
    QuestionChoice.import(all_choices, validate: false, timestamps: false) if all_choices
  end

  def get_translations_with_order(translations)
    translations_with_order = {}
    translations.each do |profile_question_id, question_info|
      translations_with_order[profile_question_id] = split_translations(question_info)
    end
    return translations_with_order
  end

  def split_translations(question_info)
    translated_split_text = {}
    question_info.each do |locale, translated_question_info|
      translated_split_text[locale] = ProfileQuestion.split_by_separator(translated_question_info) if translated_question_info.present?
    end
    return translated_split_text
  end

  def import_question_choice_translations(translations_with_orders, choice_info)
    all_choice_translations = []
    translations_with_orders.each do |profile_question_id, locale_with_translated_text|
      locale_with_translated_text.each do |locale, translated_text|
        existing_default_locale_choices = []
        translated_text.each_with_index do |translated_choice, index|
          default_locale_choice = locale_with_translated_text[I18n.default_locale.to_s][index]
          next if translated_choice.blank? || default_locale_choice.in?(existing_default_locale_choices)
          existing_default_locale_choices << default_locale_choice
          choice_id = choice_info[profile_question_id][default_locale_choice]
          all_choice_translations << QuestionChoice::Translation.new(text: translated_choice, locale: locale, question_choice_id: choice_id)
        end
      end
    end
    QuestionChoice::Translation.import(all_choice_translations, validate: false, timestamps: false)
  end

  def update_timestamps
    timestamp = Time.now
    QuestionChoice.update_all(created_at: timestamp, updated_at: timestamp)
    QuestionChoice::Translation.update_all(created_at: timestamp, updated_at: timestamp)
  end
end