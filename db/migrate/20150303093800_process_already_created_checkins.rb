class ProcessAlreadyCreatedCheckins< ActiveRecord::Migration[4.2]
  def change
    GroupCheckin.all.each do |checkin|
    	if checkin.checkin_ref_obj_type == MentoringModel::Task.name
    		checkin.title = checkin.checkin_ref_obj.title
    	elsif checkin.checkin_ref_obj_type == MemberMeeting.name
    		checkin.title = checkin.checkin_ref_obj.meeting.topic
    		checkin.comment = ""
    	end
    	checkin.save!
    end
  end
end
