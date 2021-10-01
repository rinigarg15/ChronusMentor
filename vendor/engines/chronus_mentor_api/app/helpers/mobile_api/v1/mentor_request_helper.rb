module MobileApi::V1::MentorRequestHelper
  def fetch_mentor_request_hash(json, mentor_request, filter, size = :medium)
    mentor_request_user = filter == AbstractRequest::Filter::TO_ME ? mentor_request.student : mentor_request.mentor
    json.image_url generate_member_url(mentor_request_user.member, size: size)
    json.first_name mentor_request_user.first_name
    json.last_name mentor_request_user.last_name
    json.user_id mentor_request_user.id
    json.member_id mentor_request_user.member_id
    json.can_withdraw current_program.allow_mentee_withdraw_mentor_request
  end
end