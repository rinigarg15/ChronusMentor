class SurveyResponseExportAsXlsService
  def initialize(survey_content_hash, locale)
    @user = survey_content_hash[:user]
    @group = survey_content_hash[:group]
    @meeting = survey_content_hash[:meeting]
    @submitted_at = survey_content_hash[:submitted_at]
    @survey_answers = survey_content_hash[:survey_answers]
    @survey_questions = survey_content_hash[:survey_questions]
    @user_roles = survey_content_hash[:user_roles]
    @locale = locale
  end

  def build_xls_data_for_survey
    GlobalizationUtils.run_in_locale(@locale) do
      program = @user.program
      @connection_term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
      @meeting_term = program.term_for(CustomizedTerm::TermType::MEETING_TERM).term
      book = Spreadsheet::Workbook.new

      sheet = book.create_worksheet
      sheet.name = @user.name(:name_only => true)

      sheet.row(0).push "display_string.Name".translate, @user.name(:name_only => true)
      sheet.row(1).push "feature.survey.survey_report.date_of_response".translate, DateTime.localize(@submitted_at, format: :default)
      sheet.row(2).push "feature.survey.survey_report.filters.header.user_role".translate, @user_roles

      row_no = 3
      if @meeting.present?
        sheet.row(row_no).push @meeting_term, @meeting.topic
        row_no += 1
      elsif @group.present?
        sheet.row(row_no).push @connection_term, @group.name
        row_no += 1
      end

      @survey_questions.each do |question|
        sheet.row(row_no).push question.question_text
        answer = @survey_answers[question.id].try(:first)
        if question.matrix_question_type?
          sheet.row(row_no).push answer_for_matrix_question(question)
        elsif CommonQuestion::Type.filterable.include?(question.question_type)
          sheet.row(row_no).push answer_for_renderable_questions(answer, question)
        end
        row_no += 1
      end

      data = StringIO.new ''
      book.write data
      data.string
    end
  end

  private

  def answer_for_matrix_question(question)
    text = ""
    question.rating_questions.each_with_index do |rq, index|
      new_text = "#{rq.question_text} - #{@survey_answers[rq.id].try(:first).try(:selected_choices_to_str, rq) || "common_text.Not_Specified".translate}"
      text += index.zero? ? new_text : "\n#{new_text}"
    end
    return text
  end

  def answer_for_renderable_questions(answer, question)
    answer.present? ? answer.selected_choices_to_str(question) : "common_text.Not_Specified".translate
  end
end