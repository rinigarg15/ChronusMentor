class CreateGroupStateChanges< ActiveRecord::Migration[4.2]
  def up
    create_table :group_state_changes do |t|
      t.belongs_to :group
      t.string :from_state
      t.string :to_state
      t.integer :date_id

      t.timestamps null: false
    end
    add_index :group_state_changes, :group_id
    add_index :group_state_changes, :date_id

    # populate default state
    group_state_change_objects = []
    counter = 0
    Group.select([:id, :status, :created_at, :published_at, :closed_at, :pending_at, :program_id, :creator_id]).includes(:program, :created_by).find_each do |group|
      if group.program.career_based?
        if group.closed? # closed groups
          if group.published_at == group.created_at
            group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::ACTIVE, date_id: get_date_id(group.created_at))
            group_state_change_objects << group.state_changes.new(from_state: Group::Status::ACTIVE, to_state: group.status, date_id: get_date_id(group.closed_at))
          else # closed groups, published later in time after being created
            group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::DRAFTED, date_id: get_date_id(group.created_at))
            group_state_change_objects << group.state_changes.new(from_state: Group::Status::DRAFTED, to_state: Group::Status::ACTIVE, date_id: get_date_id(group.published_at))
            group_state_change_objects << group.state_changes.new(from_state: Group::Status::ACTIVE, to_state: group.status, date_id: get_date_id(group.closed_at))
          end
        else # not closed groups
          if group.published_at.nil? || group.published_at == group.created_at
            group_state_change_objects << group.state_changes.new(from_state: nil, to_state: group.status, date_id: get_date_id(group.created_at))
          else # published later in time after being created
            group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::DRAFTED, date_id: get_date_id(group.created_at))
            group_state_change_objects << group.state_changes.new(from_state: Group::Status::DRAFTED, to_state: group.status, date_id: get_date_id(group.published_at))
          end
        end
      else # project based engagement scenario
        ary = [group.created_at.present?, group.pending_at.present?, group.published_at.present?, group.closed_at.present?, group.created_by.present? && group.created_by.is_admin?]
        if ary[0..3] == [true, false, false, false]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: group.status, date_id: get_date_id(group.created_at))
        elsif ary == [true, false, false, true, false]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::PROPOSED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PROPOSED, to_state: group.status, date_id: get_date_id(group.closed_at))
        elsif ary == [true, true, false, false, false]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::PROPOSED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PROPOSED, to_state: group.status, date_id: get_date_id(group.pending_at))
        elsif ary == [true, true, false, false, true]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::DRAFTED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::DRAFTED, to_state: group.status, date_id: get_date_id(group.pending_at))  
        elsif ary == [true, true, true, false, false]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::PROPOSED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PROPOSED, to_state: Group::Status::PENDING, date_id: get_date_id(group.pending_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PENDING, to_state: group.status, date_id: get_date_id(group.published_at))
        elsif ary == [true, true, true, false, true]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::DRAFTED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::DRAFTED, to_state: Group::Status::PENDING, date_id: get_date_id(group.pending_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PENDING, to_state: group.status, date_id: get_date_id(group.published_at))
        elsif ary == [true, true, true, true, false]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::PROPOSED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PROPOSED, to_state: Group::Status::PENDING, date_id: get_date_id(group.pending_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PENDING, to_state: Group::Status::ACTIVE, date_id: get_date_id(group.published_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::ACTIVE, to_state: Group::Status::CLOSED, date_id: get_date_id(group.closed_at)) if group.closed?
        elsif ary == [true, true, true, true, false]
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::DRAFTED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::DRAFTED, to_state: Group::Status::PENDING, date_id: get_date_id(group.pending_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PENDING, to_state: Group::Status::ACTIVE, date_id: get_date_id(group.published_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::ACTIVE, to_state: Group::Status::CLOSED, date_id: get_date_id(group.closed_at)) if group.closed?
        end
      end
      print '.' if counter % 100 == 0
      counter += 1
    end
    puts "\nDumping #{group_state_change_objects.size} objects into db"
    GroupStateChange.import group_state_change_objects
  end

  def down
    drop_table :group_state_changes
  end

  private

  def get_date_id(timestamp)
    (timestamp.utc.to_i / 86400) # 1.day.to_i => 86400
  end
end
