class MobileApi::V1::LanguagesController < MobileApi::V1::BasicController
  skip_before_action :require_program
  before_action { |controller| controller.authenticate_user(false) }

  def index
    english_language = Language.for_english()

    @languages_supported = Language.supported_for(super_console?, wob_member, @current_organization)
    @languages_supported.each do |lang|
      lang.language_name = "fr-CA" if lang.language_name == "fr-FR"
    end
    @languages_supported.unshift(english_language)

    render_success "languages/index"
  end

  def set_member_language
    language_name = (params["language_name"] == "fr-CA") ? "fr-FR" : params["language_name"]
    Language.set_for_member(@current_member, language_name)
    render_response(status: 200, data: {})
  end
end