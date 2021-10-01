require_relative './../../test_helper.rb'

class MentorRequest::InstructionTest < ActiveSupport::TestCase

  def test_translated_fields
    instruction = MentorRequest::Instruction.new(program: programs(:albers))
    Globalize.with_locale(:en) do
      instruction.content = "english content"
    end
    Globalize.with_locale(:de) do
      instruction.content = "Hindilu content"
    end
    instruction.save!
    Globalize.with_locale(:en) do
      assert_equal "english content", instruction.content
    end
    Globalize.with_locale(:de) do
      assert_equal "Hindilu content", instruction.content
    end
  end

  def test_populate_content_for_language
    program = programs(:albers)
    program.mentor_request_instruction.update_attributes!(content: "Default Mentor request content")
    Globalize.with_locale(:en) do
      assert_equal "Default Mentor request content", program.mentor_request_instruction.content
    end

    Globalize.with_locale(:de) do
      assert_equal "[[ Łéáνé á ɳóťé ƒóř ťĥé mentor áƀóůť ŵĥáť ýóů ářé łóóǩíɳǧ ƒóř. Ťĥé řéƣůéšť čáɳ ƀé šééɳ óɳłý ƀý ťĥé mentor áɳď ťĥé program administrators. ]]", program.mentor_request_instruction.content
    end
  end

  def test_populate_content_for_language_portal
    org = programs(:org_nch)
    program = programs(:primary_portal)
    assert_nil program.mentor_request_instruction

    Globalize.with_locale(:de) do
      assert_equal "[[ Łéáνé á ɳóťé ƒóř ťĥé mentor áƀóůť ŵĥáť ýóů ářé łóóǩíɳǧ ƒóř. Ťĥé řéƣůéšť čáɳ ƀé šééɳ óɳłý ƀý ťĥé mentor áɳď ťĥé program administrators. ]]", programs(:nch_mentoring).mentor_request_instruction.content
    end

    Globalize.with_locale(:en) do
      assert_equal "Leave a note for the mentor about what you are looking for. The request can be seen only by the mentor and the program administrators.", programs(:nch_mentoring).mentor_request_instruction.content
    end
  end

  def test_populate_content_with_default_value_if_nil
    program = programs(:albers)
    program.mentor_request_instruction.destroy
    instruction = MentorRequest::Instruction.create(program: program)
    program.reload
    Globalize.with_locale(:en) do
      assert_nil program.mentor_request_instruction.content
    end

    Globalize.with_locale(:de) do
      assert_nil program.mentor_request_instruction.content
    end

    instruction.populate_content_with_default_value_if_nil([:de])
    program.reload

    Globalize.with_locale(:en) do
      assert_nil program.mentor_request_instruction.content
    end

    Globalize.with_locale(:de) do
      assert_equal "[[ Łéáνé á ɳóťé ƒóř ťĥé mentor áƀóůť ŵĥáť ýóů ářé łóóǩíɳǧ ƒóř. Ťĥé řéƣůéšť čáɳ ƀé šééɳ óɳłý ƀý ťĥé mentor áɳď ťĥé program administrators. ]]", program.mentor_request_instruction.content
    end
  end

  def test_populate_content_with_default_value_if_nil_should_not_create_translation_for_portal
    program = programs(:primary_portal)
    instruction = MentorRequest::Instruction.create(program: program)
    program.reload
    Globalize.with_locale(:en) do
      assert_nil program.mentor_request_instruction.content
    end

    Globalize.with_locale(:de) do
      assert_nil program.mentor_request_instruction.content
    end


    instruction.populate_content_with_default_value_if_nil([:de])
    program.reload
    Globalize.with_locale(:en) do
      assert_nil program.mentor_request_instruction.content
    end

    Globalize.with_locale(:de) do
      assert_nil program.mentor_request_instruction.content
    end
  end

end