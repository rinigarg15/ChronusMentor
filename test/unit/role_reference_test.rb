require_relative './../test_helper.rb'

class RoleReferenceTest < ActiveSupport::TestCase
  def test_belongs_to_polymorphic_object
    assert_difference 'RoleReference.count' do
      @ref = RoleReference.create! :ref_obj => articles(:economy), :role => fetch_role(:albers, :admin)
    end

    assert_equal articles(:economy), @ref.ref_obj
    assert_equal fetch_role(:albers, :admin), @ref.role

    @ref.ref_obj = announcements(:assemble)
    @ref.save!
    assert_equal announcements(:assemble), @ref.reload.ref_obj
  end

  def test_validate_role_unique_for_ref_obj
    assert_difference 'RoleReference.count' do
      RoleReference.create! :ref_obj => articles(:economy), :role => fetch_role(:albers, :admin)
    end

    assert_no_difference 'RoleReference.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :role do
        RoleReference.create! :ref_obj => articles(:economy), :role => fetch_role(:albers, :admin)
      end
    end
  end

  def test_invlidated_ref_object_cache
    user = users(:f_mentor)
    cache_key = user.cache_key
    ref = nil
    Timecop.freeze(5.minutes.from_now) { ref = RoleReference.create! ref_obj: user, role: fetch_role(:albers, :admin) }
    assert_not_equal cache_key, user.cache_key
    cache_key = user.cache_key
    Timecop.freeze(10.minutes.from_now) do
      ref.role = fetch_role(:albers, :student)
      ref.save
    end
    assert_not_equal cache_key, user.cache_key
    cache_key = user.cache_key
    Timecop.freeze(15.minutes.from_now) { ref.destroy }
    assert_not_equal cache_key, user.cache_key
    cache_key = user.cache_key
  end

  def test_observers_reindex_es
    user = users(:f_mentor)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).never # Dont call if the ref obj type is not user
    RoleReference.create! :ref_obj => articles(:economy), :role => fetch_role(:albers, :admin)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(3).with(User, [user.id])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(3).with(Member, [user.member.id])
    role_reference = RoleReference.create! ref_obj: user, role: fetch_role(:albers, :admin) # 1st time

    role_reference.role = fetch_role(:albers, :student)
    role_reference.save # 2nd time

    role_reference.destroy # 3rd time
  end
end
