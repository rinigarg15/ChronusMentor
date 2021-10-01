# A Collection of Feedback::Response for a mentor
class Feedback::ResponseListForMentor < Array
  # Constructor
  #
  # Params:
  # * <tt>mentor</tt> : the mentor user whose feedback responses this list
  # holds
  # * <tt>item_list</tt> : optional collection to initialize this list with.
  def initialize(mentor, item_list = [])
    self.mentor = mentor
    self.replace(item_list)
  end

  # Gettor for the mentor to which the responses belongs to. 
  def mentor
    @mentor
  end

  # Settor for the mentor to which the responses belongs to.
  def mentor=(mentor_obj)
    # Don't accept if mentor_obj is not a mentor.
    raise 'Not a mentor' unless mentor_obj.is_mentor?
    @mentor = mentor_obj
  end
end
