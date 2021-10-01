class PrivateMeetingNotesController < ApplicationController
  
  before_action :fetch_meeting
  allow :exec => :check_member_for_meeting_notes
  
  PRIVATE_NOTES_PER_PAGE = 10

  def index
    @private_meeting_notes = @meeting.private_meeting_notes.latest_first.paginate(:page => params[:notes_page], :per_page => PRIVATE_NOTES_PER_PAGE) 
    @back_link = {:link => session[:back_url]} 
  end

  def new
    @new_private_meeting_note = @meeting.private_meeting_notes.new()
  end

  def create
    @notify_attendees = params[:private_meeting_note].delete(:notify_attendees).to_s.to_boolean
    @private_meeting_note = PrivateMeetingNote.new_for(
      @meeting, wob_member, meeting_private_meeting_note_params(:create))
    @private_meeting_notes = @meeting.private_meeting_notes.latest_first.paginate(:page => params[:journal_page], :per_page => PRIVATE_NOTES_PER_PAGE)
    if @private_meeting_note.save
      create_scrap_for_note if @notify_attendees
      track_activity_for_ei(EngagementIndex::Activity::RECORD_NOTES)
    else
      @error_message = @private_meeting_note.errors.full_messages.to_sentence.presence 
    end
  rescue VirusError
    @error_message = "flash_message.message_flash.virus_present".translate
  end

  def edit
    private_meeting_note = @meeting.private_meeting_notes.find(params[:id])
    render(:partial => 'private_meeting_notes/edit_meeting_note', :locals => {meeting: @meeting, private_meeting_note: private_meeting_note})
  end

  def update
    @private_meeting_note = @meeting.private_meeting_notes.find(params[:id])

    # Attachment removal.
    if params[:remove_attachment]
      # Remove new attachment data from params. We will use this once removal
      # succeeds. 
      new_attachment = params[:private_meeting_note].delete(:attachment) 
      @private_meeting_note.text = params[:private_meeting_note][:text]
      @private_meeting_note.attachment = nil

      if @private_meeting_note.save
        # Success. Now, set the new attachment.
        @private_meeting_note.attachment = new_attachment
      end
    else
      # Update without attachment removal.
      @private_meeting_note.update_attributes(meeting_private_meeting_note_params(:update))
    end
    @error_message = @private_meeting_note.errors.full_messages.to_sentence.presence unless @private_meeting_note.save
  rescue VirusError
    @error_message = "flash_message.message_flash.virus_present".translate
  end

  def destroy
    @meeting.private_meeting_notes.find(params[:id]).destroy
    flash[:notice] = "flash_message.private_note_flash.deleted".translate
    redirect_to meeting_private_meeting_notes_path(@meeting)
  end

  private

  def meeting_private_meeting_note_params(action)
    params[:private_meeting_note].permit(PrivateMeetingNote::MASS_UPDATE_ATTRIBUTES[action])
  end

  def fetch_meeting
    @meeting = current_program.meetings.find(params[:meeting_id])
  end

  def check_member_for_meeting_notes
    is_member = @meeting.has_member?(wob_member)
    is_admin = current_user.can_manage_connections?
    @is_admin_view = !is_member && is_admin
    is_member || is_admin
  end

  def create_scrap_for_note
    begin
      note_params = params[:private_meeting_note]
      ref_obj = fetch_group_or_meeting
      subject = "feature.connection.content.message_note_subject".translate(name: wob_member.name(:name_only => true), topic: @meeting.topic)
      scrap = ref_obj.scraps.new(sender: wob_member, program_id: ref_obj.program_id, content: note_params[:text], subject: subject, attachment: note_params[:attachment])
      scrap.create_receivers!
      scrap.save!
    rescue => e
      notify_airbrake(e)
    end
  end
  
  def fetch_group_or_meeting
    @meeting.group_meeting? ? @meeting.group : @meeting
  end
end
