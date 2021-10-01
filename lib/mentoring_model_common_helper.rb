module MentoringModelCommonHelper
  def get_all_mentoring_models(program)
    program.mentoring_models.select(:id, :default).sort_by(&:title)
  end
end