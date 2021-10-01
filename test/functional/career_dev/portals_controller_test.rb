require_relative './../../test_helper.rb'

class CareerDev::PortalsControllerTest < ActionController::TestCase
  include CareerDevTestHelper

  def setup
    super
    enable_career_development_feature(programs(:org_primary))
  end

  def test_new
    current_member_is :f_admin

    get :new
    assert_response :success
    assert_template 'new'
    assert assigns(:program)
    assert_equal CareerDev::Portal::ProgramType::CHRONUS_CAREER, assigns(:program).program_type
  end

  def test_new_with_employee_role
    portal = create_career_dev_portal
    user = create_user(:role_names => [RoleConstants::EMPLOYEE_NAME], :program => portal)

    current_member_is user.member

    assert_permission_denied do
      get :new
    end
  end

  def test_create_portal_from_standalone_program
    enable_career_development_feature(programs(:org_foster))
    current_user_is :foster_admin
    assert programs(:org_foster).standalone?

    assert_difference 'User.count' do
      assert_difference 'programs(:org_foster).reload.programs_count' do
        assert_difference 'programs(:org_foster).programs.reload.size' do
          post :create, params: { :career_dev_portal => {
            :name => 'CareerDev',
            :description => 'Career Program',
            :program_type => CareerDev::Portal::ProgramType::CHRONUS_CAREER,
            :number_of_licenses => 10000
          },
          :creation_way => Program::CreationWay::MANUAL}
        end
      end
    end
    program = Program.find_by(root: 'cd1')
    assert_false program.nil?

    assert_equal  'CareerDev', program.name
    assert_equal  'Career Program', program.description
    assert_equal  CareerDev::Portal::ProgramType::CHRONUS_CAREER, program.program_type
    assert_equal  10000, program.number_of_licenses
    assert_equal  Program::CreationWay::MANUAL, program.creation_way
    assert_equal  [members(:foster_admin)], program.users.collect(&:member)
    assert_redirected_to program_root_path(:root => 'cd1')

    user = program.users.first
    assert_equal user, assigns(:current_user)
    assert_equal user, program.owner

    programs(:foster).reload
    programs(:org_foster).reload

    assert_equal "foster", programs(:foster).name
    assert_equal "main", programs(:foster).root

    assert_equal "Foster School of Business", programs(:org_foster).name
    assert_equal "foster", programs(:org_foster).subdomain
  end

  def test_create_with_employee
    portal = create_career_dev_portal
    user = create_user(:role_names => [RoleConstants::EMPLOYEE_NAME], :program => portal)

    current_member_is user.member

    assert_permission_denied do
      post :create
    end
  end

  def test_create_portal_with_error
    current_user_is :portal_admin

    @controller.expects(:save_program).returns(false)
    assert_no_difference 'User.count' do
      assert_no_difference 'programs(:org_nch).reload.programs_count' do
        assert_no_difference 'programs(:org_nch).programs.reload.size' do
          post :create, params: { :career_dev_portal => {
            :name => 'CareerDev',
            :description => 'Career Program',
            :program_type => CareerDev::Portal::ProgramType::CHRONUS_CAREER,
            :number_of_licenses => 10000
          },
          :creation_way => Program::CreationWay::MANUAL}
        end
      end
    end

    assert_template :new
  end

  def test_create_portal_from_standalone_program_using_solution_pack
    organization = programs(:org_foster)
    enable_career_development_feature(organization)
    current_user_is :foster_admin
    assert organization.standalone?

    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/solution_pack_portal.zip'), mimeType)

    assert_difference 'User.count' do
      assert_difference 'organization.reload.programs_count' do
        assert_difference 'organization.programs.reload.count' do
          assert_difference 'Role.count', 2 do
            assert_difference 'CustomizedTerm.count', 7 do
              assert_difference 'Forum.count', 6 do
                assert_difference 'Survey.count', 10 do
                  assert_difference 'Section.count', 1 do
                    assert_difference 'AdminView.count', 7 do
                      assert_difference 'CampaignManagement::AbstractCampaign.count', 4 do
                        assert_difference 'Resource.count', 4 do
                          post :create, params: { :career_dev_portal => {
                            :name => 'CareerDev',
                            :description => 'Career Program',
                            :program_type => CareerDev::Portal::ProgramType::CHRONUS_CAREER,
                            :number_of_licenses => 10000,
                            :solution_pack_file => attached_file
                          }, :creation_way => Program::CreationWay::SOLUTION_PACK}
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    assert_equal "The solution pack was imported and the Program has been successfully setup!", flash[:notice]
    assert_redirected_to program_root_path(:root => 'cd1')

    program = Program.find_by(root: 'cd1')
    assert_false program.nil?

    assert_equal 'CareerDev', program.name
    assert_equal 'Career Program', program.description
    assert_equal CareerDev::Portal::ProgramType::CHRONUS_CAREER, program.program_type
    assert_equal 10000, program.number_of_licenses
    assert_equal Program::CreationWay::SOLUTION_PACK, program.creation_way
    assert_equal [members(:foster_admin)], program.users.collect(&:member)
    assert_redirected_to program_root_path(:root => 'cd1')

    user = program.users.first
    assert_equal user, assigns(:current_user)
    assert_equal user, program.owner

    programs(:foster).reload
    organization.reload

    assert_equal "foster", programs(:foster).name
    assert_equal "main", programs(:foster).root

    assert_equal "Foster School of Business", organization.name
    assert_equal "foster", programs(:org_foster).subdomain

    assert_equal 'wiki', program.customized_terms.find_by(term: 'Resource').term_downcase
  end

  def test_create_portal_from_standalone_program_error_using_solution_pack
    enable_career_development_feature(programs(:org_foster))
    current_user_is :foster_admin
    assert programs(:org_foster).standalone?

    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/solution_pack_portal.zip'), mimeType)

    CareerDev::PortalsController.any_instance.expects(:import_solution_pack).raises(->{StandardError.new("Some error")})

    assert_no_difference 'programs(:org_foster).programs.reload.count' do
      post :create, params: { :career_dev_portal => {
        :name => 'CareerDev',
        :description => 'Career Program',
        :program_type => CareerDev::Portal::ProgramType::CHRONUS_CAREER,
        :number_of_licenses => 10000,
        :solution_pack_file => attached_file
      },
      :creation_way => Program::CreationWay::SOLUTION_PACK}
    end

    assert_equal "Failed to create the program using solution pack", flash[:error]
    assert_redirected_to new_career_dev_portal_path(root: nil)
  end

  def test_import_role_permission_in_portal
    organization = programs(:org_foster)
    enable_career_development_feature(organization)
    current_user_is :foster_admin
    assert organization.standalone?

    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/solution_pack_portal.zip'), mimeType)

    post :create, params: { :career_dev_portal => {
      :name => 'CareerDev',
      :description => 'Career Program',
      :program_type => CareerDev::Portal::ProgramType::CHRONUS_CAREER,
      :number_of_licenses => 10000,
      :solution_pack_file => attached_file
    }, :creation_way => Program::CreationWay::SOLUTION_PACK}

    assert_equal "The solution pack was imported and the Program has been successfully setup!", flash[:notice]
    assert_redirected_to program_root_path(:root => 'cd1')
    role_permission_import_hash = {"employee" => ["write_article"]}

    program = Program.find_by(root: 'cd1')
    role_permission_import_hash.each do |role_name, permission_names|
      permission_names.each do |permission_name|
        assert program.has_role_permission?(role_name, permission_name)
      end
    end
  end
end
