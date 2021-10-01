jbuilder_responder(json, local_assigns) do
  json.instruction @instruction.content if @instruction.present?
  json.receiver do
    json.extract! @receiver, :id, :first_name, :last_name
    json.member_id @receiver.member_id
    json.image_url generate_member_url(@receiver.member, size: :small)
    json.student_count @receiver.students.count
  end
end