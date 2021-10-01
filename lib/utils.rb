# Utilities for usage in ruby console
def org(prog_name = nil)
  Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,prog_name)
end

def prog(prog_name = nil)
  unless prog_name
    Program.first
  else
    Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,prog_name).programs.ordered.first
  end
end

def progadmin(prog_name = nil)
  p = prog(prog_name)
  p.admin_users.first
end

def progmentor(prog_name = nil)
  p = prog(prog_name)
  p.mentor_users.first
end

def progstud(prog_name = nil)
  p = prog(prog_name)
  p.students.first
end