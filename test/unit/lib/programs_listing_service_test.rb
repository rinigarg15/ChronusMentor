require_relative './../../test_helper.rb'

class ProgramsListingServiceTest < ActiveSupport::TestCase

  def test_set_program
    organization = programs(:org_nch)
    portal = programs(:primary_portal)
    track = programs(:nch_mentoring)
    disable_career_development_feature(organization)
    org_ctrl = OrganizationsController.new
    ProgramsListingService.fetch_programs(org_ctrl, organization) do |all_programs|
      all_programs.ordered
    end

    assert_equal [track], org_ctrl.instance_variable_get("@tracks")
    assert_nil org_ctrl.instance_variable_get("@portals")
    assert_equal 1, org_ctrl.instance_variable_get("@programs_view_count")
    assert_equal 1, org_ctrl.instance_variable_get("@program_types_count")

    enable_career_development_feature(organization)
    org_ctrl = OrganizationsController.new
    ProgramsListingService.fetch_programs(org_ctrl, organization) do |all_programs|
      all_programs.ordered
    end
    assert_equal [track], org_ctrl.instance_variable_get("@tracks")
    assert_equal [portal], org_ctrl.instance_variable_get("@portals")
    assert_equal 2, org_ctrl.instance_variable_get("@programs_view_count")
    assert_equal 2, org_ctrl.instance_variable_get("@program_types_count")

    # only mentoring organization
    organization = programs(:org_primary)
    org_ctrl = OrganizationsController.new
    ProgramsListingService.fetch_programs(org_ctrl, organization) do |all_programs|
      all_programs.ordered
    end
    program_ids = organization.programs.ordered.map{|p| p.id}
    assert_equal program_ids, org_ctrl.instance_variable_get("@tracks").map{|p| p.id}
    assert_nil org_ctrl.instance_variable_get("@portals")
    assert_equal 5, org_ctrl.instance_variable_get("@programs_view_count")
    assert_equal 1, org_ctrl.instance_variable_get("@program_types_count")

    options = {}
    options[Program::ProgramTypeConstants::PORTAL] = {association: :active_portals}
    options[Program::ProgramTypeConstants::TRACK] = {association: :active_tracks}
    member = members(:nch_admin)
    ProgramsListingService.fetch_programs self, member, member.organization, options do |all_programs|
      all_programs.ordered
    end
    assert_equal [track], self.instance_variable_get("@tracks")
    assert_equal [portal], self.instance_variable_get("@portals")
    assert_equal 2, self.instance_variable_get("@programs_view_count")
    assert_equal 2, self.instance_variable_get("@program_types_count")
  end  

  def test_listing_programs_test
    organization = programs(:org_nch)
    @tracks = organization.tracks
    @portals = organization.portals
    @programs_view_count = 2
    @program_types_count = 2
    divider = "==divider=="
    content = ProgramsListingService.list_programs self, nil do |programs, opts|
      programs.collect(&:name).join(', ')
    end

    assert_equal "Primary Career PortalNCH Mentoring Program", content

    content = ProgramsListingService.list_programs self, nil, divider: divider do |programs, opts|
      programs.collect(&:name).join(', ')
    end

    assert_equal "Primary Career Portal==divider==NCH Mentoring Program", content


    wrapper_proc = Proc.new do |programs, opts, &block|
      "##wrapper_start##" + block.call(programs, opts) + "##wrapper_end##"
    end

    content = ProgramsListingService.list_programs self, wrapper_proc do |programs, opts|
      programs.collect(&:name).join(', ')
    end

    assert_equal "##wrapper_start##Primary Career Portal##wrapper_end####wrapper_start##NCH Mentoring Program##wrapper_end##", content

    titles = []
    content = ProgramsListingService.list_programs self, wrapper_proc, divider: divider do |programs, opts|
      titles << opts[:title]
      programs.collect(&:name).join(', ')
    end

    assert_equal "##wrapper_start##Primary Career Portal##wrapper_end##==divider==##wrapper_start##NCH Mentoring Program##wrapper_end##", content

    assert_equal ["Career Tracking Program", "Program"], titles.uniq

    #Only mentoring program

    organization = programs(:org_primary)
    @tracks = organization.tracks
    @portals = organization.portals
    @programs_view_count = 5
    @program_types_count = 1
    divider = "==divider=="
    content = ProgramsListingService.list_programs self, nil do |programs, opts|
      programs.collect(&:name).join(', ')
    end

    assert_equal "Albers Mentor Program, Moderated Program, No Mentor Request Program, NWEN, Project Based Engagement", content

    content = ProgramsListingService.list_programs self, nil, divider: divider do |programs, opts|
      programs.collect(&:name).join(', ')
    end

    assert_equal "Albers Mentor Program, Moderated Program, No Mentor Request Program, NWEN, Project Based Engagement", content


    wrapper_proc = Proc.new do |programs, opts, &block|
      "##wrapper_start##" + block.call(programs, opts) + "##wrapper_end##"
    end

    content = ProgramsListingService.list_programs self, wrapper_proc do |programs, opts|
      programs.collect(&:name).join(', ')
    end

    assert_equal "Albers Mentor Program, Moderated Program, No Mentor Request Program, NWEN, Project Based Engagement", content

    content = ProgramsListingService.list_programs self, wrapper_proc, divider: divider do |programs, opts|
      programs.collect(&:name).join(', ')
    end

    assert_equal "Albers Mentor Program, Moderated Program, No Mentor Request Program, NWEN, Project Based Engagement", content


  end

  def test_get_merged_hash
    hash = {"a" => {"b" => 1, "c" => 2}}
    assert_equal hash, ProgramsListingService.get_merged_hash({"a" => {"b" => 1, "c" => 2}}, {})
    assert_equal hash, ProgramsListingService.get_merged_hash({"a" => {"b" => 1, "c" => 2}}, {"d" => {"c" => 3}})
    hash = {"a" => {"b" => 1, "c" => 3}}
    assert_equal hash, ProgramsListingService.get_merged_hash({"a" => {"b" => 1, "c" => 2}}, {"a" => {"c" => 3}})
  end

  def test_get_applicable_programs
    #standalone organization
    organization = programs(:org_foster)
    assert_equal [], ProgramsListingService.get_applicable_programs(organization)

    #mentoring organization
    organization = programs(:org_primary)
    assert_equal organization.programs.ordered.pluck(:id), ProgramsListingService.get_applicable_programs(organization).collect(&:id)
    
    #career dev
    organization = programs(:org_nch)
    disable_career_development_feature(organization)
    organization.reload
    assert_false organization.can_show_portals?
    assert_equal [programs(:nch_mentoring).id], ProgramsListingService.get_applicable_programs(organization).collect(&:id)

    enable_career_development_feature(organization)

    assert_equal [programs(:primary_portal).id, programs(:nch_mentoring).id], ProgramsListingService.get_applicable_programs(organization).collect(&:id)

    #check for the option conditions

    options = {}
    options[Program::ProgramTypeConstants::PORTAL] = {order: 100}
    options[Program::ProgramTypeConstants::TRACK] = {order: 10}
    organization = programs(:org_nch)
    assert_equal [programs(:nch_mentoring).id, programs(:primary_portal).id], ProgramsListingService.get_applicable_programs(organization, options).collect(&:id)
  end

  def _Program
    "Program"
  end

  def _Programs
    "Programs"
  end

  def _Career_Development
    "Career Tracking"
  end

end
