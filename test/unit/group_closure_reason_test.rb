require_relative './../test_helper.rb'

class GroupClosureReasonTest < ActiveSupport::TestCase
  def test_association_scope_and_validations
    program = programs(:albers)
    closure_reason = program.group_closure_reasons.create!(reason: "reason")
    assert_equal program, closure_reason.program

    assert_equal closure_reason, GroupClosureReason.non_default.last
    assert !program.group_closure_reasons.default.include?(closure_reason)
    closure_reason.update_attributes!(is_default: true)
    assert program.group_closure_reasons.default.include?(closure_reason)

    assert program.group_closure_reasons.permitted.include?(closure_reason)
    closure_reason.update_attributes!(is_deleted: true)
    assert !program.group_closure_reasons.permitted.include?(closure_reason)
    closure_reason.update_attributes!(reason: "")
    closure_reason.update_attributes!(is_deleted: false)

    assert !program.group_closure_reasons.completed.include?(closure_reason)
    closure_reason.update_attributes!(is_completed: true)
    assert program.group_closure_reasons.completed.include?(closure_reason)
  end
end