class BulkMatchesController < ApplicationController
  include BulkMatchUtils
  include MentoringModelCommonHelper
  include AdminViewsPreviewUtils

  skip_before_action :back_mark_pages, except: [:bulk_match]

  before_action :set_bulk_dj_priority
  before_action :fetch_orientation_type, only: [:bulk_match, :fetch_settings, :update_settings, :refresh_results, :fetch_notes, :groups_alert, :bulk_update_bulk_match_pair, :update_bulk_match_pair, :export_csv, :export_all_pairs, :alter_pickable_slots, :update_notes, :fetch_summary_details]
  before_action :fetch_bulk_match, only: [:bulk_update_bulk_match_pair, :update_bulk_match_pair, :fetch_settings, :update_settings, :fetch_notes, :update_notes, :export_csv, :alter_pickable_slots, :refresh_results, :export_all_pairs]
  before_action :fetch_student_mentor, only: [:update_bulk_match_pair, :fetch_summary_details, :alter_pickable_slots]
  before_action :fetch_group, only: [:update_bulk_match_pair, :update_notes]
  before_action :fetch_mentoring_model, only: [:bulk_update_bulk_match_pair, :update_bulk_match_pair]

  allow user: :can_manage_connections?
  allow exec: :check_program_has_ongoing_mentoring_enabled
  allow exec: :bulk_match_enabled?, only: [:bulk_match]

  def bulk_match
    if request.xhr?
      @bulk_match = BulkMatch.find_or_initialize_by(program_id: @current_program.id, orientation_type: @orientation_type)
      @bulk_match.update_bulk_entry(params["mentor_view_id"], params["mentee_view_id"])
      compute_bulk_match_results(@current_program, @bulk_match)
    else
      @set_source_info = params.permit(:controller, :action, :id)
      @bulk_match = BulkMatch.find_or_initialize_by(program_id: @current_program.id, default:  1)
      @orientation_type = @bulk_match.orientation_type
      set_admin_view_details
    end
  end

  def bulk_update_bulk_match_pair
    handle_bulk_request
    render json: { error_flash: @error_flash, object_id_group_id_map: @object_id_group_id_map }.to_json.html_safe
  end

  def update_bulk_match_pair
    @group_name = params[:group_name]
    handle_normal_request
    @bulk_match.update_attributes!(request_notes: (params["request_notes"] == "true")) if params["request_notes"].present?
    @error_flash ||= "activerecord.custom_errors.group.match_error".translate(errors: @errors[0]) if @errors.present?
    render json: { error_flash: @error_flash, object_id_group_id_map: @object_id_group_id_map }.to_json
  end

  def fetch_summary_details
    create_or_delete_supplementary_matching_pairs
    @match_configs, supplementary_matching_pairs = get_match_configs_and_supplementary_matching_pairs
    match_score = @student.student_cache_normalized(true)[@mentor.id]
    match_score_and_status = get_match_score_and_status_hash(@match_configs, @student, @mentor)
    render partial: "bulk_matches/match_config_summary" , locals: {match_score: match_score, match_score_and_status: match_score_and_status, supplementary_matching_pairs: supplementary_matching_pairs, mentee_to_mentor_match: mentee_to_mentor_match?}
  end

  def fetch_settings
    render partial: "popup_bulk_match_settings", locals: {orientation_type: @orientation_type}, layout: false
  end

  def update_settings
    if params[:sort].present?
      @bulk_match.update_attributes!(:sort_value => params[:sort_value], :sort_order => params[:sort_order])
    else
      @refresh_results = (@bulk_match.max_pickable_slots.to_i > params[:bulk_match][:max_pickable_slots].to_i) || (@bulk_match.request_notes != params[:bulk_match][:request_notes].to_s.to_boolean)
      @bulk_match.update_attributes!(update_settings_bulk_match_params)
      compute_bulk_match_results(@current_program, @bulk_match) if @refresh_results
    end
  end

  def preview_view_details
    set_preview_view_details
  end

  def fetch_notes
    @action_type = params["action_type"]
    @mentoring_models = get_all_mentoring_models(current_program)
    if params[:bulk_action]
      allow! exec: Proc.new { @action_type == BulkMatch::UpdateType::PUBLISH }
      @drafted_group_ids = params[:group_ids].map(&:to_i)
      render partial: "bulk_pairs_message_popup", layout: false
    else
      fetch_student_mentor
      fetch_group
      render partial: "bulk_match_notes_popup", layout: false
    end
  end

  def update_notes
    @group.update_attributes!(update_notes_group_params)
  end

  def export_csv
    set_mentor_and_student_ids
    student_mentor_hash = get_normalized_student_mentor_score_details(@current_program, @student_user_ids, @mentor_user_ids)
    compute_bulk_match_data(@current_program, @bulk_match, true) unless mentee_to_mentor_match?
    _students_hash, _mentors_hash, _students, _mentors, groups = set_user_hashes_and_groups_for_export
    set_filename_and_generate_drafted_pairs_csv(student_mentor_hash, groups)
  end

  def export_all_pairs
    students_hash, mentors_hash, students, mentors, groups = set_user_hashes_and_groups_for_export
    student_mentor_map = get_student_suggested_mentors_map
    generate_all_pairs_csv(students_hash, mentors_hash, student_mentor_map, {students: students, mentors: mentors, groups: groups})
  end

  def alter_pickable_slots
    render partial: "alter_pickable_slots_popup", layout: false
  end

  def refresh_results
    compute_bulk_match_results(@current_program, @bulk_match)
    render template: 'bulk_matches/bulk_match', formats: [:js]
  end

  def groups_alert
    allow! exec: Proc.new { params[:update_type] == BulkMatch::UpdateType::DRAFT }

    @student_id_mentor_id_sets = if params[:bulk_action]
      get_student_mentor_map(true).to_a
    else
      fetch_student_mentor
      [[[@student.id], [@mentor.id]]]
    end
    render json: { groups_alert: render_to_string(partial: "bulk_matches/groups_alert").strip }.to_json.html_safe
  end

  def change_match_orientation
    allow! exec: lambda{ @current_program.mentor_to_mentee_matching_enabled? }
    @orientation_type = params[:type].to_i
    @bulk_match = BulkMatch.find_or_initialize_by(program_id: @current_program.id, orientation_type: @orientation_type)
    @current_program.update_bulk_match_default(BulkMatch.name, @orientation_type)
    @step_2_tab_title = "feature.#{@bulk_match.type.underscore}.tab.assign_matches".translate(Mentors: _Mentors)
    fetch_mentee_and_mentor_views(@bulk_match.mentee_view, @bulk_match.mentor_view)
  end

  private

  def set_admin_view_details
    fetch_admin_views_for_matching
    fetch_mentee_and_mentor_views(@bulk_match.mentee_view, @bulk_match.mentor_view, params[:admin_view_id])
  end

  def update_settings_bulk_match_params
    params[:bulk_match].present? ? params[:bulk_match].permit(BulkMatch::MASS_UPDATE_ATTRIBUTES[:update_settings]) : {}
  end

  def update_notes_group_params
    params.present? ? params.permit(BulkMatch::MASS_UPDATE_ATTRIBUTES[:update_notes]) : {}
  end

  def fetch_bulk_match
    @bulk_match = mentee_to_mentor_match? ? @current_program.student_bulk_match : @current_program.mentor_bulk_match
  end

  def fetch_orientation_type
    @orientation_type = params[:orientation_type].to_i
  end

  def bulk_match_enabled?
    @current_program.bulk_match_enabled?
  end

  def set_mentor_and_student_ids
    active_pending_ids = @current_program.all_users.select('id, state').active_or_pending.pluck(:id)
    @student_user_ids = active_pending_ids & get_user_ids(@bulk_match.mentee_view, false)
    @mentor_user_ids = active_pending_ids & get_user_ids(@bulk_match.mentor_view, true)
  end

  def set_user_hashes_and_groups_for_export
    students_hash, mentors_hash = get_student_mentor_hash
    students, mentors, groups = get_students_mentors_and_groups(students_hash, mentors_hash)
    return [students_hash, mentors_hash, students, mentors, groups]
  end

  def get_match_configs_and_supplementary_matching_pairs
    match_configs = @current_program.match_configs.order("weight DESC").includes(mentor_question: [:profile_question], student_question: [:profile_question])
    supplementary_matching_pairs = @current_program.supplementary_matching_pairs.includes(mentor_role_question: [:profile_question], student_role_question: [:profile_question])
    [match_configs, supplementary_matching_pairs]
  end

  def get_match_score_and_status_hash(question_pairs, student, mentor)
    match_score_and_status = {}
    indexed_data = get_indexed_data([RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], current_program, user_ids: [student.id, mentor.id])
    question_pairs.each do |question_pair|
      match_score_and_status[question_pair.id] = get_match_status_for_match_config(student.id, mentor.id, indexed_data, match_config: question_pair)
    end
    match_score_and_status
  end

  def set_filename_and_generate_drafted_pairs_csv(student_mentor_hash, groups)
    csv_file_name = get_csv_file_name_for_bulk_match("feature.bulk_match.label.mentee_to_mentor_drafted_export_report_name".translate(get_translation_params) , "feature.bulk_match.label.mentor_to_mentee_drafted_export_report_name".translate(get_translation_params))

    generate_drafted_pairs_csv(student_mentor_hash, groups, csv_file_name)
  end

  def generate_drafted_pairs_csv(student_mentor_hash, groups, csv_file_name)
    drafted_groups = @current_program.groups.where(id: groups.keys).includes(:students =>  [:roles, :member => [:profile_answers]], :mentors =>  [:roles, :member => [:profile_answers]]).select(&:drafted?)
    send_csv @bulk_match.generate_csv_for_drafted_pairs(drafted_groups, student_mentor_hash, @student_user_ids, @mentor_user_ids, {pickable_slots: @pickable_slots}),
      :disposition => "attachment; filename=#{csv_file_name}.csv"
  end

  def generate_all_pairs_csv(students_hash, mentors_hash, student_mentor_map, options={})
    csv_file_name = is_bulk_recommendation ? "feature.bulk_match.label.all_recommendations_export_report_name".translate(date: DateTime.localize(Time.now, format: :csv_timestamp)) : get_csv_file_name_for_bulk_match("feature.bulk_match.label.mentee_to_mentor_all_pairs_export_report_name".translate(get_translation_params), "feature.bulk_match.label.mentor_to_mentee_all_pairs_export_report_name".translate(get_translation_params))

    send_csv BulkMatch.generate_csv_for_all_pairs(students_hash, mentors_hash, student_mentor_map, options.merge({bulk_recommendation_flag: is_bulk_recommendation, program: @current_program, orientation_type: @orientation_type})), :disposition => "attachment; filename=#{csv_file_name}.csv"
  end

  def get_translation_params
    {mentoring_connections: _mentoring_connections, date: DateTime.localize(Time.now, format: :csv_timestamp), Mentor: _Mentor, Mentee: _Mentee}
  end

  def get_csv_file_name_for_bulk_match(mentee_to_mentor_match_text, mentor_to_mentee_match_text)
    mentee_to_mentor_match? ? mentee_to_mentor_match_text : mentor_to_mentee_match_text
  end

  def create_or_delete_supplementary_matching_pairs
    if params[:add_supplementary_question].to_s.to_boolean
      create_supplementary_matching_pair
    elsif params[:delete_supplementary_question].to_s.to_boolean
      delete_supplementary_matching_pair
    end    
  end

  def create_supplementary_matching_pair
    current_program.supplementary_matching_pairs.create(student_role_question_id: params[:student_question_id].to_i, mentor_role_question_id: params[:mentor_question_id].to_i)
  end

  def delete_supplementary_matching_pair
    supplementary_matching_pair = current_program.supplementary_matching_pairs.find(params[:question_pair_id].to_i)
    supplementary_matching_pair.destroy
  end

  def get_student_mentor_hash
    [HashWithIndifferentAccess[JSON.parse(CGI::unescapeHTML(params[:students])).map { |s| [s["id"], s] }], HashWithIndifferentAccess[JSON.parse(CGI::unescapeHTML(params[:mentors])).map { |m| [m["id"], m] }]]  
  end

  def get_student_suggested_mentors_map
    bulk_match_or_recommendation = is_bulk_recommendation ? @current_program.bulk_recommendation : fetch_bulk_match
    compute_bulk_match_results(@current_program, bulk_match_or_recommendation)
    suggested_mentors_or_mentees = mentee_to_mentor_match? ? @suggested_mentors : @suggested_mentees
    HashWithIndifferentAccess[suggested_mentors_or_mentees.map{|user| [user[0], HashWithIndifferentAccess[user[1].map{|us| [us[0], us[1]]}]]}]
  end

  def is_bulk_recommendation
    params[:recommendation].to_s.to_boolean
  end

  def get_students_mentors_and_groups(students_hash, mentors_hash)
    students = current_program.users.where(id: students_hash.keys).index_by(&:id)
    mentors = current_program.users.where(id: mentors_hash.keys).index_by(&:id)
    users_hash = mentee_to_mentor_match? ? students_hash : mentors_hash
    group_ids = users_hash.collect{ |sh| sh[1][:group_id] }.reject(&:nil?)
    groups = current_program.groups.where(id: group_ids).index_by(&:id)
    [students, mentors, groups]
  end

  def fetch_student_mentor
    mentor_id = params["mentor_id"].presence || params["mentor_id_list"].split(",").first
    student_id = params["student_id"].presence || params["student_id_list"].split(",").first
    @mentor = @current_program.mentor_users.find(mentor_id)
    @student = @current_program.student_users.find(student_id)
  end

  def fetch_group
    if params["group_id"].present?
      @group = @current_program.groups.active_or_drafted.find(params["group_id"])
    end
  end

  def handle_normal_request
    @object_id_group_id_map = {}
    notes = params["notes"]

    @group ||= Group.get_non_bulk_match_drafted_groups(@student.id => @mentor.id).try(:[], @student.id)
    existing_connections = Group.involving(@student, @mentor)
    existing_connections -= [@group] if @group.present?

    if !@current_program.allow_multiple_groups_between_student_mentor_pair? && existing_connections.any?
      @error_flash = "flash_message.bulk_match_flash.connection_already_exists_v1".translate(Mentoring_Connection: _Mentoring_Connection)
    else
      case params[:update_type]
      when BulkMatch::UpdateType::DISCARD
        @group.destroy if @group.drafted?
      when BulkMatch::UpdateType::DRAFT
        @group = handle_draft_request(@student, @mentor, @group, notes)
      when BulkMatch::UpdateType::PUBLISH
        if @group.blank?
          @group = create_bulk_match_group(@student, @mentor, false, notes, @mentoring_model, @group_name)
        elsif @group.drafted?
          @group.bulk_match = @bulk_match
          @group.mentoring_model = @mentoring_model if @mentoring_model
          @group.name = @group_name if @group_name.present?
          @group.publish(current_user, params["message"])
        end
      end

      if [BulkMatch::UpdateType::DRAFT, BulkMatch::UpdateType::PUBLISH].include?(params[:update_type]) && @group.present?
        set_object_id_group_id_map_for_normal_request
      end
    end
  end

  def set_object_id_group_id_map_for_normal_request
    if mentee_to_mentor_match?
      @object_id_group_id_map[@student.id] = @group.id
    else
      @object_id_group_id_map[@mentor.id] = @group.id
    end
  end

  def handle_bulk_request
    unless params[:update_type] == BulkMatch::UpdateType::DRAFT
      drafted_groups = @current_program.groups.drafted.where(id: params["group_ids"].map(&:to_i))
    end

    @object_id_group_id_map = {}
    case params[:update_type]
    when BulkMatch::UpdateType::DRAFT
      handle_bulk_draft_requests
    when BulkMatch::UpdateType::PUBLISH
      handle_bulk_publish_requests(drafted_groups)
    when BulkMatch::UpdateType::DISCARD
      drafted_groups.map(&:destroy)
    end
  end

  def handle_bulk_draft_requests
    student_mentor_map = get_student_mentor_map
    student_map, mentor_map = get_student_and_mentor_map(student_mentor_map)
    user_id_drafted_group_id_map = Group.get_non_bulk_match_drafted_groups(student_mentor_map, mentee_to_mentor_match?)
    begin
      ActiveRecord::Base.transaction do
        set_object_id_group_id_map(student_mentor_map, student_map, mentor_map, user_id_drafted_group_id_map)
        raise if @errors.present?
      end
    rescue => ex
      if @errors.present?
        @error_flash = "flash_message.membership.creation_failed".translate
        @error_flash << "<br/>"
        @error_flash << @errors.join("<br/>")
      end
    end
  end

  def set_object_id_group_id_map(student_mentor_map, student_map, mentor_map, user_id_drafted_group_id_map)
    student_mentor_map.each_pair do |key_id, value_id|
      if mentee_to_mentor_match?
        mentor = mentor_map[value_id]
        student = student_map[key_id]
        group = handle_draft_request(student, mentor, user_id_drafted_group_id_map[key_id])
        @object_id_group_id_map[student.id] = group.id
      else
        mentor = mentor_map[key_id]
        student = student_map[value_id]
        group = handle_draft_request(student, mentor, user_id_drafted_group_id_map[key_id])
        @object_id_group_id_map[mentor.id] = group.id
      end
    end
  end

  def handle_bulk_publish_requests(drafted_groups)
    drafted_groups.each do |group|
      group.bulk_match = @bulk_match
      group.mentoring_model =  @mentoring_model if @mentoring_model
      group.publish(current_user, params[:message])
      student_mentor_id = mentee_to_mentor_match? ? group.initial_student_mentor_pair[0] : group.initial_student_mentor_pair[1]
      @object_id_group_id_map[student_mentor_id] = group.id
    end
  end

  def create_bulk_match_group(student, mentor, is_draft, notes, mentoring_model = nil, group_name =nil)
    group = @current_program.groups.new
    group.mentors = [mentor]
    group.students = [student]
    group.status = is_draft ? Group::Status::DRAFTED : Group::Status::ACTIVE
    group.actor = current_user
    group.created_by = current_user
    group.bulk_match = @bulk_match
    group.notes = notes if is_draft
    group.message = params["message"]
    group.mentoring_model = mentoring_model if mentoring_model
    group.name = group_name if group_name.present?
    unless group.save
      @errors ||= []
      @errors << group.errors.full_messages.to_sentence
    end
    group
  end

  # key_and_value_as_array: false => { student_id => mentor_id }
  # key_and_value_as_array: true => { [student_id] => [mentor_id] }
  def get_student_mentor_map(key_and_value_as_array = false)
    student_mentor_map = {}

    params[:student_mentor_map].each do |key_id, value_ids|
      key = key_id.to_i
      value = value_ids[0].to_i
      if key_and_value_as_array
        key = [key]
        value = [value]
      end
      student_mentor_map[key] = value
    end
    student_mentor_map
  end

  def get_student_and_mentor_map(student_mentor_map)
    student_ids = mentee_to_mentor_match? ? student_mentor_map.keys : student_mentor_map.values
    mentor_ids = mentee_to_mentor_match? ? student_mentor_map.values : student_mentor_map.keys
    student_map = @current_program.student_users.where(id: student_ids).index_by(&:id)
    mentor_map = @current_program.mentor_users.where(id: mentor_ids).index_by(&:id)
    return [student_map, mentor_map]
  end

  def handle_draft_request(student, mentor, group = nil, notes = nil)
    if group.present?
      # when drafting an already drafted pair, it's tied to bulk_match and notes are updated
      # only when present
      group.notes = notes if notes.present?
      group.bulk_match = @bulk_match
      group.save!
    else
      group = create_bulk_match_group(student, mentor, true, notes)
    end
    group
  end

  def fetch_mentoring_model
    @mentoring_model = current_program.mentoring_models.find_by(id: params[:mentoring_model_id])
  end

  def mentee_to_mentor_match?
    @orientation_type == BulkMatch::OrientationType::MENTEE_TO_MENTOR
  end
end