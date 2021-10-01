class CsvImporter::ImportUsers
  include CsvImporter::Utils

  attr_accessor :filename, :organization, :processed_rows, :program, :options, :failed_rows, :progress, :progress_count,
    :members_map, :answers_map, :users_map, :questions, :user_csv_import, :locale

  def initialize(user_csv_import, organization, program, options = {})
    @user_csv_import = user_csv_import
    @filename = user_csv_import.local_csv_file_path
    @processed_rows = CsvImporter::Cache.read(user_csv_import)
    @organization = organization
    @program = program
    @failed_rows = []
    @options = options
    @questions = options[:questions] || {}
    initialize_for_progress_bar if @processed_rows.present?
    @locale = options[:locale]||I18n.locale
  end

  def import
    GlobalizationUtils.run_in_locale(locale) do
      add_users
      update_users
      invite_users if program_level?
    end
    #Running SFTP feed and Import CSV users parallely might create duplicate other choice records. So cleaning other choice records post imports
    QuestionChoice.cleanup_duplicate_other_choices(@questions.select{|pq| pq.choice_or_select_type? && pq.allow_other_option?}.collect(&:id))
    CsvImporter::Cache.write_failures(user_csv_import, failed_rows)
    return failed_rows
  end

  private

  def initialize_for_progress_bar
    import_count = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :to_be_imported?).size
    @progress_count = 0
    @progress = ProgressStatus.create!(ref_obj: user_csv_import, maximum: import_count, for: ProgressStatus::For::CsvImports::IMPORT_DATA, completed_count: 0)
  end

  def program_level?
    program.present?
  end

  def add_users
    rows = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :is_user_to_be_added?)
    maintain_progress_count(rows) do |rows|
      initialize_member_information(rows)
      iterate_and_update_progress(rows) do |row|
        member = members_map[email(row.data)]
        create_or_update_member(member, row) ? nil : row
      end
    end
  end

  def update_users
    rows = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :is_user_to_be_updated?)
    maintain_progress_count(rows) do |rows|
      initialize_member_information(rows)
      iterate_and_update_progress(rows) do |row|
        member = members_map[email(row.data)]
        update_member_information(member, row) ? nil : row
      end
    end
  end

  def invite_users
    rows = CsvImporter::ProcessedRow.select_rows_where(processed_rows, :is_user_to_be_invited?)
    maintain_progress_count(rows) do |rows|
      iterate_and_update_progress(rows) do |row|
        invite_user(row.data) ? nil : row
      end
    end
  end

  def iterate_and_update_progress(rows, &block)
    results = Parallel.map(rows, :in_processes => 6) do |row|
      row_result, es_reindex_list = DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true, skip_dj_creation: true) do
        set_parallel_iteration_variables
        update_counter
        block.call(row)
      end
      {row: row_result, es_reindex_list: es_reindex_list}
    end
    format_and_map_results(results)
  end

  def format_and_map_results(results)
    failed_results = []
    es_reindex_list = {}
    results.each do |result|
      failed_results << result[:row]
      create_es_reindex_list!(result[:es_reindex_list], es_reindex_list)
    end
    @failed_rows += failed_results.select(&:present?)
    DelayedEsDocument.create_delayed_indexes_from_hash(es_reindex_list)
  end

  def create_es_reindex_list!(result_list, es_reindex_list)
    result_list.each do |model, ids|
      es_reindex_list[model] ||= []
      es_reindex_list[model] += Array(ids)
    end
  end

  def set_parallel_iteration_variables
    @reconnected ||= ActiveRecord::Base.connection.reconnect!
    @count ||= 0
    @counter ||= progress.counters.create!(count: 0)
  end

  def update_counter
    @counter.update_attribute(:count, @count) if (@count - @counter.count) >= progress_batch_size
    @count += 1
  end

  def create_or_update_member(member, row)
    begin
      ActiveRecord::Base.transaction do
        if member.present?
          update_member(member, row.data)
          existing_member = true
        else
          member = create_member(row.data)
          existing_member = false
        end
        create_or_update_profile(member, row.data)
        create_user(member, row, existing_member) if program_level?
      end
      return true
    rescue => e
      return false
    end
  end

  def update_member_information(member, row)
    begin
      ActiveRecord::Base.transaction do
        update_member(member, row.data)
        create_or_update_profile(member, row.data)
        create_or_update_user(member, row) if program_level?
      end
      return true
    rescue => e
      return false
    end
  end

  def update_member(member, row)
    member.first_name = row[UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym]
    member.last_name = row[UserCsvImport::CsvMapColumns::LAST_NAME.to_sym]
    member.build_login_identifiers_for_custom_auths(row[UserCsvImport::CsvMapColumns::UUID.to_sym]) if @options[:is_super_console]
    member.save!
  end

  def create_member(row)
    state = program_level? ? Member::Status::ACTIVE : Member::Status::DORMANT
    member = organization.members.build(
      email: row[UserCsvImport::CsvMapColumns::EMAIL.to_sym],
      first_name: row[UserCsvImport::CsvMapColumns::FIRST_NAME.to_sym],
      last_name: row[UserCsvImport::CsvMapColumns::LAST_NAME.to_sym],
      state: state,
      imported_at: Time.now
    )
    member.build_login_identifiers_for_custom_auths(row[UserCsvImport::CsvMapColumns::UUID.to_sym]) if @options[:is_super_console]
    member.save!
    member
  end

  def create_or_update_profile(member, row)
    questions.each do |question|
      next if question && question.handled_after_check_for_conditional_question_applicability?(member)
      key = UserCsvImport::CsvMapColumns::PROFILE_QUESTION_COLUMN_KEY.call(question.id).to_sym
      if row[key].present?
        profile_answer = (answers_map[member.id] && answers_map[member.id][question.id]) || member.profile_answers.build(profile_question: question)
        profile_answer.save_answer!(question, row[key], nil, from_import: true)
      else
        profile_answer = answers_map[member.id] && answers_map[member.id][question.id]
        profile_answer.destroy if profile_answer.present?
      end
      question.update_dependent_questions(member)
    end
  end

  def create_or_update_user(member, row)
    user = users_map[member.id]
    if user.present?
      user.promote_to_role!(get_role(row.data), options[:current_user])
    else
      create_user(member, row, true)
    end
  end

  def create_user(member, row, existing_member=false)
    user = member.users.new
    user.program = program
    user.state = row.state
    user.created_by = options[:current_user]
    user.role_names = get_role(row.data)
    user.imported_from_other_program = existing_member
    user.save!
  end

  def invite_user(row_data)
    begin
      invite = program.program_invitations.build(sent_to: email(row_data), user: options[:current_user], role_type: ProgramInvitation::RoleType::ASSIGN_ROLE)
      invite.role_names = get_role(row_data)
      invite.save!
      return true
    rescue => e
      return false
    end
  end

  def initialize_member_information(rows)
    emails = downcase(rows.collect(&:email))
    includes_list = rows.first.try(:has_custom_login_identifier?) ? :login_identifiers : {}
    members = organization.members.where(email: emails).includes(includes_list)
    @members_map = members.index_by { |member| member.email.downcase }
    member_ids = members.pluck(:id)

    @answers_map = {}
    member_answers = ProfileAnswer.where(ref_obj_type: "Member", ref_obj_id: member_ids)
    member_answers.find_each do |answer|
      @answers_map[answer.ref_obj_id] ||= {}
      @answers_map[answer.ref_obj_id][answer.profile_question_id] = answer
    end

    @users_map = program_level? ? program.users.where(member_id: member_ids).index_by{|user| user.member_id} : {}
  end

  def progress_batch_size
    [progress.maximum/10, CsvImporter::Constants::PROGRESS_BATCH_SIZE].min
  end

  def maintain_progress_count(rows, &block)
    previous_count = progress.reload.total_completed_count
    block.call(rows)
    current_count = progress.reload.total_completed_count
    count_difference = rows.size + previous_count - current_count
    increment_progress_count(count_difference)
  end

  def increment_progress_count(count)
    progress.reload.update_attribute(:completed_count, progress.count + count)
  end
end