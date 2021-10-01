require_relative './../test_helper.rb'

class ProgramActivityTest < ActiveSupport::TestCase
  def setup
    super
    @activity = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS,
      :member => members(:f_mentor)
    )
  end

  def test_non_null_requirement_for_foreign_keys
    activity = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS
    )

    #NULL activity_id not caught in database
    assert_difference 'ProgramActivity.count', 1 do
      ProgramActivity.create!(:program_id => programs(:albers).id)
    end
    #NULL program_id not caught in database
    assert_difference 'ProgramActivity.count', 1 do
      ProgramActivity.create!(:activity_id => activity.id)
    end
  end

  def test_program_should_have_the_activity_member
    program_activity = ProgramActivity.new(
      :activity => @activity, :program => programs(:psg)
    )

    assert_false program_activity.valid?
    assert program_activity.errors[:program]
  end

  def test_user
    @activity.programs << programs(:albers)

    albers_activity = ProgramActivity.last
    assert_equal users(:f_mentor), albers_activity.user

    @activity.programs << programs(:nwen)

    nwen_activity = ProgramActivity.last
    assert_equal users(:f_mentor_nwen_student), nwen_activity.user
  end

  def test_in_program_scope
    assert_equal [], ProgramActivity.in_program(programs(:albers))
    assert_equal [], ProgramActivity.in_program(programs(:nwen))

    @activity.programs << programs(:albers)

    albers_activity = ProgramActivity.last
    assert_equal [albers_activity], ProgramActivity.in_program(programs(:albers))
    assert_equal [], ProgramActivity.in_program(programs(:nwen))

    @activity.programs << programs(:nwen)
    nwen_activity = ProgramActivity.last
    assert_equal [albers_activity], ProgramActivity.in_program(programs(:albers))
    assert_equal [nwen_activity], ProgramActivity.in_program(programs(:nwen))
  end
end
