class AddingTypeValuesToTimelineQuestions< ActiveRecord::Migration[4.2]
  def add_timeline_question_type_info!(filter_params)
    return unless filter_params[:timeline] && filter_params[:timeline][:timeline_questions]
    filter_params[:timeline][:timeline_questions].each do |question, details|
      if details[:type].nil?
        details[:type] = (details[:value].try(:downcase) == AdminView::TimelineQuestions::NEVER_SEEN_VALUE ?
          AdminView::TimelineQuestions::Type::NEVER :
          AdminView::TimelineQuestions::Type::DATE_RANGE)
      end
    end
  end

  def up
    ActiveRecord::Base.transaction do
      AdminView.find_each do |admin_view|
        filter_params = YAML.load(admin_view.filter_params)
        add_timeline_question_type_info!(filter_params)
        admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
        admin_view.save!
      end
    end
  end

  def down
    # No down migration
  end
end
