class Connection::PrivateNotesController < ApplicationController
  include ConnectionFilters
  include MentoringModelUtils
  common_extensions

  allow :exec => :check_access
  PRIVATE_NOTES_PER_PAGE = 10

  def index
    @mentoring_context = :private_notes
    @private_notes = @group.private_notes.owned_by(current_user).latest_first.paginate(:page => params[:journal_page], :per_page => PRIVATE_NOTES_PER_PAGE)
    @new_private_note = @group.membership_of(current_user).private_notes.new()
 
    if params[:updated]
      # Redirected from update. Load the object from session so as to check
      # the validity and show appropriate message.
      @edit_private_note = deserialize_from_session(Connection::PrivateNote)
    else
      # New note.
      @new_private_note = deserialize_from_session(Connection::PrivateNote)
    end
  end

  def create
    @private_note = Connection::PrivateNote.new_for(
      @group, current_user, connection_private_note_params(:create))

    # Serialize the error so as to show it in the next page.
    if @private_note.save 
      track_activity_for_ei(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL)
     else
      flash[:error] = @private_note.errors.full_messages.to_sentence
      serialize_to_session(@private_note)
    end

    redirect_to group_connection_private_notes_path(@group)
  end

  def update
    @private_note = @group.private_notes.owned_by(current_user).find(params[:id])

    # Attachment removal.
    if params[:remove_attachment]
      # Remove new attachment data from params. We will use this once removal
      # succeeds. 
      new_attachment = params[:connection_private_note].delete(:attachment)
      @private_note.text = params[:connection_private_note][:text]

      # Delete the attachment.
      @private_note.attachment = nil
      if @private_note.save
        # Success. Now, set the new attachment.
        @private_note.attachment = new_attachment
      end

      # Now save the record to push any pending changes.
      @private_note.save
    else
      # Update without attachment removal.
      @private_note.update_attributes(connection_private_note_params(:update))
    end

    # Serialize the note object always so that +index+ can highlight the success
    # or error.
    track_activity_for_ei(EngagementIndex::Activity::CREATE_UPDATE_JOURNAL) unless @private_note.errors.any?
    serialize_to_session(@private_note)

    redirect_to group_connection_private_notes_path(
      @group,
      :anchor => @private_note.errors.any? ? 
        "edit_note_#{@private_note.id}" : "note_#{@private_note.id}",
      :updated => 1)
  end

  def destroy
    @group.private_notes.owned_by(current_user).find(params[:id]).destroy
    flash[:notice] = "flash_message.private_note_flash.deleted".translate
    redirect_to group_connection_private_notes_path(@group)
  end

  private

  def connection_private_note_params(action)
    params[:connection_private_note].present? ? params[:connection_private_note].permit(Connection::PrivateNote::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def check_access
    !working_on_behalf? && @current_program.allow_private_journals?
  end

end
