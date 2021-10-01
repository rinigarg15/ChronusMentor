# Mentoring connections related tasks
namespace :connection do
  # Usage: rake connection:generate_tasks_report DOMAIN="localhost.com" SUBDOMAIN="sub" ROOT="p1" QUESTION_IDS="10,12" LOCALE="en"
  desc "Mentoring Model Tasks report for a program"
  task generate_tasks_report: :environment do
    programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])
    program = programs[0]
    question_ids = ENV["QUESTION_IDS"].split(",").map(&:to_i)
    locale = ENV["LOCALE"] || I18n.default_locale

    user_id_member_id_map = program.users.pluck("id, member_id").to_h

    query = program.users.joins(:member).includes(:profile_answers).select("users.id, CONCAT(members.first_name, ' ', members.last_name)")
    user_id_name_map = ActiveRecord::Base.connection.exec_query(query.to_sql).rows.to_h

    groups = program.groups
    group_id_student_id_map = groups.joins(:student_memberships).group("groups.id").pluck("groups.id, GROUP_CONCAT(connection_memberships.user_id)").to_h
    group_id_mentor_id_map = groups.joins(:mentor_memberships).group("groups.id").pluck("groups.id, GROUP_CONCAT(connection_memberships.user_id)").to_h

    question_headers, questions = get_question_header_details(program, question_ids)
    question_ids = questions.map(&:id)

    question_type_map = organization.profile_questions.pluck(:id, :question_type).to_h
    choice_text_map = QuestionChoice.includes(:translations)
                        .where(ref_obj_id: question_ids, ref_obj_type: ProfileQuestion.name, question_choice_translations: { locale: locale } )
                        .pluck("question_choices.id, question_choice_translations.text")
                        .to_h

    query = %Q[
      select u.id, p.profile_question_id, GROUP_CONCAT(DISTINCT(p.answer_text)) AS answer_text, GROUP_CONCAT(a.question_choice_id) AS answer_choices
      FROM users u
      LEFT JOIN members m ON u.member_id = m.id
      LEFT JOIN profile_answers p ON p.ref_obj_id = m.id AND p.ref_obj_type = 'Member'
      LEFT JOIN answer_choices a ON a.ref_obj_id = p.id AND a.ref_obj_type = 'ProfileAnswer'
      WHERE p.profile_question_id IN (#{question_ids.join(",")}) AND u.id IN (#{program.users.map(&:id).join(",")})
      GROUP BY u.id, p.profile_question_id;
    ]

    rows = ActiveRecord::Base.connection.exec_query(query).rows
    user_id_question_answers_map = rows.map { |row| [row.first(2), row[2..-1]] }.to_h

    CSV.open("/tmp/task_details_#{program.id}.csv", "w") do |csv|
      csv << ["Mentor Name", "Mentee Name", *question_headers.flatten, "Connection Name", "Connection Start Date", "Task Name", "Task Owner", "Completed"]
      groups.where(status: Group::Status::CLOSED).includes(mentoring_model_tasks: :connection_membership).find_each do |group|
        mentor_ids = group_id_mentor_id_map[group.id].split(",").map(&:to_i)
        student_ids = group_id_student_id_map[group.id].split(",").map(&:to_i)

        mentor_names = mentor_ids.inject([]) {|names, mentor_id| names << user_id_name_map[mentor_id] }.join(", ")
        student_names = student_ids.inject([]) {|names, student_id| names << user_id_name_map[student_id] }.join(", ")

        mentor_answers = get_answers_for_users(mentor_ids, question_ids, user_id_question_answers_map: user_id_question_answers_map, choice_text_map: choice_text_map, question_type_map: question_type_map, user_id_name_map: user_id_name_map)
        student_answers = get_answers_for_users(student_ids, question_ids, user_id_question_answers_map: user_id_question_answers_map, choice_text_map: choice_text_map, question_type_map: question_type_map, user_id_name_map: user_id_name_map)

        group.mentoring_model_tasks.each do |task|
          task_detail = [mentor_names, student_names, *mentor_answers, *student_answers, group.name, DateTime.localize(group.published_at, format: :abbr_short), task.title]
          task_detail << (task.connection_membership.present? ? user_id_name_map[task.connection_membership.user_id] : "Unassigned")
          task_detail << task.done?
          csv << task_detail
        end
      end
    end
  end

  private

  def get_question_header_details(program, question_ids)
    valid_questions = program.organization.profile_questions.where(id: question_ids)
    valid_question_texts = valid_questions.map(&:question_text)
    valid_question_ids = valid_questions.map(&:id)
    invalid_questions = (question_ids - valid_question_ids)
    if invalid_questions.present?
      raise("Could not find Question with ID: #{valid_question_ids.join(", ")}")
    else
      [["Mentor", "Mentee"].map { |role| valid_question_texts.map { |question| "#{role} - #{question}" } }, valid_questions]
    end
  end

  def get_answers_for_users(user_ids, question_ids, options = {})
    user_id_question_answers_map = options[:user_id_question_answers_map]
    choice_text_map = options[:choice_text_map]
    question_type_map = options[:question_type_map]
    user_id_name_map = options[:user_id_name_map]
    question_ids.map do |question_id|
      user_ids.map do |user_id|
        user_name = user_id_name_map[user_id]
        question_answers = user_id_question_answers_map[[user_id, question_id]]
        name_pointer = user_name + " -> ["
        if question_answers.present?
          name_pointer + if ProfileQuestion::Type.choice_based_types.include?(question_type_map[question_id].to_i)
            question_answers[1].split(",").map { |choice_id| "'#{choice_text_map[choice_id.to_i]}'" }.join(",")
          else
            question_answers[0]
          end + "]"
        end
      end.compact.join(",")
    end
  end
end