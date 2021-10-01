class MobileApi::V1::MembersController < MobileApi::V1::BasicController
  skip_before_action :require_program
  before_action { |controller| controller.authenticate_user(false) }
  respond_to :json

  def auto_complete_for_name
    options = get_dormant_member_search_options
    options[:retry_stale] = true
    options[:conditions] = {:state => [Member::Status::ACTIVE, Member::Status::DORMANT].join(" | ")}
    @members = Member.search("@name #{TsUtils.ts_escape(params[:search].strip)}*", options)
    result = {list: @members.map{|m| {id: m.id, name: m.name, email: m.email}} }
    render_presenter_response({data: result, success: true})
  end
end
