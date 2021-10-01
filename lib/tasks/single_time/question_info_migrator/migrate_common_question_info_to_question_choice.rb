class MigrateCommonQuestionInfoToQuestionChoice
  def migrator
    start_time = Time.now

    translations = get_question_info_translations
    import_question_choice(translations)
    translations_with_order = get_translations_with_order(translations)
    import_question_choice_translations(translations_with_order, get_choice_info)

    puts Time.now - start_time
  end

  def validator
    question_info_translations = get_question_info_translations
    question_choice_translations = get_question_choices_translations
    compare_existing_and_migrated(question_info_translations, question_choice_translations)
    compare_answer_choices(question_choice_translations)
  end

  def migrate_delta_question_info_to_question_choices(delta_common_question_ids)
    return if delta_common_question_ids.empty?
    common_questions = CommonQuestion.where(id: delta_common_question_ids, question_type: CommonQuestion::Type.choice_based_types).includes(:translations, question_choices: :translations)

    # clean question choices if question type changed from choice based to non choice based or common question deleted
    cq_ids_for_choice_deletion = delta_common_question_ids - common_questions.collect(&:id)
    qcs = QuestionChoice.where(ref_obj_type: CommonQuestion.name, ref_obj_id: cq_ids_for_choice_deletion)
    QuestionChoice::Translation.where(question_choice_id: qcs.collect(&:id)).delete_all
    qcs.delete_all

    return if common_questions.empty?

    common_questions.each do |cq|
      position = 0
      existing_choices = []
      existing_translated_choices = []
      qc_ids = []
      qcs_hash = {}
      cq = cq.get_question
      question_info = cq.translations.find{|cqt| cqt.locale == I18n.default_locale}.question_info
      choices = question_info.split(",").map(&:strip)
      choices.each_with_index do |choice, index|
        next if choice.blank? || choice.in?(existing_choices)
        position += 1
        qc = cq.question_choices.find{|qc| qc.text == choice && qc.position == position && !qc.is_other?}
        if qc.blank? && (qc = cq.question_choices.find{|qc| qc.text == choice }).present?
          qc.update_columns(position: position, is_other: false)
        end
        qc ||= cq.question_choices.create!(text: choice, position: position, is_other: false)
        qcs_hash[index] = qc
        qc_ids << qc.id
        existing_choices << choice
      end

      other_position = cq.question_choices.select{|qc| !qc.is_other?}.size + 1
      cq.question_choices.other_choices.update_all(position: other_position)
      cq.question_choices.select{|qc| !qc.is_other? && !qc.id.in?(qc_ids)}.each do |qc|
        qc.translations.delete_all
        qc.delete
      end
      cq.translations.each do |cqt|
        next if cqt.locale == I18n.default_locale
        translated_choices = cqt.question_info.split(",").map(&:strip)
        translated_choices.each_with_index do |translated_choice, index|
          question_choice = qcs_hash[index]
          next if translated_choice.blank? || translated_choice.in?(existing_translated_choices) || question_choice.blank?
          qct = question_choice.translations.find{|qct| qct.text == translated_choice && qct.locale == cqt.locale}
          qct ||= question_choice.translations.create!(text: translated_choice, locale: cqt.locale)
          existing_translated_choices << translated_choice
        end
      end
    end
  end

  private

  def compare_existing_and_migrated(existing, migrated)
    unmigrated = Hash[*(
      (existing.size > migrated.size)    \
          ? existing.to_a - migrated.to_a \
          : migrated.to_a - existing.to_a
      ).flatten]
    unmigrated.keys.each do |common_question_id|
      existing[common_question_id].each do |locale, values|
        e = (values || "").split(",").map(&:strip).uniq
        m = (migrated[common_question_id].try(:[], locale) || "").split(",").uniq
        unmigrated[common_question_id].delete(locale) if (e-m).blank?
      end
      unmigrated.delete(common_question_id) if unmigrated[common_question_id].blank?
    end
    raise Exception.new("Unmigrated question info found: #{unmigrated}") if unmigrated.size > 0
  end

  def get_question_choices_translations
    question_choice_translations = QuestionChoice::Translation.includes(:globalized_model).where('question_choices.is_other' => false, 'question_choices.ref_obj_type' => CommonQuestion.name).pluck('question_choices.ref_obj_id', :locale, 'question_choice_translations.text', :question_choice_id)
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
    choice_based_question_types = [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE, CommonQuestion::Type::MATRIX_RATING]
    common_question_ids = CommonQuestion.where(question_type: choice_based_question_types, matrix_question_id: nil).pluck(:id)
    translations = CommonQuestion::Translation.where(common_question_id: common_question_ids).pluck(:common_question_id, :locale, :question_info)
    build_hash(translations)
  end

  def get_choice_info_id
    question_choice_translations = QuestionChoice::Translation.includes(:globalized_model).where("question_choices.ref_obj_type" =>  CommonQuestion.name).pluck(:ref_obj_id, :question_choice_id, :text)
    hsh = question_choice_translations.group_by{|translation| translation[0]}
    hsh.each do |element_0, element|
      hsh[element_0] = element.map{|ele| ele[1..2]}.group_by{|ele| ele[0]}
    end

    return(hsh)
  end

  def get_choice_info
    choice_info = QuestionChoice.where(ref_obj_type: CommonQuestion.name).pluck(:ref_obj_id, :text, :id)
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
    translations.each do |common_question_id, question_info|
      split_choices = question_info[I18n.default_locale.to_s].split(",")
      next if split_choices.blank?
      index = 0
      existing_choices = []
      all_choices += split_choices.map do |choice|
        choice.strip!
        next if choice.blank? || choice.in?(existing_choices)
        index += 1
        existing_choices << choice
        QuestionChoice.new(text: choice, ref_obj_id: common_question_id, ref_obj_type: CommonQuestion.name, position: index, is_other: false)
      end.compact
    end
    QuestionChoice.import(all_choices, validate: false) if all_choices
  end

  def get_translations_with_order(translations)
    translations_with_order = {}
    translations.each do |common_question_id, question_info|
      translations_with_order[common_question_id] = split_translations(question_info)
    end
    return translations_with_order
  end

  def split_translations(question_info)
    translated_split_text = {}
    question_info.each do |locale, translated_question_info|
      translated_split_text[locale] = translated_question_info.split(",").map(&:strip) if translated_question_info.present?
    end
    return translated_split_text
  end

  def import_question_choice_translations(translations_with_orders, choice_info)
    all_choice_translations = []
    translations_with_orders.each do |common_question_id, locale_with_translated_text|
      locale_with_translated_text.each do |locale, translated_text|
        existing_default_locale_choices = []
        translated_text.each_with_index do |translated_choice, index|
          default_locale_choice = locale_with_translated_text[I18n.default_locale.to_s][index]
          next if translated_choice.blank? || default_locale_choice.in?(existing_default_locale_choices)
          existing_default_locale_choices << default_locale_choice
          choice_id = choice_info[common_question_id][default_locale_choice]
          all_choice_translations << QuestionChoice::Translation.new(text: translated_choice, locale: locale, question_choice_id: choice_id)
        end
      end
    end
    QuestionChoice::Translation.import(all_choice_translations, validate: false)
  end

  def compare_answer_choices(question_choices)
    choice_info = get_choice_info_id # hash with common_question_id as the key and another hash(key: question_choice_id, value: array of all locale texts) as value
    matrix_q_ids = CommonQuestion.where.not(matrix_question_id: nil).select(:id, :matrix_question_id).index_by(&:id)
    missing_answer_text = []
    extra_answer_choice = []

    question_choices.keys.in_groups_of(1000, false) do |common_question_id_batch|
      common_answers = Hash[CommonAnswer.where(common_question_id: common_question_id_batch).pluck(:id, :answer_text, :common_question_id).map{|e| [e[0], e[1..2]]}]


      answer_choices = AnswerChoice.where(ref_obj_id: common_answers.keys, ref_obj_type: CommonAnswer.name).pluck(:ref_obj_id, :question_choice_id, :id)


      answer_choices.each do |answer_choice|
        answer_text, common_question_id = common_answers[answer_choice[0].to_i]
        common_question_id = matrix_q_ids[common_question_id].matrix_question_id if matrix_q_ids[common_question_id].present?
        all_locale_values = choice_info[common_question_id.to_i][answer_choice[1].to_i].transpose[1].map(&:downcase).map{|text| I18n.transliterate(text)}
        existing_choices = answer_text.split(",").map(&:strip).map(&:downcase).map{|text| I18n.transliterate(text)}
        unless(all_locale_values & existing_choices).present?
          extra_answer_choice << answer_choice[2]
        end
      end

      answer_choices = answer_choices.group_by{|ac| ac[0]}
      common_answers.each do |id, values|
        # id is common_answer_id, values is [answer_text, common_question_id]
        next if values[0].blank? && answer_choices[id].blank?
        if answer_choices[id].blank?
          missing_answer_text << id
          next
        end
        question_choice_ids = answer_choices[id].transpose[1] # getting the middle element 'question_choice_id'
        common_question_id = values[1].to_i
        common_question_id = matrix_q_ids[common_question_id].matrix_question_id if matrix_q_ids[common_question_id].present?
        existing_selected_choices = values[0].split(",").map(&:strip).map(&:downcase).delete_if{|choice| choice.blank?}.map{|text| I18n.transliterate(text)}
        migrated_choices = question_choice_ids.map{|choice| choice_info[common_question_id][choice].transpose[1]}.flatten.map(&:downcase).map{|text| I18n.transliterate(text)}
        if(existing_selected_choices - migrated_choices).present?
          missing_answer_text << id
        end
      end
    end

    actual_missing_answer_text = {}
    common_answers = CommonAnswer.where(id: missing_answer_text).includes(common_question: [{default_question_choices: :translations}, :translations])
    common_answers.each do |ans|
      question = ans.common_question
      next if(ans.answer_text.split(",").map(&:strip).map(&:downcase).map{|text| I18n.transliterate(text)} - question.question_info.split(",").map(&:strip).map(&:downcase).map{|text| I18n.transliterate(text)}).present? && !question.allow_other_option
      # We have removed answers which have an unmigrated answer text but the common quesiton does not allow other option
      actual_missing_answer_text[ans.id] ||= {}
      actual_missing_answer_text[ans.id][:answer_text] = ans.answer_text
      actual_missing_answer_text[ans.id][:default_choices] = ans.common_question.default_question_choices.collect(&:text)
    end

    puts "Extra Answer Choice Ids: #{extra_answer_choice.join(",")}"
    puts "Missing Answer Text: #{actual_missing_answer_text}"
  end


end