class CustomizedTermsController < ApplicationController

  allow :exec => :check_super_user_access_for_program_update
  contextual_login_filters

  def update_all
    @program_scope = params[:program_scope].to_boolean
    terms = @program_scope ? @current_program.get_terms_for_view : @current_organization.get_terms_for_view
    params[:customized_term].keys.each do |custom_term_key|
      term = terms.find{|term| term.id == custom_term_key.to_i}
      term.update_term(params[:customized_term][custom_term_key]) if term.present?
    end
    @current_organization.send_later(:sync_customized_terms) unless @program_scope
    set_terminology_helpers #To reflect updated terminology
  end

  private

  def check_super_user_access_for_program_update
    super_console?
  end
end
