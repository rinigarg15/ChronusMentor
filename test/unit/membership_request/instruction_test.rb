require_relative './../../test_helper.rb'

class MembershipRequest::InstructionTest < ActiveSupport::TestCase

  def test_instruction_type_cant_be_random
    instruction = MembershipRequest::Instruction.new(:program => programs(:albers))
    assert instruction.valid?
  end

  def test_translated_fields
    program = programs(:albers)
    instruction = program.build_membership_instruction
    Globalize.with_locale(:en) do
      instruction.content = "english content"
      instruction.save!
    end
    Globalize.with_locale(:de) do
      instruction.content = "hindilu content"
      instruction.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english content", instruction.content
    end
    Globalize.with_locale(:de) do
      assert_equal "hindilu content", instruction.content
    end
  end
end
