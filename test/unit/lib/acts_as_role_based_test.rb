require_relative './../../test_helper.rb'

class ActsAsRoleBasedTest < ActiveSupport::TestCase

  def startup
    Object.const_set("Branch", Class.new(ActiveRecord::Base) { belongs_to :tree } )

    Object.const_set("Tree", Class.new(ActiveRecord::Base) do
      acts_as_role_based students_scope: :used_by_students,
        admins_scope: :dedicated_to_admin,
        role_assoc_after_add: :tree_after_add,
        role_assoc_before_remove: :tree_before_remove,
        role_assoc_after_remove: :tree_after_remove

      belongs_to_program
      has_many :branches, class_name: Branch.name
      scope :gigantic, -> { where("height > 5") }
      attr_accessor :tree_after_add_called, :tree_after_remove_called, :tree_before_remove_called

      def tree_after_add(_role)
        @tree_after_add_called = true
      end

      def tree_after_remove(_role)
        @tree_after_remove_called = true
      end

      def tree_before_remove(_role)
        @tree_before_remove_called = true
      end
    end )

    Object.const_set("AbstractBuilding", Class.new(ActiveRecord::Base) {} )

    Object.const_set("Building", Class.new(AbstractBuilding) do
      acts_as_role_based  role_association: 'occupant_role', skip_validation: true, program_assoc: :school
      belongs_to :school, class_name: 'Organization', foreign_key: 'program_id'
    end )

    Object.const_set("ShoppingComplex", Class.new(Building) {} )
  end

  def shutdown
    [Branch, Tree, AbstractBuilding, Building, ShoppingComplex].each do |klass|
      ActiveRecord::Base.direct_descendants.delete(klass) if klass.superclass == ActiveRecord::Base
      Object.send(:remove_const, klass.name)
    end
  end

  def setup_db
    ActiveRecord::Base.connection.create_table :trees, force: true, temporary: true do |t|
      t.column  :height,      :integer, default: 0
      t.column  :program_id,  :integer
      t.column  :created_at,  :datetime
      t.column  :updated_at,  :datetime
    end

    ActiveRecord::Base.connection.create_table :abstract_buildings, force: true, temporary: true do |t|
      t.column :program_id,  :integer
      t.column :type,       :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end

    ActiveRecord::Base.connection.create_table :branches, force: true, temporary: true do |t|
      t.references :tree
    end
  end

  def teardown_db
    ActiveRecord::Base.connection.drop_table(:trees, temporary: true)
    ActiveRecord::Base.connection.drop_table(:abstract_buildings, temporary: true)
    ActiveRecord::Base.connection.drop_table(:branches, temporary: true)
  end

  def setup
    super
    setup_db
  end

  def teardown
    super
    teardown_db
  end

  def test_role_name_accessors
    tree = Tree.new # Program not set
    assert tree.roles.empty?
    assert !tree.valid?
    assert tree.errors[:roles]

    # program should have been set.
    assert_raise AuthorizationManager::ProgramNotSetException do
      tree.role_names = [RoleConstants::STUDENT_NAME]
    end

    tree.program = programs(:albers)
    tree.role_names = [RoleConstants::STUDENT_NAME]
    assert tree.valid?
    tree.save!

    assert_equal [fetch_role(:albers, :student)], tree.roles.reload
    assert_equal_unordered [RoleConstants::STUDENT_NAME], tree.role_names

    tree.role_names = [RoleConstants::ADMIN_NAME, RoleConstants::STUDENT_NAME]
    assert_equal_unordered [RoleConstants::ADMIN_NAME, RoleConstants::STUDENT_NAME], tree.role_names
    tree.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], tree.role_names

    tree.role_names = [RoleConstants::ADMIN_NAME]
    assert_equal_unordered [RoleConstants::ADMIN_NAME], tree.role_names

    # Custom accessors
    building = Building.new(school: programs(:org_anna_univ))
    building.occupant_roles.empty?

    # No validations for building
    assert building.valid?
    building.occupant_role_names = [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]
    assert_equal_unordered [fetch_role(:org_anna_univ, :admin), fetch_role(:org_anna_univ, :mentor)], building.occupant_roles
    assert_equal_unordered [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME], building.occupant_role_names
    building.save!
    assert_equal_unordered [fetch_role(:org_anna_univ, :admin), fetch_role(:org_anna_univ, :mentor)], building.occupant_roles.reload
    assert_equal_unordered [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME], building.occupant_role_names
  end

  def test_after_add_after_remove_callbacks
    tree = Tree.new
    tree.program = programs(:albers)

    assert_nil tree.tree_after_add_called
    assert_nil tree.tree_after_remove_called

    tree.role_names = [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]
    assert tree.tree_after_add_called
    assert_nil tree.tree_after_remove_called
    assert_nil tree.tree_before_remove_called

    tree.role_names = [RoleConstants::STUDENT_NAME]
    assert tree.tree_after_add_called
    assert tree.tree_after_remove_called
    assert tree.tree_before_remove_called
  end

  def test_formatted_str
    organization = programs(:org_primary)
    building = Building.new(school: organization)
    building.occupant_role_names = [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]
    assert_equal 'Administrator and Mentor', building.formatted_occupant_role_names
    assert_equal 'an Administrator and Mentor', building.formatted_occupant_role_names(articleize: true)

    building.occupant_role_names = [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]
    assert_equal 'Mentor and Student', building.formatted_occupant_role_names
    assert_equal 'mentor and student', building.formatted_occupant_role_names(
      no_capitalize: true)
    assert_equal 'mentors and students', building.formatted_occupant_role_names(
      no_capitalize: true, pluralize: true)
    assert_equal 'a Mentor and Student', building.formatted_occupant_role_names(
      articleize: true)
    assert_equal 'a mentor and student', building.formatted_occupant_role_names(
      no_capitalize: true, articleize: true)
  end

  def test_role_names_str
    building = Building.new(school: programs(:org_anna_univ))
    building.occupant_role_names = [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]
    assert_equal "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME}",
        building.occupant_role_names_str
  end

  def test_role_scopes
    assert Tree.for_mentors.empty?
    assert Tree.used_by_students.empty?
    assert Tree.dedicated_to_admin.empty?

    tree_1 = Tree.new(program: programs(:ceg), height: 6)
    tree_1.role_names = [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]
    tree_1.save!

    assert_equal [tree_1], Tree.for_mentors.reload
    assert_equal [], Tree.used_by_students.reload
    assert_equal [tree_1], Tree.dedicated_to_admin.reload

    tree_2 = Tree.new(program: programs(:ceg), height: 4)
    tree_2.role_names = [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]
    tree_2.save!

    assert_equal [tree_1, tree_2], Tree.for_mentors
    assert_equal [tree_2], Tree.used_by_students
    assert_equal [tree_1], Tree.dedicated_to_admin

    # for_role
    assert_equal [tree_1, tree_2], Tree.for_role(RoleConstants::MENTOR_NAME)
    assert_equal [tree_2], Tree.for_role(RoleConstants::STUDENT_NAME)
    assert_equal [tree_1], Tree.for_role(RoleConstants::ADMIN_NAME)
    assert_equal [tree_1, tree_2], Tree.for_role([RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME])

    # Following call should not result in duplicate tree_1 records.
    assert_equal [tree_1, tree_2], Tree.for_role([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    # Cascaded named scopes.
    assert_equal [tree_1], Tree.for_role([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).gigantic
    assert_equal 2, Tree.for_role([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).uniq.count
    assert_equal 2, Tree.for_role([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).uniq.size
    assert_equal 2, Tree.for_role([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).uniq.length

    tree_3 = Tree.new(program: programs(:ceg))
    tree_3.role_names = [RoleConstants::MENTOR_NAME]
    tree_3.save!

    tree_4 = Tree.new(program: programs(:ceg))
    tree_4.role_names = [RoleConstants::STUDENT_NAME]
    tree_4.save!

    # not_for_only_role
    assert_equal [tree_1, tree_2, tree_4], Tree.not_for_only_role(RoleConstants::MENTOR_NAME)
    assert_equal [tree_1, tree_2, tree_3], Tree.not_for_only_role(RoleConstants::STUDENT_NAME)
    assert_equal [tree_1, tree_2, tree_3, tree_4], Tree.not_for_only_role(RoleConstants::ADMIN_NAME)
    assert_equal [tree_2, tree_4], Tree.not_for_only_role([RoleConstants::MENTOR_NAME, RoleConstants::ADMIN_NAME])
    assert_equal [tree_1], Tree.not_for_only_role([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_equal [tree_1, tree_2, tree_3], Tree.not_for_only_role([RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME])
  end

  def test_sti_base_table_name
    sc_1 = ShoppingComplex.new(school: programs(:org_anna_univ))
    sc_1.occupant_role_names = [RoleConstants::STUDENT_NAME]
    sc_1.save!

    sc_2 = ShoppingComplex.new(school: programs(:org_anna_univ))
    sc_2.occupant_role_names = [RoleConstants::MENTOR_NAME]
    sc_2.save!

    assert_equal [sc_2], ShoppingComplex.for_mentors
    assert_equal [sc_1], ShoppingComplex.for_students
  end

  def test_has_any_role
    building = Building.new(school: programs(:org_anna_univ))
    building.occupant_role_names = [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]
    assert building.has_any_occupant_role?([fetch_role(:org_anna_univ, :admin), fetch_role(:albers, :mentor)])
    assert building.has_any_occupant_role?([fetch_role(:org_anna_univ, :admin)])
    assert building.has_any_occupant_role?([fetch_role(:org_anna_univ, :mentor)])
    assert !building.has_any_occupant_role?([fetch_role(:org_anna_univ, :student)])

    building.occupant_role_names = [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]
    assert !building.has_any_occupant_role?([fetch_role(:org_anna_univ, :admin)])
    assert building.has_any_occupant_role?([fetch_role(:org_anna_univ, :mentor)])
    assert building.has_any_occupant_role?([fetch_role(:org_anna_univ, :student)])
    assert building.has_any_occupant_role?([fetch_role(:org_anna_univ, :admin), fetch_role(:albers, :student)])
  end

  # While applying a role scope, the other roles of the model should also be
  # included. Though we are testing a basic ActiveRecord joins functionality,
  # this test is present so as to capture any problems with eager loading, where
  # some roles are not loaded.
  def test_role_scope_fetches_other_roles_too
    building = Building.new(school: programs(:org_anna_univ))
    building.occupant_role_names = [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]
    building.save!

    # Both the roles must be there.
    assert_equal_unordered [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME],
      Building.for_admins.first.occupant_role_names
    assert_equal_unordered [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME],
      Building.for_mentors.first.occupant_role_names
    assert_equal_unordered [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME],
      Building.for_role(RoleConstants::ADMIN_NAME).first.occupant_role_names
  end

  # Ensure all second order associations are fetched when a role scope is applied.
  def test_included_associations_are_fetched
    tree_1 = Tree.new(program: programs(:ceg))
    tree_1.role_names = [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]
    tree_1.save!

    b1 = Branch.create!(tree: tree_1)
    b2 = Branch.create!(tree: tree_1)
    assert_equal [b1, b2], tree_1.branches
    trees = Tree.for_role([RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME]).includes([:branches])
    assert_equal tree_1, trees.first
    assert_equal [b1, b2], trees.first.branches
  end

  def test_recent_activity_target
    tree = Tree.new(program: programs(:albers))
    tree.role_names = [RoleConstants::MENTOR_NAME]
    tree.save!
    assert_equal RecentActivityConstants::Target::MENTORS, tree.recent_activity_target
    tree.role_names = [RoleConstants::STUDENT_NAME]
    tree.save!
    assert_equal RecentActivityConstants::Target::MENTEES, tree.reload.recent_activity_target
    tree.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    tree.save!
    assert_equal RecentActivityConstants::Target::ALL, tree.reload.recent_activity_target
  end
end
