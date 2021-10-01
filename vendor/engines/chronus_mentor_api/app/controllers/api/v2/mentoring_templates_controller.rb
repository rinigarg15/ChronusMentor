class Api::V2::MentoringTemplatesController < Api::V2::BasicController
  before_action :build_presenter 

  def index
    result = @presenter.list(params)
    render_presenter_response(result, :mentoring_template)
  end

protected
  
  def build_presenter
    @presenter = Api::V2::MentoringTemplatePresenter.new(@current_program)
  end

end