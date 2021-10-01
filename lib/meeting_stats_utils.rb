module MeetingStatsUtils
  def columns_for_meeting_stats
    "meetings.id as meeting_id, meetings.start_time as meeting_start_time, member_meetings.id as member_meeting_id, member_meetings.member_id as member_id, meetings.mentee_id as meeting_owner_id"
  end

  def remove_invalid_meetings(meetings, for_positive_outcome=false, member_meeting_ids = [])
    meeting_hash = {}
    processed_meetings = []
    meetings.each do |meeting|
      if (meeting_hash[meeting["meeting_id"]].nil?)
        meeting_hash.merge!(meeting["meeting_id"] => 1)
      else
        meeting_hash.merge!(meeting["meeting_id"] => (meeting_hash[meeting["meeting_id"]])+1)
      end
    end
    meetings.each do |meeting|
      processed_meetings << meeting if can_add_meeting?(meeting_hash, meeting, for_positive_outcome, member_meeting_ids)
    end
    return processed_meetings
  end

  def can_add_meeting?(meeting_hash, meeting, for_positive_outcome, member_meeting_ids)
    if for_positive_outcome
      (meeting_hash[meeting["meeting_id"]] > 1) && member_meeting_ids.include?(meeting["member_meeting_id"])
    else
      (meeting_hash[meeting["meeting_id"]] > 1)
    end
  end

  def get_meetings_data_hash_for_stats(query)
    query = query.non_group_meetings.joins(:member_meetings).where("member_meetings.attending!=?", MemberMeeting::ATTENDING::NO)
    query = query.select(columns_for_meeting_stats)
    ActiveRecord::Base.connection.exec_query(query.to_sql).to_hash
  end

  def get_meetings_count(meetings_data_hash)
    meetings_data_hash.collect{|m| m["meeting_id"]}.uniq.count
  end
end