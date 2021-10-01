When(/facilitation is enabled/) do
end

Before("@facilitation") do
  set_current_program_for_integration(Program.find_by(root: "albers"))
end