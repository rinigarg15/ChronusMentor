namespace :single_time do
  desc 'Update closed invalid groups with default closure reason'
  task update_closure_reason: :environment do
    group_closure_reason_ids = Group.pluck(:closure_reason_id).uniq
    closure_reason_ids = GroupClosureReason.pluck(:id)
    invalid_closure_reason_ids = group_closure_reason_ids - closure_reason_ids
    Group.where(closure_reason_id: invalid_closure_reason_ids).group_by(&:program).each do |program, groups|
    default_closure_reason_id = program.default_closure_reasons.first.id
    groups.each{|gp| gp.update_attribute(:closure_reason_id, default_closure_reason_id)}
    end
  end
end
