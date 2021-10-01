require 'prawn'
require 'csv'

class MentorRequestReport
  include ChronusFonts
  DefaultFontSize = 12
  SmallFontSize = 10
  ForegroundColors = { default: "000000", gray: "888888", light_gray: "CCCCCC", header: "900000" }
  BackgroundColors = { light_1: "F5F5F0", light_2: "FCFCF5", white: "FFFFFF"}

  # CSV exporting logic
  module CSV
    class << self
      # Generates CSV data for the given +requests+ of the +program+
      def generate(program, requests)
        ::CSV.generate do |csv|
          csv << csv_header(program)
          # Reload the object because Delayed::Job is not handling
          # deserializing of objects does not result in loading of
          # associations
          MentorRequest.sort_by_student(requests, program).each do |m_req|
            m_req.reload
            student = m_req.student
            match_array = student.get_student_cache_normalized

            request_created_at = DateTime.localize(m_req.created_at, format: :full_display)
            message = m_req.message
            req_favorites = m_req.request_favorites
            if req_favorites.empty?
              none_string = "display_string.None".translate
              csv << [student.name, student.email, (1..4).map{none_string}, request_created_at, message].flatten
            else
              req_favorites.order(:position).each do |request_favorite|
                favorite = request_favorite.favorite
                line_item = [student.name]
                line_item << student.email
                line_item << favorite.name
                line_item << favorite.email
                line_item << "#{match_array[favorite.id]}%"
                line_item << request_favorite.position.to_s
                line_item << request_created_at
                line_item << message
                csv << line_item
              end
            end
          end
        end
      end

      # Mentee Name, Mentee Email, Preferred Mentor Name, Preferred Mentor Email, Match Score, Preference number, Requested On
      def csv_header(program)
        mentor_name = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
        mentee_name = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term

        headers = []
        headers << "feature.mentor_request.label.csv_headers.mentee_name".translate(Mentee: mentee_name)
        headers << "feature.mentor_request.label.csv_headers.mentee_email".translate(Mentee: mentee_name)
        headers << "feature.mentor_request.label.csv_headers.preferred_mentor_name".translate(Mentor: mentor_name)
        headers << "feature.mentor_request.label.csv_headers.preferred_mentor_email".translate(Mentor: mentor_name)
        headers << "feature.mentor_request.label.csv_headers.match_score".translate
        headers << "feature.mentor_request.label.csv_headers.mentee_preference".translate(Mentee: mentee_name)
        headers << "feature.mentor_request.label.csv_headers.requested_on".translate
        headers << "feature.mentor_request.label.Request".translate
        headers
      end

      # Returns string of the format "Name <email>" for the
      # mentor
      def mentor_data(user)
        "#{user.name} <#{user.email}>"
      end
    end
  end

  module PDF
    class << self
      def generate(mentor_request_ids, list_field)
        reqs = MentorRequest.where(id: mentor_request_ids)
        pdf = Prawn::Document.new
        ChronusFonts.update_fonts(pdf)
        program = reqs.first.program
        student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME, :default => false, :skype => false, pq_translation_include: true)

        # Facing page
        facing_page(pdf, program, list_field)
        pdf.font_size DefaultFontSize # Reset font
        pdf.start_new_page

        # Print each request with student profile in a page
        reqs.each do |m_req|
          # Reload the object because Delayed::Job deserializing of objects
          # does not result in loading of associations
          m_req.reload
          page_header(pdf, m_req)
          request_details(pdf, m_req, list_field)
          student_profile(pdf, m_req.student, student_questions)
          pdf.start_new_page
        end

        pdf.render
      end

      def facing_page(pdf, program, list_field)
        report_name = "feature.mentor_request.label.report.report_name.#{list_field}".translate(mentoring: program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase)
        pdf.move_down 200
        pdf.stroke_horizontal_rule
        pdf.move_down 50
        pdf.font_size 30
        pdf.text report_name, :align => :center
        pdf.font_size DefaultFontSize
        pdf.text program.name, :align => :center
        pdf.text "feature.mentor_request.label.report.generated_at".translate(date: Date.today), :align => :center
        pdf.move_down 50
        pdf.stroke_horizontal_rule
        pdf.font_size DefaultFontSize # Reset font
        pdf.start_new_page
      end

      # Prints request details
      def request_details(pdf, m_req, list_field)
        student = m_req.student
        section_header(pdf, "feature.mentor_request.label.report.request_details".translate)

        name_data = []
        value_data = []

        name_data << "feature.mentor_request.label.report.sent".translate
        value_data << DateTime.localize(m_req.created_at, format: :short_year)

        print_table_and_clear_data(pdf, name_data, value_data)

        student_favorites(pdf, m_req) if m_req.program.preferred_mentoring_for_mentee_to_admin?

        if (list_field == "accepted" && !student.mentors.empty?)
          mentor_name = m_req.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term.pluralize
          name_data << "feature.mentor_request.label.report.assigned_mentors".translate(:Mentors => mentor_name)
          value_data << student.mentors.collect { |mentor| mentor.name }.join(", ")
        end
        name_data << "feature.mentor_request.label.report.request".translate
        value_data << m_req.message
        print_table_and_clear_data(pdf, name_data, value_data)
      end

      def student_favorites(pdf, m_req)
        # Verify empty favorites case
        mentor_name = m_req.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term
        if m_req.favorites.empty?
          print_table_and_clear_data(pdf, ["feature.mentor_request.label.report.preferred_mentors_header".translate(:Mentors => mentor_name.pluralize)], ["display_string.None".translate])
          return
        end

        student = m_req.student
        match_results = student.student_document_available? ? student.student_cache_normalized(true) : nil
        req_favorite_date = m_req.request_favorites.map do |req_fav|
          match_score = match_results.present? && match_results[req_fav.favorite.id].present? ? "#{match_results[req_fav.favorite.id]} %" : "display_string.NA".translate
          [ nil, nil,
            req_fav.favorite.name,
            match_score,
            req_fav.note.blank? ? "-" : req_fav.note ]
        end
        table_data = [["feature.mentor_request.label.report.preferred_mentors_header".translate(:Mentors => mentor_name.pluralize), ":" ,"feature.mentor_request.label.report.mentor_name_header".translate(:Mentor => mentor_name) , "feature.mentor_request.label.report.match".translate, "feature.mentor_request.label.report.reason_for_prefrence".translate]] + req_favorite_date
        table_data[1][0] = "<color rgb='888888'>" + "feature.mentor_request.label.report.in_order_of_preference".translate + "</color>"

        pdf.table table_data,
          :cell_style => {:border_color => "FFFFFF",:border_width => 0, :align => :left, :padding => [2,5,2,5], :inline_format => true},
          :column_widths => {0 => 135, 1 => 20, 2 => 150, 3 => 50, 4 => 200},
          :width => 555,
          :row_colors => [BackgroundColors[:light_1]]
      end

      # Prints the given student's profile.
      def student_profile(pdf, student, student_questions)
        section_header(pdf, "feature.mentor_request.label.report.student_profile".translate(student_name: student.name))
        name_data = ["app_constant.question_type.Email".translate]
        value_data = [student.email]

        student_questions.each do |question|
          answer = student.answer_for(question)
          answer_value = answer.blank? ? "-" : question.format_profile_answer_for_xls(answer)
          name_data << question.question_text
          value_data << answer_value
        end

        print_table_and_clear_data(pdf, name_data, value_data)
      end

      def print_table_and_clear_data(pdf, name_data, value_data)
        pdf.table name_data.zip(Array.new(value_data.size, ":"), value_data),
          :column_widths => {0 => 135, 1 => 20, 2 => 400},
          :width => 555,
          :cell_style => {:border_width => 0},
          :row_colors => [BackgroundColors[:light_1], BackgroundColors[:light_2]]

        name_data.clear
        value_data.clear
      end

      def page_header(pdf, m_req)
        student = m_req.student
        pdf.save_font do
          pdf.font_size 20
          pdf.text student.name, :align => :center
        end

        # 10pt margin bottom
        pdf.move_down 15
      end

      # A sub header
      def section_header(pdf, text)
        # 10pt margin top
        pdf.move_down 10

        pdf.save_font do
          pdf.font_size 15
          pdf.fill_color ForegroundColors[:header]
          pdf.text text
          pdf.fill_color ForegroundColors[:light_gray]
          pdf.move_down 5
          pdf.stroke_horizontal_rule
          pdf.fill_color ForegroundColors[:default]
        end

        # 10pt margin bottom
        pdf.move_down 10
      end
    end
  end
end