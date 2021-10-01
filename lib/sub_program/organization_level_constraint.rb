module SubProgram
  class OrganizationLevelConstraint
    def matches?(request)
      request.env['PATH_INFO'] =~ %r(^/#{SubProgram::PROGRAM_PREFIX}([^/]+))
      program_root = $1
      return program_root.nil?
    end
  end
end