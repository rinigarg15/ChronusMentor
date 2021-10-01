require 'rmagick'
class ProfileExporter
  include ChronusFonts

  MULTILINE_SEPARATOR = "\n"
  SINGLE_SPACE = " "
  class << self
    def generate_pdf(program, user, questions_for_user, program_url)
      pdf = Prawn::Document.new
      ChronusFonts.update_fonts(pdf)
      pic_path = user.member.picture_path_for_pdf(:medium)
      base_name = File.basename(File.basename(URI.parse(pic_path).path), ".*")
      seed = "#{Time.now.to_i}#{SecureRandom.hex(4)}"
      tmp_img_path = "#{Rails.root}/tmp/#{base_name}_#{seed}.jpg"
      img = ImportExportUtils.copy_image(tmp_img_path, pic_path)
      pdf.image tmp_img_path, :position => 490, :vposition => 5
      File.delete(tmp_img_path)

      pdf.font_size 20
      pdf.move_up 35
      pdf.text "#{user.name(:name_only => true)}", :style => :bold
      pdf.move_down 5
      pdf.font_size 15
      pdf.text "#{program.name}"
      pdf.move_down 15
      pdf.stroke_horizontal_rule
      pdf.move_down 20

      pdf.font_size 12 # Reset font
      generate_section_and_questions(pdf, program, user, questions_for_user, program_url)
      pdf
    end

    private

    def generate_section_and_questions(pdf, program, user, questions_for_user, program_url)
      section_questions_hash = questions_for_user.group_by(&:section)
      section_questions_hash.keys.sort_by(&:position).each do |key|
        value = section_questions_hash[key].sort_by(&:position)
        pdf.move_down 10
        pdf.font_size 15
        pdf.text "#{key.title}", :align => :left, :style => :bold
        pdf.move_down 20

        request_info_rows = []

        if key.default_field?
          request_info_rows << ["Profile Url", "#{program_url}members/#{user.member.id}"]
        end

        value.each do |question|
          next unless question
          answer = user.answer_for(question)

          if question.email_type?
            ans_text =  user.email
          elsif question.name_type?
            ans_text =  user.name
          elsif answer.nil? || answer.unanswered?
            ans_text = "-"
          elsif question.file_type?
            ans_text = answer.attachment_file_name
          elsif question.date?
            ans_text = question.format_profile_answer(answer)
          elsif question.question_type == ProfileQuestion::Type::MULTI_CHOICE || question.question_type == ProfileQuestion::Type::MULTI_STRING || question.question_type == ProfileQuestion::Type::ORDERED_OPTIONS
            ans_text = answer.answer_value.join("\n")
          elsif question.question_type == ProfileQuestion::Type::SINGLE_CHOICE || question.question_type == ProfileQuestion::Type::ORDERED_SINGLE_CHOICE
            ans_text = answer.answer_value
          elsif question.education?
            ans_text = format_education_answer(answer)
          elsif question.experience?
            ans_text = format_experience_answer(answer)
          elsif question.publication?
            ans_text = format_publication_answer(answer)
          else
            ans_text = answer.answer_text
          end
          request_info_rows << [question.question_text, ans_text]
        end

        request_info_rows.each do |q, ans|
          pdf.fill_color "4A4A4A"
          pdf.text "#{q} :", :align => :left, :style => :bold
          pdf.fill_color "000000"
          pdf.move_down 5
          pdf.text ans, :align => :left
          pdf.move_down 15
        end

        pdf.move_down 10
        pdf.fill_color "CCCCCC"
        pdf.stroke_horizontal_rule
        pdf.fill_color "000000"
        pdf.move_down 15
      end
    end

    def page_header(pdf, header)
      pdf.font_size 20
      pdf.text header
      pdf.stroke_horizontal_rule
      pdf.font_size DefaultFontSize
      pdf.move_down 20
    end

    def format_education_answer(answer)
      answer.educations.inject([]) do |full_str, education|
        str = education.school_name
        degree_str = education.degree
        major_str = education.major
        date_str = education.graduation_year

        if degree_str.present? || major_str.present?
          degree_major_str = "#{[degree_str, major_str].select(&:present?).join(SINGLE_SPACE + 'display_string.in'.translate + SINGLE_SPACE)}"
        end

        if degree_major_str.present? || date_str.present?
          str = "#{[str, degree_major_str].select(&:present?).join(COMMON_SEPARATOR)}"
          str = "#{[str, date_str].select(&:present?).join(' | ')}"
        end
        full_str << str
      end.join(MULTILINE_SEPARATOR)
    end

    def format_experience_answer(answer)
      answer.experiences.inject([]) do |full_str, experience|
        str = experience.company
        title_str = experience.job_title

        if experience.dates_present?
          date_start_info = (fetch_workex_month(experience.start_month) + " " + experience.start_year.to_s).strip
          date_end_info = experience.current_job? ? "feature.education_and_experience.label.present".translate : (fetch_workex_month(experience.end_month) + " " + experience.end_year.to_s).strip
          date_str = (date_start_info.present? && date_end_info.present?) ? "#{date_start_info} - #{date_end_info}" : date_start_info + date_end_info
        end

        if title_str.present? || date_str.present?
          str = "#{[str, title_str].select(&:present?).join(COMMON_SEPARATOR)}"
          str = "#{[str, date_str].select(&:present?).join(' | ')}"
        end
        full_str << str
      end.join(MULTILINE_SEPARATOR)
    end

    def format_publication_answer(answer)
      full_str = []
      answer.publications.each_with_index do |publication, index|
        publisher = publication.publisher
        date = publication.formatted_date
        str = "#{index + 1}.#{SINGLE_SPACE}#{publication.title}#{ ' - ' + publication.url if publication.url.present?}#{MULTILINE_SEPARATOR}"
        str << "#{[publisher, date].select(&:present?).join(' | ')}#{MULTILINE_SEPARATOR}" if publisher.present? || date.present?
        str << "#{'feature.education_and_experience.content.authors'.translate} #{publication.authors}#{MULTILINE_SEPARATOR}" if publication.authors.present?
        str << "#{MULTILINE_SEPARATOR}#{publication.description}#{MULTILINE_SEPARATOR}" if publication.description.present?
        full_str << str
      end
      full_str.join(MULTILINE_SEPARATOR)
    end

    def fetch_workex_month(month_code)
      "date.abbr_month_names".translate[month_code].to_s
    end
  end
end