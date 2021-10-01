module HealthReport
  class Base
    attr_accessor :program, :role_map, :growth, :connectivity, :engagement, :content_overview

    module SubReports
      GROWTH = "growth"
      CONNECTIVITY = "connectivity"
      ENGAGEMENT = "engagement"
      CONTENT_OVERVIEW = "content_overview"

      MAPPING = {
        "growth" => GROWTH,
        "connectivity" => CONNECTIVITY,
        "engagement" => ENGAGEMENT,
        "content_overview" => CONTENT_OVERVIEW
      }
    end

    def initialize(program)
      self.program          = program
      self.role_map         = {}
      self.program.roles_without_admin_role.each do |role|
        self.role_map[role.name] = role.id
      end
      self.growth           = Growth.new(self.program, self.role_map)
      self.connectivity     = Connectivity.new(self.program, self.role_map)
      self.engagement       = Engagement.new(self.program)
      self.content_overview = ContentOverview.new(self.program)
    end

    def compute
      self.growth.compute_summary_data
      self.growth.compute
      self.connectivity.compute
      self.engagement.compute
      self.content_overview.compute
    end
  end
end