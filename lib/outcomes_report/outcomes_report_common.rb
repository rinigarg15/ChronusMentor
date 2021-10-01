class OutcomesReportCommon

  attr_accessor :startDate, :startDateForGraph, :endDate, :startDayIndex, :daysSpan, :getOldData, :oldEndTime, :oldStartTime, :totalCount, :overallChange,
  :roleGraphColorMapping, :enabledStatusMapping, :userSummary, :rolewiseSummary, :graphData, :responseRate, :marginError

  attr_reader :program

  include OutcomesReportUtils

  def common_initialization(program, date_range, enabled_status)
    @program = program
    @mentoring_roles = @program.roles.for_mentoring
    enabled_status = enabled_status || Array.new(@mentoring_roles.count, 0).insert(0, 1).insert(-1, 1).join("")
    # default enabled status is of the form "1001" where the leading 1 represents users graph, trailing 1 is for total connections/meetings graph, and the number of 0's depends on the number of mentoring roles

    self.roleGraphColorMapping = GraphColor.get_role_graph_color_mapping(@mentoring_roles)
    self.enabledStatusMapping = GraphEnabledStatus.get_enabled_status_mapping(@mentoring_roles, enabled_status, true)
    process_date_params(date_range)

    self.startDayIndex = (self.startDate.utc.beginning_of_day.to_i - program.created_at.utc.beginning_of_day.to_i)/1.day
    self.startDayIndex = 0 if (self.startDayIndex < 0)

    self.daysSpan = (self.endDate.utc.beginning_of_day.to_i - self.startDate.utc.beginning_of_day.to_i)/1.day + 1
    self.oldEndTime = self.startDate - 1.day
    self.oldStartTime = self.startDate - self.daysSpan.days
    self.getOldData = self.oldStartTime >= @program.created_at.utc.to_datetime
    self.startDateForGraph = self.startDate.to_i*1000
  end
end