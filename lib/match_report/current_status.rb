class MatchReport::CurrentStatus
  attr_accessor :graphData, :program, :startDate, :endDate

  def initialize(program)
    self.program = program
    self.startDate = self.program.created_at
    self.endDate = Time.now
    self.graphData = self.program.set_current_status_graph_data(self.startDate, self.endDate, self.program)
  end

end