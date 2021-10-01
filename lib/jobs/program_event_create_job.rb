class ProgramEventCreateJob < Struct.new(:program_event_id)
  def perform
    program_event = ProgramEvent.find_by(id: program_event_id)
    if program_event.try(:published_upcoming?)
      program_event.handle_new_published_event
    end
  end
end