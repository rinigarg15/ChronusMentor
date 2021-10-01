require_relative './../../test_helper.rb'

class GenericKendoPresenterTest < ActiveSupport::TestCase
  def setup
    super
    @config = {
      :attributes => {
        :first_name => {
          :posted_as => "First Name",
          :filterable => true,
          :type => :string
        },
        :last_name => {
          :sortable => true,
          :filterable => true
        },
        :terms_and_conditions_accepted => {
          :filterable => true,
          :type => :datetime
        }
      },
      :default_scope => Member.where('members.id is NOT NULL')
    }
  end
  def test_initialize_should_configure_instance_variables_as_expected
    GenericKendoPresenter.any_instance.expects(:store_posts_to_attributes_hash).returns
    presenter = GenericKendoPresenter.new(Member, @config)
    assert_equal Member, presenter.instance_eval("@model")
  end

  # Filterable should be set to true
  def test_store_posts_to_attributes_hash
    presenter = GenericKendoPresenter.new(Member, @config)
    expected_posts_to_attrs_hash = {
      "First Name" => :first_name,
      "last_name" => :last_name,
      "terms_and_conditions_accepted" => :terms_and_conditions_accepted
    }
    assert_equal expected_posts_to_attrs_hash, presenter.instance_eval("@posts_to_attrs_hash")
  end

  def test_presenter_should_raise_expection_when_default_scope_is_not_set
    config = @config.clone
    config.delete(:default_scope)
    assert_raise RuntimeError, "Default Scope should be set" do
      presenter = GenericKendoPresenter.new(Member, config)
    end
  end


  def test_no_sort_options_present_should_work_as_expected
    presenter = GenericKendoPresenter.new(Member, @config)
    assert presenter.send(:no_sort_options_present?)

    params = first_name_sort_param
    presenter = GenericKendoPresenter.new(Member, @config, params)
    assert_false presenter.send(:no_sort_options_present?)
  end

  def test_no_filers_present_should_work_as_expected
    presenter = GenericKendoPresenter.new(Member, @config)
    assert presenter.send(:no_filters_present?)

    presenter = GenericKendoPresenter.new(Member, @config, {:filter => "null"})
    assert presenter.send(:no_filters_present?)

    presenter = GenericKendoPresenter.new(Member, @config, {:filter => first_name_filter})
    assert_false presenter.send(:no_filters_present?)
  end

  def test_no_pagination_options_present_should_work_as_expected
    presenter = GenericKendoPresenter.new(Member, @config)
    assert presenter.send(:no_pagination_options_present?)

    presenter = GenericKendoPresenter.new(Member, @config, {:take => 1})
    assert presenter.send(:no_pagination_options_present?)

    presenter = GenericKendoPresenter.new(Member, @config, {:skip => 1})
    assert presenter.send(:no_pagination_options_present?)

    presenter = GenericKendoPresenter.new(Member, @config, pagination_options)
    assert_false presenter.send(:no_pagination_options_present?)
  end

  def test_is_valid_filter_should_work_as_expected
    presenter = GenericKendoPresenter.new(Member, @config)
    assert presenter.send(:is_valid_filter?, "First Name")

    presenter = GenericKendoPresenter.new(Member, @config)
    assert presenter.send(:is_valid_filter?, "last_name")

    presenter = GenericKendoPresenter.new(Member, @config)
    assert_false presenter.send(:is_valid_filter?, "created_at")
  end

  def test_convert_kendo_date_to_datetime_in_user_timezone
    assert_equal "2015-01-06 00:00:00 UTC", GenericKendoPresenter.convert_kendo_date_to_datetime_in_user_timezone("1/6/2015", "gte").to_s
    assert_equal "2015-01-06 23:59:59 UTC", GenericKendoPresenter.convert_kendo_date_to_datetime_in_user_timezone("1/6/2015", "lte").to_s

    Time.zone = "Australia/Melbourne"
    assert_equal "2015-01-06 00:00:00 +1100", GenericKendoPresenter.convert_kendo_date_to_datetime_in_user_timezone("1/6/2015", "gte").to_s
    assert_equal "2015-01-06 23:59:59 +1100", GenericKendoPresenter.convert_kendo_date_to_datetime_in_user_timezone("1/6/2015", "lte").to_s
  end

  def test_default_scope_should_work_as_expected
    presenter = GenericKendoPresenter.new(Member, @config)
    assert_equal @config[:default_scope], presenter.send(:default_scope)
  end

  def test_has_custom_filtering_should_work_as_expected
    assert_false GenericKendoPresenter.has_custom_filtering?({})
    assert GenericKendoPresenter.has_custom_filtering?({:custom_filter => {}})
  end

  def test_custom_filter_scope_should_work_as_expected
    attr_config = {
      :custom_filter => Proc.new {|x| x}
    }
    assert_equal "Executing the block", GenericKendoPresenter.send(:custom_filter_scope, attr_config, "Executing the block")
  end

  def test_is_nested_filter_should_work_as_expected
    assert_false GenericKendoPresenter.is_nested_filter?({})
    assert GenericKendoPresenter.is_nested_filter?({:filters => {}})
  end

  def test_merge_scopes_should_return_default_scope_for_an_empty_array
    presenter = GenericKendoPresenter.new(Member, @config)
    assert_equal Member.where('members.id is NOT NULL'), presenter.send(:merge_scopes, [])
  end

  def test_merge_scopes_should_merge_the_array_of_scopes
    presenter = GenericKendoPresenter.new(Member, @config)

    active_or_dormant_scope = Member.where("state = ? OR state = ?", Member::Status::ACTIVE, Member::Status::DORMANT)
    suspended_scope = Member.where("state = #{Member::Status::SUSPENDED}")
    active_scope = Member.where("state = #{Member::Status::ACTIVE}")

    scopes = [suspended_scope, active_scope]


    merged_scope = presenter.send(:merge_scopes, [suspended_scope, active_scope])
    assert_equal 0, merged_scope.count

    # Scopes are already enumerated, build them again
    active_or_dormant_scope = Member.where("state = ? OR state = ?", Member::Status::ACTIVE, Member::Status::DORMANT)
    suspended_scope = Member.where("state = #{Member::Status::SUSPENDED}")
    active_scope = Member.where("state = #{Member::Status::ACTIVE}")

    expected_active_members = Member.where("state = #{Member::Status::ACTIVE}")
    merged_scope = presenter.send(:merge_scopes, [active_scope, active_or_dormant_scope])
    assert_equal expected_active_members.count, merged_scope.count
    assert_equal_unordered expected_active_members.collect(&:id), merged_scope.collect(&:id)
  end

  def test_pagination_scope
    expected_final_set = Member.where('members.id is NOT NULL').offset(1).limit(2)

    presenter = GenericKendoPresenter.new(Member, @config, pagination_options)
    returned_scope = presenter.send(:build_pagination_scopes)
    assert_equal 2, returned_scope.count
    assert_equal_unordered  expected_final_set.collect(&:id), returned_scope.collect(&:id)
  end

  def test_sort_ascending_order
    random_member = Member.order("RAND()").first
    random_member.update_attributes!(:first_name => "aaaaaaa")

    presenter = GenericKendoPresenter.new(Member, @config, first_name_sort_param)
    assert_equal random_member.id, presenter.send(:build_sort_scopes).first.id

  end

  def test_sort_descending_order
    random_member = Member.order("RAND()").first
    random_member.update_attributes!(:first_name => "zzzzzz")

    sort_params = first_name_sort_param
    sort_params[:sort]["0"][:dir] = "desc"

    presenter = GenericKendoPresenter.new(Member, @config, sort_params)
    assert_equal random_member.id, presenter.send(:build_sort_scopes).first.id
  end

  def test_build_simple_scope_should_return_default_scope_when_invalid_filter_is_passed
    presenter = GenericKendoPresenter.new(Member, @config, {})
    GenericKendoPresenter.any_instance.expects(:is_valid_filter?).returns(false)
    output = presenter.send(:build_simple_scope, {:filter => first_name_filter})
    assert_equal @config[:default_scope], output
  end


  def test_build_simple_scope_should_filter_string_type_column_based_on_input_filter
    presenter = GenericKendoPresenter.new(Member, @config)
    member1 = get_ram_member
    member1.update_attributes!(:first_name => "FilterFirstNameCheckOne")

    member2 = get_psg_member
    member2.update_attributes!(:first_name => "FilterFirstNameCheckTwo")

    output = presenter.send(:build_simple_scope, first_name_filter)
    assert_equal_unordered [member1.id, member2.id], output.collect(&:id)
  end

  def test_build_simple_scope_should_filter_datetype_type_column_based_on_input_filter
    presenter = GenericKendoPresenter.new(Member, @config)
    member1 = get_ram_member

    member1.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    output = presenter.send(:build_simple_scope, terms_filter_lte)
    assert_equal [member1.id], output.collect(&:id)

    member1.update_attributes!(:terms_and_conditions_accepted => DateTime.new(2030, 7, 28))

    presenter = GenericKendoPresenter.new(Member, @config)
    output = presenter.send(:build_simple_scope, terms_filter_gte)
    assert_equal [member1.id], output.collect(&:id)
  end

  def test_build_simple_scope_should_call_custom_scope_if_it_is_configured
    config = @config.clone
    member = members(:mkr_student)
    config[:attributes][:first_name][:custom_filter] = Proc.new{ |x| Member.where("first_name like 'mkr_student'") }

    presenter = GenericKendoPresenter.new(Member, @config)
    output = presenter.send(:build_simple_scope, first_name_filter)
    assert_equal member.id, output.first.id
  end

  def test_build_filter_scopes_should_work_when_date_range_params_are_passed
    params = {
      :filter => {
        :filters => {
          0 => {
            :field => "terms_and_conditions_accepted",
            :operator => "lte", #it supports contains only
            :value => "07/29/1987"
          },
          1 =>     {
            :field => "terms_and_conditions_accepted",
            :operator => "gte", #it supports contains only
            :value => "07/27/1987"
          }
        }
      }
    }

    member1 = get_ram_member
    member1.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))

    presenter = GenericKendoPresenter.new(Member, @config, params)
    output = presenter.send(:build_filter_scopes, params[:filter][:filters])
    assert_equal [member1.id], output.collect(&:id)
  end

  def test_build_filter_scopes_should_work_when_only_from_date_params_are_passed
    params = {
      "filter" => {
        "logic"=>"and",
        "filters"=>{
          "0" => {
            "field"=>"sent_on",
            "operator"=>"gte",
            "value"=>"2/2/2015"
           },
          "1" => {
              "field"=>"sent_on",
              "operator"=>"lte",
              "value"=>""
          }
        }
      }
    }

    invitation = ProgramInvitation.first
    assert invitation.is_sender_admin?
    presenter = GenericKendoPresenter.new(ProgramInvitation, GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(invitation.program, true), params)
    output = presenter.send(:build_filter_scopes, params["filter"]["filters"])
    assert_equal [invitation], output
  end

  def test_build_filter_scopes_should_work_when_only_to_date_params_are_passed
    params = {
      "filter" => {
        "logic"=>"and",
        "filters"=>{
          "0" => {
            "field"=>"sent_on",
            "operator"=>"gte",
            "value"=>""
           },
          "1" => {
              "field"=>"sent_on",
              "operator"=>"lte",
              "value"=>"26/1/2025"
          }
        }
      }
    }

    invitation = ProgramInvitation.first
    assert invitation.is_sender_admin?
    assert invitation.created_at < "26/01/2025".to_time
    presenter = GenericKendoPresenter.new(ProgramInvitation, GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(invitation.program, true), params)
    output = presenter.send(:build_filter_scopes, params["filter"]["filters"])
    assert_equal [invitation], output
  end

  def test_build_filter_scopes_should_work_when_multiple_filters_are_passed
    params = {
      :filter => {
        :filters => {
          0 => {
            :filters => {
              0 => {
                :field => "terms_and_conditions_accepted",
                :operator => "lte", #it supports contains only
                :value => "07/29/1987"
              },
              1 =>     {
                :field => "terms_and_conditions_accepted",
                :operator => "gte", #it supports contains only
                :value => "07/27/1987"
              }
            }
          },
          1 => {
            :field => "First Name",
            :operator => "contains", #it supports contains only
            :value => "FilterFirstNameCheck"
          }
        }
      }
    }

    member1 = get_ram_member
    member1.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member1.update_attributes!(:first_name => "FilterFirstNameCheckOne")

    member2 = get_psg_member
    member2.update_attributes!(:first_name => "FilterFirstNameCheckTwo")

    presenter = GenericKendoPresenter.new(Member, @config, params)
    output = presenter.send(:build_filter_scopes, params[:filter][:filters])
    assert_equal [member1.id], output.collect(&:id)
  end

  def test_build_all_scopes_should_return_default_scope_when_no_params_are_sent
    presenter = GenericKendoPresenter.new(Member, @config)
    assert_equal_unordered Member.all.collect(&:id), presenter.list.collect(&:id)
  end

  def test_filtered_scope_should_filter_based_on_filters
    params = {
      :filter => {
        :filters => {
          0 => {
            :filters => {
              0 => {
                :field => "terms_and_conditions_accepted",
                :operator => "lte", #it supports contains only
                :value => "07/29/1987"
              },
              1 =>     {
                :field => "terms_and_conditions_accepted",
                :operator => "gte", #it supports contains only
                :value => "07/27/1987"
              }
            }
          },
          1 => {
            :field => "First Name",
            :operator => "contains", #it supports contains only
            :value => "FilterFirstNameCheck"
          }
        }
      }
    }
    member1 = get_ram_member
    member1.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member1.update_attributes!(:first_name => "FilterFirstNameCheckaaaa")

    member2 = get_psg_member
    member2.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member2.update_attributes!(:first_name => "FilterFirstNameCheckbbbb")

    member3 = get_foster_member
    member3.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member3.update_attributes!(:first_name => "FilterFirstNameCheckcccc")

    presenter = GenericKendoPresenter.new(Member, @config, params)
    filtered_output = presenter.filtered_scope
    assert_equal_unordered [member1.id, member2.id, member3.id], filtered_output.collect(&:id)

    member3 = get_foster_member
    member3.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member3.update_attributes!(:first_name => "NotFilterNameCheckcccc")

    presenter = GenericKendoPresenter.new(Member, @config, params)
    filtered_output = presenter.filtered_scope
    assert_equal_unordered [member1.id, member2.id], filtered_output.collect(&:id)

  end

  def test_build_all_scopes_should_filter_based_on_filter_sort_pagination_params
    params = {
      :filter => {
        :filters => {
          0 => {
            :filters => {
              0 => {
                :field => "terms_and_conditions_accepted",
                :operator => "lte", #it supports contains only
                :value => "07/29/1987"
              },
              1 =>     {
                :field => "terms_and_conditions_accepted",
                :operator => "gte", #it supports contains only
                :value => "07/27/1987"
              }
            }
          },
          1 => {
            :field => "First Name",
            :operator => "contains", #it supports contains only
            :value => "FilterFirstNameCheck"
          }
        }
      },
      :sort => {
        "0" => {
          :field => "First Name",
          :dir => "asc"
        }
      },
      :take => "2",
      :skip => "1"
    }

    member1 = get_ram_member
    member1.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member1.update_attributes!(:first_name => "FilterFirstNameCheckaaaa")

    member2 = get_psg_member
    member2.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member2.update_attributes!(:first_name => "FilterFirstNameCheckbbbb")

    member3 = get_foster_member
    member3.update_attributes!(:terms_and_conditions_accepted => DateTime.new(1987, 7, 28))
    member3.update_attributes!(:first_name => "FilterFirstNameCheckcccc")

    presenter = GenericKendoPresenter.new(Member, @config, params)
    output = presenter.list
    assert_equal_unordered [member2.id, member3.id], output.collect(&:id)
    assert_equal 3, presenter.total_count
  end



  private
  def first_name_filter
    {
      :field => "First Name",
      :operator => "contains", #it supports contains only
      :value => "FilterFirstNameCheck"
    }
  end

  def terms_filter_lte
    {
      :field => "terms_and_conditions_accepted",
      :operator => "lte", #it supports contains only
      :value => "7/29/1987"
    }
  end

  def terms_filter_gte
    {
      :field => "terms_and_conditions_accepted",
      :operator => "gte", #it supports contains only
      :value => "1/1/2030"
    }
  end

  def first_name_sort_param
    {
      :sort => {
        "0" => {
          :field => "First Name",
          :dir => "asc"
        }
      }
    }
  end

  def pagination_options
    {
      :take => "2",
      :skip => "1"
    }
  end

  def get_ram_member
    members(:ram)
  end

  def get_psg_member
    members(:psg_student1)
  end

  def get_foster_member
    members(:foster_mentor6)
  end

end