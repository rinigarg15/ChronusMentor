class MobileApi::V1::MentoringTemplatesController < MobileApi::V1::BasicController
  before_action :authenticate_user
  allow :user => :is_admin?
  before_action :build_presenter 

  def index
    result = @presenter.list(params)
    render_presenter_response(result)
  end

protected
  
  def build_presenter
    @presenter = MobileApi::V1::MentoringTemplatePresenter.new(@current_program)
  end

end
