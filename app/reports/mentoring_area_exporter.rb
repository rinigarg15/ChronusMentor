require 'prawn'
require 'rmagick'
require 'zip/filesystem'
require 'zip'
require 'uri'

class MentoringAreaExporter
  include ChronusFonts
  DefaultFontFamily = "OpenSans"
  FontSize = {
    title: 25,
    section_header: 21,
    sub_header: 18,
    default: 12,
    small: 10,
    smaller: 8
  }
  ForegroundColors = {:default => "000000", :gray => "888888", :light_gray => "CCCCCC", :header => "FFFFFF", :dark_gray => "555555", :green => "6D9887", :red => "FF000D"}
  BackgroundColors = {:light_1 => "F5F3EA", :light_2 => "FCFCF5", :header => "6D9887", :white => "FFFFFF", :faded_green => "80A0A6", :green => "3B9C2B", :red => "FF000D", :gray => "888888"}
  MilestoneColors = {overdue: "FF000D", completed: "000000", current: "3B9C2B", not_started: "888888"}

  class << self
    include ScrapsHelper
    include ApplicationHelper
    include MentoringModel::MilestonesHelper
    include MentoringModelUtils

    def generate_zip(user, group, non_member_view, scraps_with_attachements, notes_with_attachments, pdf_file_name, is_super_console=false)
      pdf_data = generate_pdf(user, group, non_member_view, is_super_console)
      seed = "#{Time.now.to_i}#{SecureRandom.hex(4)}"
      zip_file_path = "#{Rails.root}/tmp/Mentoring_Area_#{seed}.zip"
      can_admin_enter_mentoring_connection = group.admin_enter_mentoring_connection?(user, is_super_console)

      Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
        zipfile.file.open(pdf_file_name, "w") { |f| f.puts pdf_data }
        if scraps_with_attachements.any? && can_admin_enter_mentoring_connection
          zipfile.dir.mkdir(directory_name(:message))
          scraps_with_attachements.each do |scrap|
            file_name = get_base_name(scrap.attachment.path)
            zipfile.file.open("#{directory_name(:message)}/#{scrap.id}_#{file_name}", "w") do |f|
              f.puts scrap.attachment.content
            end
          end
        end
        if notes_with_attachments.any? && can_admin_enter_mentoring_connection
          zipfile.dir.mkdir(directory_name(:personal))
          notes_with_attachments.each do |notes|
            file_name = get_base_name(notes.attachment.path)
            zipfile.file.open("#{directory_name(:personal)}/#{notes.id}_#{file_name}", "w") do |f|
              f.puts notes.attachment.content
            end
          end
        end
      end

      return_data = open(zip_file_path).read
      File.delete(zip_file_path)
      return return_data
    end

    def directory_name(dir)
      return case dir
      when :personal
        "feature.connection.content.label.dir_name.personal_note_v1".translate
      when :message
        "feature.connection.content.label.dir_name.message".translate
      end
    end

    def generate_pdf(user, group, non_member_view, is_super_console=false)
      can_admin_enter_mentoring_connection = group.admin_enter_mentoring_connection?(user, is_super_console)
      pdf = Prawn::Document.new
      ChronusFonts.update_fonts(pdf)
      pdf.stroke_color ForegroundColors[:green]
      program = group.program
      pdf.indent(0, 100) do
        title_page(pdf, group, user, non_member_view)
      end
      pdf.indent(100) do
        if program.mentoring_connections_v2_enabled?
          summary_page(pdf, group, user)
          milestones = group.mentoring_model_milestones
          tasks = group.mentoring_model_tasks.includes(task_eager_loadables)
          if tasks.present?
            with_gray_stroke(pdf) do
              tasks_page(pdf, milestones, tasks, user, non_member_view)
            end
          end
        end

        # Scraps
        if group.scraps_enabled?
          scraps = (non_member_view && user.is_admin? && can_admin_enter_mentoring_connection) ? group.scraps : Scrap.of_member_in_ref_obj(user.member_id, group.id, Group.to_s).distinct
          if scraps.present?
            scraps_page(pdf, user, scraps)
          end
        end

        # Private Notes
        if !non_member_view && program.allow_private_journals?
          notes = group.private_notes.owned_by(user).latest_first
          notes_page(pdf, notes, user) if notes.present?
        end
      end
      number_string = "<page>"
      pdf.number_pages number_string, at: [pdf.bounds.right - 150, 0], width: 150, align: :right
      pdf.render
    end

    def get_formatted_time_in_zone(time, user, format)
      return "" unless time.present?
      zone = user.member.get_valid_time_zone
      DateTime.localize(time.in_time_zone(zone), format: format)
    end

    private

    def get_milestone_status_string(state)
      return case state
        when :overdue
          'feature.milestones.label.overdue'.translate
        when :completed
          'feature.milestones.label.Completed'.translate
        when :current
          'feature.milestones.label.in_progress'.translate
        when :not_started
          'feature.milestones.label.not_started'.translate
      end
    end

    def summary_page(pdf, group, user)
      start_new_page(pdf)
      section_header(pdf, 'feature.connection.export_pdf.header.summary'.translate)
      pdf.move_down 10
      get_activity_overview_summary(pdf, group)
      goals = group.mentoring_model_goals
      get_goals_summary(pdf, group, goals, user) if goals.present?
      milestones = group.mentoring_model_milestones
      get_milestones_summary(pdf, group, milestones) if milestones.present?
    end

    def get_activity_overview_summary(pdf, group)
      summary_page_sub_header(pdf, 'feature.connection.export_pdf.header.activity_overview'.translate)
      memberships = group.memberships.includes(:user)
      memberships_size = memberships.size

      activity_data = {}
      activity_data[:scraps_activity] = group.scraps_activity if group.scraps_enabled?
      activity_data[:meetings_activity] = group.meetings_activity if group.meetings_enabled?
      if group.program.mentoring_connections_v2_enabled? && group.program.surveys.of_engagement_type.present?
        activity_data[:survey_answers] = group.survey_answers.select(:user_id, :response_id, :group_id).distinct.group_by(&:user_id)
      end

      memberships.each_with_index do |membership, index|
        user_summary_details(pdf, membership, activity_data)
        unless index + 1 == memberships_size
          pdf.move_down 5
          with_gray_stroke(pdf) do
            pdf.stroke_horizontal_rule
          end
          pdf.move_down 5
        end
      end
      pdf.move_down 15
    end

    def user_summary_details(pdf, membership, activity_data)
      group = membership.group
      user = membership.user
      role_name = group.program.term_for(CustomizedTerm::TermType::ROLE_TERM, membership.role.name).term

      img_cell_options = {
        image_height: 50,
        image_width: 50,
        position: :center,
        vposition: :top,
        rowspan: 3
      }
      profile_pic_cell, tmp_img_path = render_image_cell(user, img_cell_options)
      activity_title_options = {
        align: :right,
        text_color: ForegroundColors[:gray],
        inline_format: true,
        colspan: 3
      }

      table = []
      table << [
        profile_pic_cell,
        {
          content: "#{user.name} - <color rgb='#{ForegroundColors[:gray]}'>#{role_name}</color>",
          align: :left,
          inline_format: true,
          colspan: 6
        }
      ]

      activity_row = []
      unless activity_data[:scraps_activity].nil?
        activity_row += [
          { content: 'feature.connection.export_pdf.content.messages_sent'.translate }.merge(activity_title_options),
          activity_data[:scraps_activity][user.member_id].to_i
        ]
      end
      unless activity_data[:meetings_activity].nil?
        meetings_term = user.program.term_for(CustomizedTerm::TermType::MEETING_TERM).pluralized_term
        activity_row += [
          { content: 'feature.connection.export_pdf.content.meetings_attended'.translate(meetings: meetings_term) }.merge(activity_title_options),
          activity_data[:meetings_activity][user.member_id].to_i
        ]
      end
      unless activity_data[:survey_answers].nil?
        activity_row += [
          { content: 'feature.connection.export_pdf.content.survey_responses'.translate }.merge(activity_title_options),
          activity_data[:survey_answers][user.id].try(:count).to_i
        ]
      end
      table << activity_row

      if group.program.mentoring_connections_v2_enabled?
        tasks = membership.mentoring_model_tasks
        done_count, overdue_count, pending_count = get_task_counts_by_status(tasks)
        table << [
          { content: 'feature.connection.export_pdf.header.tasks'.translate }.merge(activity_title_options),
          { content: get_task_status_str(done_count, overdue_count, pending_count), align: :left, colspan: 5, inline_format: true }
        ]
      end

      table_options = {
        cell_style: {
          border_width: 0,
          size: FontSize[:small],
          valign: :center
        }
      }
      pdf.table(table, table_options)
      File.delete(tmp_img_path)
    end

    def get_goals_summary(pdf, group, goals, user)
      summary_page_sub_header(pdf, 'feature.connection.export_pdf.header.goals'.translate)
      required_tasks = group.mentoring_model_tasks.required
      model = group.mentoring_model || group.program.default_mentoring_model
      is_manual_progress_goal = model.manual_progress_goals?
      goals.each do |goal|
        pdf.font DefaultFontFamily, style: :bold
        pdf.text goal.title, align: :left
        goal_tasks = goal.mentoring_model_tasks
        if is_manual_progress_goal
          goal_status = goal.completion_percentage
          pdf.move_up FontSize[:default]
          pdf.text "#{goal_status}%", align: :right
          table_options = {
            :column_widths => {0 => 4.40*goal_status, 1 => 4.40*(100 - goal_status)},
            :cell_style => {:border_width => 0, :size => FontSize[:small], :valign => :center}
          }
          pdf.table([[
            pdf.make_cell("", background_color: BackgroundColors[:green]),
            pdf.make_cell("", background_color: BackgroundColors[:gray])
          ]], table_options)
          pdf.move_down 10
          pdf.font DefaultFontFamily, style: :normal
          get_goal_activity_summary(pdf, goal, user)
        elsif goal_tasks.present?
          done_count, overdue_count, pending_count = get_task_counts_by_status(goal_tasks)
          all_count = (done_count + overdue_count + pending_count).to_f
          goal_status = goal.completion_percentage(required_tasks)
          pdf.move_up FontSize[:default]
          pdf.text "#{goal_status}%", align: :right
          pdf.font DefaultFontFamily
          table_options = {
            :column_widths => {0 => 440*(done_count/all_count), 1 => 440*(overdue_count/all_count), 2 => 440*(pending_count/all_count)},
            :cell_style => {:border_width => 0, :size => FontSize[:small], :valign => :center}
          }
          pdf.table([[
            pdf.make_cell("", background_color: BackgroundColors[:green]),
            pdf.make_cell("", background_color: BackgroundColors[:red]),
            pdf.make_cell("", background_color: BackgroundColors[:gray])
          ]], table_options)
          pdf.move_down 10
          pdf.font_size FontSize[:small]
          task_header = "<color rgb='#{ForegroundColors[:gray]}'>#{'feature.connection.export_pdf.header.tasks'.translate}</color>    "
          pdf.text "#{task_header} #{get_task_status_str(done_count, overdue_count, pending_count)}", inline_format: true
          pdf.font_size FontSize[:default]
        end
        pdf.move_down 15
      end
      pdf.font DefaultFontFamily
    end

    def goal_activity_title_text(goal_activity, user)
      if goal_activity.progress_value.present?
        "feature.mentoring_model.label.goal_process_updated_by#{"_self" if goal_activity.member_id == user.member_id}_html".translate(user: goal_activity.member.name , percent: goal_activity.progress_value.to_i)
      else
        "feature.mentoring_model.label.goal_comment_by#{"_self" if goal_activity.member_id == user.member_id}_html".translate(user: goal_activity.member.name)
      end
    end

    def get_goal_activity_summary(pdf, goal, user)
      table_options = { column_widths: [20, 360, 50],
        :cell_style => {:border_width => 0, :size => FontSize[:smaller], :valign => :center}
      }
      img_cell_options = {
        image_height: 15,
        image_width: 15,
        position: :center,
        vposition: :top,
        rowspan: 2
      }
      styling_options = {inline_format: true}
      goal.goal_activities.recent.each do |activity|
        basic_text_styling = activity.message.present? ? styling_options : styling_options.merge(rowspan: 2,:valign => :center)
        profile_pic_cell, tmp_img_path = render_image_cell(activity.member, img_cell_options)
        cells = [[
            profile_pic_cell,
            {content: goal_activity_title_text(activity, user), text_color: ForegroundColors[:default], padding_top: 0, padding_left: 3, padding_bottom: 0, padding_right: 0}.merge(basic_text_styling),
            {content: get_formatted_time_in_zone(activity.created_at, user, :abbr_short), :valign => :center, align: :right, text_color: ForegroundColors[:gray], padding: 0}.merge(styling_options)
          ]]
        cells << [{content: activity.message, text_color: ForegroundColors[:gray], padding_top: 0, padding_left: 3, padding_bottom: 0, padding_right: 0}.merge(styling_options)]
        pdf.table(cells, table_options)
        pdf.move_down 3
        File.delete(tmp_img_path)
      end
    end

    def get_milestones_summary(pdf, group, milestones)
      summary_page_sub_header(pdf, 'feature.connection.export_pdf.header.milestones'.translate)
      current_milestone = group.status != Group::Status::CLOSED ? (milestones.current.first.presence || milestones.last) : nil
      milestone_statuses = {
        overdue: milestones.overdue.pluck(:id),
        completed: milestones.completed.pluck(:id),
        current: current_milestone
      }
      milestone_cells = []
      image_cells = []
      milestone_title_cells = []
      milestones.each_with_index do |milestone, index|
        milestone_status = get_milestone_status(milestone, milestone_statuses)
        if milestone.id == current_milestone.try(:id)
          image_cells << {image: "#{Rails.root}/app/assets/images/triangle.png", position: :center, vposition: :top, image_width: 10, :border_width => 0}
          image_title_cell = {image: "#{Rails.root}/app/assets/images/right_triangle.png", position: :right, vposition: :center, image_width: 10, :border_width => 0}
        else
          image_cells << pdf.make_cell("")
          image_title_cell = pdf.make_cell("")
        end
        milestone_cells << pdf.make_cell("", background_color: MilestoneColors[milestone_status], border_widths: [0, 5, 0, 0])
        milestone_title_cells << [image_title_cell, pdf.make_cell("#{index + 1}. #{milestone.title} (#{get_milestone_status_string(milestone_status)})")]
      end
      table_options = {
        :cell_style => {:valign => :center, border_color: BackgroundColors[:white]}, width: 440
      }
      pdf.table([milestone_cells, image_cells], table_options)
      pdf.table(milestone_title_cells, table_options.merge(column_widths: {0 => 20}))
    end

    def tasks_page(pdf, milestones, tasks, user, non_member_view)
      start_new_page(pdf)
      section_header(pdf, 'feature.connection.export_pdf.header.tasks'.translate)
      pdf.font_size FontSize[:small]
      if milestones.present?
        milestones.each do |milestone|
          milestone_tasks = tasks.select{|task| task.milestone_id == milestone.id}
          if milestone_tasks.present?
            render_milestone_for_tasks(pdf, milestone)
            render_tasks(pdf, milestone_tasks, user, non_member_view)
          end
        end
      else
        render_tasks(pdf, tasks, user, non_member_view)
      end
    end

    def render_milestone_for_tasks(pdf, milestone)
      pdf.move_down 5
      pdf.stroke_horizontal_rule
      pdf.move_down 10
      pdf.text milestone.title
    end

    def render_tasks(pdf, tasks, user, non_member_view)
      row_arr = []
      tmp_img_paths = []
      img_cell_options = {
        image_height: 15,
        image_width: 15,
        position: :center,
        vposition: :center
      }
      tasks.each do |task|
        date = get_formatted_time_in_zone(task.due_date, user, :abbr_short)
        task_user = task.connection_membership && task.connection_membership.user
        date_color = task.overdue? ? ForegroundColors[:red] : ForegroundColors[:gray]
        title_color = !non_member_view && task_user && task_user == user ? ForegroundColors[:default] : ForegroundColors[:gray]
        if task_user
          profile_pic_cell, tmp_img_path = render_image_cell(task_user, img_cell_options)
          tmp_img_paths << tmp_img_path
        else
          profile_pic_cell = ""
        end

        date_cell = pdf.make_cell(date, text_color: date_color)
        title_cell = pdf.make_cell(task.title, text_color: title_color)
        status_cell = task.done? ? {image: "#{Rails.root}/app/assets/images/done.png"}.merge(img_cell_options) : ""
        row_arr << [date_cell, status_cell, profile_pic_cell, title_cell]
      end

      table_options = {
        :column_widths => {0 => 70, 1 => 20, 2 => 20},
        :cell_style => {:border_width => 0, :size => FontSize[:small], :valign => :center}
      }
      pdf.table(row_arr, table_options)
      tmp_img_paths.uniq.collect{|tmp_img_path| File.delete(tmp_img_path)}
    end

    def notes_page(pdf, notes, user)
      start_new_page(pdf)
      section_header(pdf, 'feature.connection.export_pdf.header.my_notes'.translate)
      notes.each do |note|
        pdf.move_down 15
        pdf.font_size FontSize[:small]
        pdf.fill_color ForegroundColors[:gray]
        small_header = []
        small_header << get_formatted_time_in_zone(note.created_at.to_time, user, :full_display_no_day)
        if note.attachment?
          small_header << "#{note.id}_#{note.attachment_file_name}"
        end
        pdf.text small_header.join(" | ")
        pdf.fill_color ForegroundColors[:default]
        pdf.font_size FontSize[:default]
        pdf.move_down 5
        pdf.text note.text
        pdf.move_down 15
        pdf.stroke_horizontal_rule
      end
    end

    def title_page(pdf, group, user, non_member_view)
      program = group.program
      title_overview_details(pdf, group, user, program)

      role_terms_hash = RoleConstants.program_roles_mapping(program, pluralize: true)
      program.roles.for_mentoring.each do |role|
        memberships = group.memberships.where(role_id: role.id)
        if memberships.exists?
          pdf.stroke_horizontal_rule
          pdf.move_down 20
          pdf.font_size FontSize[:sub_header]
          pdf.text role_terms_hash[role.name]
          pdf.move_down 10
          pdf.font_size FontSize[:default]
          pdf.fill_color ForegroundColors[:default]
          memberships.includes(:user).each do |membership|
            user_details(pdf, membership.user, user)
          end
          pdf.fill_color ForegroundColors[:green]
        end
      end
      title_page_footer(pdf, program)
    end

    def title_page_footer(pdf, program)
      start_new_page(pdf) if pdf.y < 120
      pdf.y = 120
      pdf.stroke_horizontal_rule
      pdf.move_down 10
      pdf.font_size FontSize[:sub_header]

      if program.logo_or_banner_url.present?
        img_cell_options = {
          pic_path: program.logo_or_banner_url,
          fit: [100, 50],
          position: :left,
          vposition: :center
        }
        program_pic_cell, tmp_img_path = render_image_cell(nil, img_cell_options)
        program_name_cell = pdf.make_cell(program.name, align: :left)
        table_options = {
          :column_widths => {0 => 110, 1 => 330},
          :cell_style => {:border_width => 0, :valign => :center}
        }
        pdf.table([[program_pic_cell, program_name_cell]], table_options)
        File.delete(tmp_img_path)
      else
        pdf.text program.name, align: :left
      end
      pdf.font_size FontSize[:default]
    end

    def title_overview_details(pdf, group, user, program)
      pdf.move_down 80
      pdf.fill_color ForegroundColors[:green]
      pdf.stroke_horizontal_rule
      pdf.move_down 30
      pdf.font DefaultFontFamily, style: :bold
      pdf.font_size FontSize[:title]
      pdf.indent(10) do
        pdf.text 'feature.connection.export_pdf.title'.translate(group: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term)
        pdf.move_down 10
        pdf.font DefaultFontFamily
        pdf.font_size 15
        pdf.fill_color ForegroundColors[:gray]
        full_date = Time.now
        time = get_formatted_time_in_zone(full_date, user, :short_time)
        date = get_formatted_time_in_zone(full_date, user, :full_display_no_time)
        zone = user.member.short_time_zone
        pdf.text 'feature.connection.export_pdf.content.as_of_content'.translate(content: "#{date} | #{time}, #{zone}")
        pdf.move_down 10
        pdf.font_size FontSize[:small]
        pdf.text "#{'feature.connection.export_pdf.content.start_date'.translate} : #{get_formatted_time_in_zone(group.published_at, user, :full_display_no_time)}"
        pdf.text "#{'feature.connection.export_pdf.content.end_date'.translate}  : #{get_formatted_time_in_zone(group.expiry_time, user, :full_display_no_time)}"
        pdf.fill_color ForegroundColors[:green]
        pdf.font_size FontSize[:default]
        pdf.move_down 15
      end
    end

    def user_details(pdf, user, viewer)
      image_height = render_image(pdf, user)

      pdf.indent(50) do
        pdf.move_up(image_height)
        pdf.pad_top(5) do
          pdf.font DefaultFontFamily, style: :bold
          pdf.text user.name
          pdf.font DefaultFontFamily
        end
        pdf.pad_bottom(10) do
          pdf.font_size FontSize[:small]
          pdf.text user.email if display_email(viewer, user)
          pdf.font_size FontSize[:default]
        end
      end
      pdf.move_down 20
    end

    def scraps_page(pdf, user, scraps)
      start_new_page(pdf)
      section_header(pdf, "feature.connection.action.Messages".translate)

      root_scrap_ids = scraps.collect(&:root_id).uniq
      root_scraps = scraps.select{|sc| root_scrap_ids.include?(sc.id)}
      grouped_child_scraps = {}
      sender_names = {}
      scraps.each do |sc|
        grouped_child_scraps[sc.root_id] ||= []
        grouped_child_scraps[sc.root_id] << sc
        sender_names[sc.root_id] ||= []
        sender_names[sc.root_id] << (sc.sender_name || sc.sender.name)
      end
      root_scrap_ids.each {|root_scrap_id| sender_names[root_scrap_id] = sender_names[root_scrap_id].uniq.to_sentence}

      scraps_data = []

      root_scraps.each do |root_scrap|
        root_cell = pdf.make_cell(
          :content => "<font size='10'><b>#{root_scrap.subject}</b></font>\n\n<font_size='8'>#{sender_names[root_scrap.id]}</font>",
          :inline_format => true
        )

        scraps_data << [pdf.make_table([[root_cell]],
          :cell_style => {:text_color => ForegroundColors[:default], :width => 440, :border_color => ForegroundColors[:green], :border_width => [1, 1, 1, 5]})]

        grouped_child_scraps[root_scrap.id].each do |child_scrap|
          child_scrap_info = ""
          child_scrap_info += "#{'feature.mentoring_model.label.from'.translate} #{child_scrap.sender_name || child_scrap.sender.name}"
          child_scrap_info += " | #{get_formatted_time_in_zone(child_scrap.created_at.to_time, user, :abbr_short_day_first_full_month)}"
          if child_scrap.attachment?
            child_scrap_info += " | #{child_scrap.id}_#{child_scrap.attachment_file_name}"
          end

          cell_1 = pdf.make_cell(child_scrap_info,
            :width => 440,
            :text_color => ForegroundColors[:dark_gray],
            :size => FontSize[:smaller],
            :border_width => 0
          )

          cell_2 = pdf.make_cell(child_scrap.content,
            :width => 440,
            :text_color => ForegroundColors[:default],
            :size => FontSize[:small],
            :border_widths => [0, 0, 1, 0],
            :border_color => ForegroundColors[:light_gray]
          )

          scraps_data << [pdf.make_table([[cell_1], [cell_2]], :cell_style => {:padding => 5})]
        end
      end

      pdf.table(scraps_data, :cell_style => {:border_width => 0}, :width => 440)
      pdf.font(DefaultFontFamily)
      pdf.font_size FontSize[:default]
    end

    def start_new_page(pdf)
      pdf.font_size FontSize[:default] # Reset font
      pdf.start_new_page
    end

    def page_header(pdf, header)
      pdf.font_size 20
      pdf.text header
      pdf.stroke_horizontal_rule
      pdf.font_size FontSize[:default]
      pdf.move_down 20
    end

    def render_image(pdf, user)
      pic_path = ImportExportUtils.file_url(user.picture_url(:small))
      base_name = File.basename(get_base_name(pic_path), ".*")
      seed = "#{Time.now.to_i}#{SecureRandom.hex(4)}"
      tmp_img_path = "#{Rails.root}/tmp/#{base_name}_#{seed}.jpg"
      img = ImportExportUtils.copy_image(tmp_img_path, pic_path)

      pdf.image(tmp_img_path)
      File.delete(tmp_img_path)

      return img.rows
    end

    def render_image_cell(user, img_cell_options = {})
      pic_path = ImportExportUtils.file_url(img_cell_options.delete(:pic_path) || user.picture_url(:small))
      base_name = File.basename(get_base_name(pic_path), ".*")
      seed = "#{Time.now.to_i}#{SecureRandom.hex(4)}"
      tmp_img_path = "#{Rails.root}/tmp/#{user.try(:id)}_#{base_name}_#{seed}.jpg"
      img = ImportExportUtils.copy_image(tmp_img_path, pic_path)
      profile_pic_cell = {image: tmp_img_path}.merge(img_cell_options)
      [profile_pic_cell, tmp_img_path]
    end

    def get_base_name(file_path)
      File.basename(URI.decode(URI.parse(URI.encode(file_path)).path))
    end

    def section_header(pdf, title)
      pdf.fill_color ForegroundColors[:header]
      pdf.font_size FontSize[:section_header]
      pdf.table([[title]], :column_widths => {0 => 440}, :cell_style => {:border_width => 0, :height => 85}, :row_colors => [BackgroundColors[:header]])
      pdf.fill_color ForegroundColors[:default]
      pdf.font_size FontSize[:default]
      pdf.move_down 10
    end

    def summary_page_sub_header(pdf, sub_heading)
      pdf.fill_color ForegroundColors[:green]
      pdf.stroke_horizontal_rule
      pdf.move_down 20
      pdf.font_size FontSize[:sub_header]
      pdf.text sub_heading
      pdf.move_down 15
      pdf.font_size FontSize[:default]
      pdf.fill_color ForegroundColors[:default]
    end

    def with_gray_stroke(pdf)
      pdf.stroke_color ForegroundColors[:gray]
      yield
      pdf.stroke_color ForegroundColors[:green]
    end

    def get_task_counts_by_status(tasks)
      done_count, overdue_count, pending_count = [0, 0, 0]
      tasks.each do |task|
        if task.done?
          done_count += 1
        elsif task.overdue?
          overdue_count += 1
        elsif task.pending?
          pending_count += 1
        end
      end
      [done_count, overdue_count, pending_count]
    end

    def get_task_status_str(done_count, overdue_count, pending_count)
      done_text = "<color rgb='#{ForegroundColors[:default]}'>#{done_count} #{'feature.mentoring_model.label.completed_label'.translate}</color>"
      overdue_text = "<color rgb='#{ForegroundColors[:red]}'>#{overdue_count} #{'feature.mentoring_model.label.overdue_label'.translate}</color>"
      pending_text = "<color rgb='#{ForegroundColors[:gray]}'>#{pending_count} #{'feature.mentoring_model.label.pending_label'.translate}</color>"
      "#{done_text}, #{overdue_text}, #{pending_text}"
    end

    def display_email(viewer, user)
      email_profile_question = user.program.organization.email_question
      email_role_questions = email_profile_question.role_questions.where(role_id: user.roles.pluck(:id)).to_a
      email_role_questions.map!{|ques| ques.visible_for?(viewer, user)}
      return email_role_questions.reduce(:|)
    end
  end
end
