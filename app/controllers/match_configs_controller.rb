class MatchConfigsController < ApplicationController
  skip_all_action_callbacks :only => [:compute_fscore, :question_template] 
  before_action :find_match_config, only: [:edit, :update, :destroy]  
  before_action :require_super_user
  before_action :fetch_choice_based_question_ids, only: [:edit, :new]
  before_action :fetch_show_match_labels_question_ids, only: [:edit, :new]

  def index
    @match_configs = current_program.match_configs.all
  end

  def new
    @match_config = current_program.match_configs.build
  end

  def edit
  end

  def create
    display_mapping, match_mapping = get_matching_details_from_params
    @match_config = current_program.match_configs.build(match_config_params(:create))
    @match_config.matching_details_for_display = display_mapping
    @match_config.matching_details_for_matching = match_mapping
    if @match_config.save
      redirect_to match_configs_path, :notice => 'flash_message.match_config.created'.translate
    else
      render :action => "new"
    end
  end

  def update
    @match_config.matching_details_for_display, @match_config.matching_details_for_matching = get_matching_details_from_params
    if @match_config.update_attributes(match_config_params(:update))
      redirect_to match_configs_path, :notice => 'flash_message.match_config.updated'.translate
    else
      render :action => "edit"
    end
  end

  def destroy
    @match_config.destroy
    redirect_to match_configs_url
  end

  def play
    @match_configs = @current_program.match_configs.includes(mentor_question: [profile_question: {question_choices: :translations}], student_question: [profile_question: {question_choices: :translations}]).order("weight DESC").all
  end

  def compute_fscore
    array = [ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS]
    if params[:sq_value].present? && params[:mq_value].present?
      sq_type = params[:sq_type].to_i
      mq_type = params[:mq_type].to_i
      sq_value = array.include?(sq_type) ? get_formatted_choices(JSON.parse(params[:sq_value])) : params[:sq_value].remove_braces_and_downcase
      mq_value = array.include?(mq_type) ? get_formatted_choices(JSON.parse(params[:mq_value])) : params[:mq_value].remove_braces_and_downcase

      student_question = RoleQuestion::MatchType.match_type_for(sq_type).new(sq_value)
      mentor_question = RoleQuestion::MatchType.match_type_for(mq_type).new(mq_value)
      match_config = MatchConfig.find(params[:config_id].to_i)
      options = (match_config.matching_type == MatchConfig::MatchingType::SET_MATCHING) ? {:matching_details => match_config.matching_details_for_matching } : {}
      score = mentor_question.match(student_question, options)
    else
      score = 0.0
    end
    
    render json: {score: score}
  end

  def question_template
    @type = params[:type].to_i
    render :layout => false
  end

  def refresh_scores
    Matching.perform_program_delta_index_and_refresh_later(@current_program)
    redirect_to match_configs_path, :notice => 'flash_message.match_config.refresh_started'.translate
  end

  def question_choices
    config_id = params[:config_id].to_i
    student_ques_id = params[:student_ques_id].to_i
    mentor_ques_id = params[:mentor_ques_id].to_i
    choices = {}
    choices[:student] = get_choices_of_question(student_ques_id)
    choices[:mentor] = get_choices_of_question(mentor_ques_id)
    if (config_id > 0)
      match_config =  @current_program.match_configs.where(id: config_id, student_question_id: student_ques_id, mentor_question_id: mentor_ques_id).first
      choices[:setMapping] = match_config.matching_details_for_display if match_config.present?
    end
    render :json => choices.to_json
  end

  private

  def match_config_params(action)
    params[:match_config].present? ? params[:match_config].permit(MatchConfig::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def get_choices_of_question(question_id)
    @current_program.role_questions.find(question_id).profile_question.default_choices
  end

  def find_match_config
    @match_config = current_program.match_configs.find(params[:id])
  end

  def fetch_choice_based_question_ids
    @mentee_single_ordered_question_ids = @current_program.choice_based_questions_ids_for_role([RoleConstants::STUDENT_NAME])
    @mentor_single_ordered_question_ids = @current_program.choice_based_questions_ids_for_role([RoleConstants::MENTOR_NAME])
  end

  def fetch_show_match_labels_question_ids
    @mentee_single_show_match_label_question_ids = @current_program.show_match_label_questions_ids_for_role([RoleConstants::STUDENT_NAME])
    @mentor_single_show_match_label_question_ids = @current_program.show_match_label_questions_ids_for_role([RoleConstants::MENTOR_NAME])
  end

  def get_matching_details_from_params
    mentee_choices_array = params[:match_config].delete(:mentee_choice)
    mentor_choices_array = params[:match_config].delete(:mentor_choices)
    if params[:match_config][:matching_type].to_i == MatchConfig::MatchingType::SET_MATCHING && mentee_choices_array.present?
      display_hash  = get_display_hash(mentee_choices_array, mentor_choices_array)
      matching_hash = get_matching_hash(mentee_choices_array, mentor_choices_array)
      return [display_hash, matching_hash]
    else
      return [nil, nil]
    end
  end

  # Removes all braces if any before matching the text
  # Added the same formula in MentorDistribution.rb for calculation. any change here should be made there too.
  def get_formatted_choices(array)
    array.map{|choice| choice.remove_braces_and_downcase }
  end

  def get_display_hash(mentee_choices_array, mentor_choices_array)
    display_hash = mentee_choices_array.each_with_index.inject({}) do |hsh, (mentee_choice, index)|
      hsh[mentee_choice] ||= []
      hsh[mentee_choice] << mentor_choices_array[index]
      hsh
    end
    display_hash.each{|k,v| display_hash[k] = v.join(MatchConfig::MUTLTISET_SEPARATOR)}
  end

  def get_matching_hash(mentee_choices_array, mentor_choices_array)
    mentee_choices_array.inject({}) do |matching_hash, mentee_choices|
      mentor_choices = get_formatted_choices(mentor_choices_array.shift.split(QuestionChoiceExtensions::SELECT2_SEPARATOR))
      get_formatted_choices(mentee_choices.split(QuestionChoiceExtensions::SELECT2_SEPARATOR)).each do |choice|
        matching_hash[choice] ||= []
        matching_hash[choice] << mentor_choices
      end
      matching_hash
    end
  end

end
