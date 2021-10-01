class CreateConnectionMembershipStateChanges< ActiveRecord::Migration[4.2]
  def up
    create_table :connection_membership_state_changes do |t|
      t.belongs_to :connection_membership
      t.belongs_to :group
      t.belongs_to :user
      t.text :info
      t.integer :date_id
      t.datetime :date_time
      t.integer :role_id

      t.timestamps null: false
    end
    add_index :connection_membership_state_changes, :connection_membership_id, :name => 'index_membership_state_change_on_membership_id'
    add_index :connection_membership_state_changes, :group_id
    add_index :connection_membership_state_changes, :user_id
    add_index :connection_membership_state_changes, :date_id

    membership_state_change_objects = []
    counter = 0
    Group.select([:id, :status, :created_at, :published_at, :closed_at, :pending_at, :program_id, :creator_id]).includes(:program, :created_by, :memberships, :state_changes).find_each do |group|
      group.memberships.each do |membership|
        membership_created_at = membership.created_at

        if group.program.career_based?
          if group.closed? # closed groups
            if group.published_at == group.created_at
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::ACTIVE, membership_created_at, nil)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::CLOSED, group.closed_at)
            else # closed groups, published later in time after being created (i.e. was initally drafted)
              if group.published_at >= membership_created_at # group got published after this membership got created
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::DRAFTED, Group::Status::DRAFTED, membership_created_at, nil)
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::DRAFTED, Group::Status::ACTIVE, group.published_at)
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::CLOSED, group.closed_at)
              else # Membership was created after the group was published
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::ACTIVE, membership_created_at, nil)
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::CLOSED, group.closed_at)
              end
            end
          else # not closed groups
            if group.published_at.nil? || group.published_at == group.created_at # Originally drafted and still drafted Or Originally active and still active
              membership_state_change_objects << create_membership_state_change(membership, group.status, group.status, membership_created_at, nil)
            else # published later in time after being created
              if group.published_at >= membership_created_at
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::DRAFTED, Group::Status::DRAFTED, membership_created_at, nil)
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::DRAFTED, Group::Status::ACTIVE, group.published_at)
              else
                membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::ACTIVE, membership_created_at, nil)
              end
            end
          end
        else # project based engagement scenario
          ary = [group.pending_at.present?, group.published_at.present?, group.closed_at.present?]
          drafted_or_proposed = (group.created_by.present? && group.created_by.is_admin?) ? Group::Status::DRAFTED : Group::Status::PROPOSED
          if ary == [false, false, false] # Originally drafted/proposed and still drafted/proposed 
            membership_state_change_objects << create_membership_state_change(membership, group.status, group.status, membership_created_at, nil)
          elsif ary == [false, false, true] # Originally proposed and now rejected (this case doesn't exist for drafted)
            membership_state_change_objects << create_membership_state_change(membership, Group::Status::PROPOSED, Group::Status::PROPOSED, membership_created_at, nil)
            membership_state_change_objects << create_membership_state_change(membership, Group::Status::PROPOSED, Group::Status::REJECTED, group.closed_at)
          elsif ary == [true, false, false] # Originally proposed/drafted and now pending
            if group.pending_at >= membership_created_at
              membership_state_change_objects << create_membership_state_change(membership, drafted_or_proposed, drafted_or_proposed, membership_created_at, nil)
              membership_state_change_objects << create_membership_state_change(membership, drafted_or_proposed, Group::Status::PENDING, group.pending_at)
            else # membership got created after group became pending
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::PENDING, Group::Status::PENDING, membership_created_at, nil)
            end
          elsif ary[0..1] == [true, true] && !group.closed? # Originally proposed/drafted, then pending and now active(or inactive)
            if membership_created_at > group.published_at # membership got created after group got published
              membership_state_change_objects << create_membership_state_change(membership, group.status, group.status, membership_created_at, nil)
            elsif membership_created_at > group.pending_at # membership got created after group became pending but before it got published
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::PENDING, Group::Status::PENDING, membership_created_at, nil)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::PENDING, group.status, group.published_at)
            else # membership got created before group became pending
              membership_state_change_objects << create_membership_state_change(membership, drafted_or_proposed, drafted_or_proposed, membership_created_at, nil)
              membership_state_change_objects << create_membership_state_change(membership, drafted_or_proposed, Group::Status::PENDING, group.pending_at)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::PENDING, group.status, group.published_at)
            end
          elsif ary[0..1] == [true, true] && group.closed? # Originally proposed/drafted, then pending, then active(or inactive we cannot tell) and now closed
            if membership_created_at > group.published_at # membership got created after group got published
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::ACTIVE, membership_created_at, nil)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::CLOSED, group.closed_at)
            elsif membership_created_at > group.pending_at # membership got created after group became pending but before it got published
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::PENDING, Group::Status::PENDING, membership_created_at, nil)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::PENDING, Group::Status::ACTIVE, group.published_at)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::CLOSED, group.closed_at)
            else # membership got created before group became pending
              membership_state_change_objects << create_membership_state_change(membership, drafted_or_proposed, drafted_or_proposed, membership_created_at, nil)
              membership_state_change_objects << create_membership_state_change(membership, drafted_or_proposed, Group::Status::PENDING, group.pending_at)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::PENDING, Group::Status::ACTIVE, group.published_at)
              membership_state_change_objects << create_membership_state_change(membership, Group::Status::ACTIVE, Group::Status::CLOSED, group.closed_at)
            end
          end
        end
        print '.' if counter % 100 == 0
        counter += 1
      end
    end
    puts "\nDumping #{membership_state_change_objects.size} objects into db"
    ConnectionMembershipStateChange.import membership_state_change_objects
  end

  def down
    drop_table :connection_membership_state_changes
  end


  private

  def get_date_id(timestamp)
    (timestamp.utc.to_i / 86400) # 1.day.to_i => 86400
  end

  def create_membership_state_change(membership, group_from_state, group_to_state, timestamp, connection_membership_from_state=Connection::Membership::Status::ACTIVE)
    membership.state_changes.new(info: {group: {from_state: group_from_state, to_state: group_to_state}, user: {from_state: membership.user.state, to_state: membership.user.state}, connection_membership: {from_state: connection_membership_from_state, to_state: Connection::Membership::Status::ACTIVE}}.to_yaml.gsub(/--- \n/, ""), date_id: get_date_id(timestamp), date_time: timestamp, group_id: membership.group.id, user_id: membership.user.id, role_id: membership.role_id)
  end

end
