user = @users[program.id].try(:first)
roles = @roles[program.id]
mem_reqs = @mem_reqs[program.id]

json.extract! program, :root, :name, :description, :show_multiple_role_option
json.roles do
  Role::PROGRAM_JOIN_OPTIONS.each do |join_option|
    json.set! join_option, roles.select{|r| r.send("#{join_option}?")}.collect(&:name)
  end
end if roles
json.user_roles do
  json.active user.roles.collect(&:name).uniq if user
  json.pending mem_reqs.collect{|req| req.roles.collect(&:name)}.flatten.uniq if mem_reqs
end
