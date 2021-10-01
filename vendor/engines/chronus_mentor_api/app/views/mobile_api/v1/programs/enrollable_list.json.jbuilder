jbuilder_responder(json, local_assigns) do
  json.programs @programs, partial: 'enrollable_program', as: :program, locals: {users: @users, roles: @roles, mem_reqs: @mem_reqs}
end