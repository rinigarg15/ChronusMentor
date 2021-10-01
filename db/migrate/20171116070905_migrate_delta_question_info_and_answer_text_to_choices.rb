class MigrateDeltaQuestionInfoAndAnswerTextToChoices< ActiveRecord::Migration[4.2]
  def up
    invalid_match_texts = {}
    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        delta_profile_question_ids = ActiveRecord::Base.connection.exec_query("select ref_obj_id from temp_profile_objects where ref_obj_type = '#{ProfileQuestion.name}'").rows.flatten
        migrate_question_info_to_question_choices(delta_profile_question_ids)
        invalid_match_texts = migrate_conditional_choice_text(invalid_match_texts)
        delta_profile_answer_ids = ActiveRecord::Base.connection.exec_query("select ref_obj_id from temp_profile_objects where ref_obj_type = '#{ProfileAnswer.name}'").rows.flatten
        migrate_answer_text_to_answer_choices(delta_profile_answer_ids)
      end
    end
    if invalid_match_texts.present?
      puts "Invalid Match Texts: #{invalid_match_texts}"
      Airbrake.notify(invalid_match_texts)
    end
  end


  def down
    # nothing
  end

  def migrate_question_info_to_question_choices(delta_profile_question_ids)
    return if delta_profile_question_ids.empty?
    profile_questions = ProfileQuestion.where(id: delta_profile_question_ids, question_type: ProfileQuestion::Type.choice_based_types).includes(:translations, question_choices: :translations)

    # clean question choices if question type changed from choice based to non choice based or profile question deleted
    pq_ids_for_choice_deletion = delta_profile_question_ids - profile_questions.collect(&:id)
    qcs = QuestionChoice.where(ref_obj_type: ProfileQuestion.name, ref_obj_id: pq_ids_for_choice_deletion)
    QuestionChoice::Translation.where(question_choice_id: qcs.collect(&:id)).delete_all
    qcs.delete_all

    return if profile_questions.empty?

    profile_questions.each do |pq|
      position = 0
      existing_choices = []
      existing_translated_choices = []
      qc_ids = []
      qcs_hash = {}
      question_info = pq.translations.find{|pqt| pqt.locale == I18n.default_locale}.question_info
      choices = ProfileQuestion.split_by_separator(question_info)
      choices.each_with_index do |choice, index|
        choice.strip!
        next if choice.blank? || choice.in?(existing_choices)
        position += 1
        qc = pq.question_choices.find{|qc| qc.text == choice && qc.position == position && !qc.is_other?}
        if qc.blank? && (qc = pq.question_choices.find{|qc| qc.text == choice }).present?
          qc.update_columns(position: position, is_other: false)
        end
        qc ||= pq.question_choices.create!(text: choice, position: position, is_other: false)
        qcs_hash[index] = qc
        qc_ids << qc.id
        existing_choices << choice
      end

      other_position = pq.question_choices.select{|qc| !qc.is_other?}.size + 1
      pq.question_choices.other_choices.update_all(position: other_position)
      pq.question_choices.select{|qc| !qc.is_other? && !qc.id.in?(qc_ids)}.each do |qc|
        qc.translations.delete_all
        qc.delete
      end
      pq.translations.each do |pqt|
        next if pqt.locale == I18n.default_locale
        translated_choices = ProfileQuestion.split_by_separator(pqt.question_info)
        translated_choices.each_with_index do |translated_choice, index|
          translated_choice.strip!
          question_choice = qcs_hash[index]
          next if translated_choice.blank? || translated_choice.in?(existing_translated_choices) || question_choice.blank?
          qct = question_choice.translations.find{|qct| qct.text == translated_choice && qct.locale == pqt.locale}
          qct ||= question_choice.translations.create!(text: translated_choice, locale: pqt.locale)
          existing_translated_choices << translated_choice
        end
      end
    end
  end

  def migrate_conditional_choice_text(invalid_match_texts = {})
    all_conditional_match_texts = []
    ProfileQuestion.where.not(conditional_match_text: nil, conditional_question_id: nil).select(:id, :conditional_question_id, :conditional_match_text, :organization_id).includes(:conditional_question).find_each do |profile_question|
      next unless profile_question.conditional_question.choice_or_select_type?
      profile_question.conditional_match_text.split(",").map(&:strip).uniq.each do |choice_text|
        next if choice_text.blank?
        qc = QuestionChoice.find_by(text: choice_text, ref_obj_id: profile_question.conditional_question_id, ref_obj_type: ProfileQuestion.name, is_other: false)
        if qc.blank?
        	invalid_match_texts[profile_question.id] ||= []
        	invalid_match_texts[profile_question.id] << choice_text
        	next
        end
        all_conditional_match_texts << profile_question.conditional_match_choices.build(question_choice_id: qc.id)
      end
    end
    ConditionalMatchChoice.import(all_conditional_match_texts, validate: false)
    invalid_match_texts
  end

  def migrate_answer_text_to_answer_choices(delta_profile_answer_ids)
    return if delta_profile_answer_ids.empty?
    profile_answers = ProfileAnswer.where(id: delta_profile_answer_ids)
    pa_ids_for_choice_deletion = delta_profile_answer_ids - profile_answers.collect(&:id)
    pq_ids = profile_answers.collect(&:profile_question_id)
    non_choice_pq_ids = ProfileQuestion.where(id: pq_ids).where.not(question_type: ProfileQuestion::Type.choice_based_types).pluck(:id)
    pa_ids_for_choice_deletion += profile_answers.where(profile_question_id: non_choice_pq_ids).pluck(:id)

    AnswerChoice.where(ref_obj_id: pa_ids_for_choice_deletion, ref_obj_type: ProfileAnswer.name).delete_all

    profile_answers = profile_answers.where.not(id: pa_ids_for_choice_deletion).includes({profile_question: [question_choices: :translations]}, :answer_choices)

    return if profile_answers.empty?

    question_choices_hash = build_question_choices_hash(pq_ids)

    profile_answers.each do |profile_answer|
      answer_choices = profile_answer.answer_text.split(profile_answer.get_answer_seperator).map(&:strip).reject(&:blank?)
      profile_question = profile_answer.profile_question
      question_choices = question_choices_hash[profile_question.id]
      answer_choice_ids = []

      position = 0
      answer_choices.each do |choice|
        question_choice_id = find_or_create_question_choice!(profile_question, question_choices, choice)
        next if question_choice_id.blank?
        ans_choice = profile_answer.answer_choices.find {|ac| ac.question_choice_id == question_choice_id && ac.position == position}
        if ans_choice.blank? && (ans_choice = profile_answer.answer_choices.find {|ac| ac.question_choice_id == question_choice_id}).present?
          ans_choice.update_columns(position: position)
        end
        ans_choice ||= profile_answer.answer_choices.create!(question_choice_id: question_choice_id, position: position)
        answer_choice_ids << ans_choice.id
        position += 1 if profile_question.ordered_options_type?
      end
      profile_answer.answer_choices.where.not(id: answer_choice_ids).delete_all
    end
  end

  def build_question_choices_hash(profile_question_ids)
    question_choices = QuestionChoice.includes(:translations).where(ref_obj_type: ProfileQuestion.name, ref_obj_id: profile_question_ids, is_other: false).select(:id, :ref_obj_id)
    hsh = {}
    question_choices.each do |qc|
      hsh[qc.ref_obj_id] ||= {}
      qc.translations.each do |qct|
        hsh[qc.ref_obj_id][qct.text.downcase] = qc.id
      end
    end
    hsh
  end

  def find_or_create_question_choice!(profile_question, question_choices, choice)
    downcased_choice = choice.downcase
    question_choice_id = question_choices[downcased_choice]
    if question_choice_id.blank? && profile_question.allow_other_option?
      question_choice = profile_question.question_choices.find_or_initialize_by(text: choice, is_other: true)
      question_choice.position = question_choices.size + 1
      question_choice.save! if question_choice.new_record?
      question_choice_id = question_choice.id
    end
    question_choice_id
  end
end
