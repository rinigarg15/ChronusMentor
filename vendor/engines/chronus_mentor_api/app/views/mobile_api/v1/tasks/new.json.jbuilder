jbuilder_responder(json, local_assigns) do
  json.connection_memberships do
    json.array! @connection_memberships do |connection_membership|
      connection_user = connection_membership.user
      json.name connection_user.name(name_only: true)
      json.image_url generate_member_url(connection_user.member, size: :small)
      json.id connection_membership.id
    end
  end
  json.current_connection_membership do
    ## Though we have current_connection_membership object in the form of @connection_membership
    ## I'm iterating through the @connection_memberships, because in @connection_memberships, the user and member relations are eager loaded.
    current_connection_membership = @connection_memberships.find{|connection_membership| connection_membership.id == @connection_membership.id }
    json.id current_connection_membership.id
    json.name current_connection_membership.user.name(name_only: true)
    json.image_url generate_member_url(current_connection_membership.user.member, size: :small)
  end
  display_goals_milestones(json, @goals, @milestones)
end