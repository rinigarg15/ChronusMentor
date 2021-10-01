module MentoringModel::MilestoneTemplatesHelper
  def control_class(milestone_template)
    milestone_template.new_record? ? "form-control" : "form-control"
  end
end