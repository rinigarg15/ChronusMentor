require_relative './../../test_helper.rb'

class ActiveRecordStuffTest < ActiveSupport::TestCase

  def startup
    Object.const_set("Car", Class.new(ActiveRecord::Base) do
      sanitize_html_attributes :name, :description
      belongs_to_admin_with_validations foreign_key: 'admin_id'
      belongs_to_mentor_with_validations foreign_key: 'mentor_id'
      belongs_to_student_with_validations :pupil, foreign_key: 'pupil_id'
    end )

    Object.const_set("Bike", Class.new(ActiveRecord::Base) do
      belongs_to_admin_with_validations validate_presence: false, foreign_key: 'admin_id'
      belongs_to_mentor_with_validations validate_presence: false, foreign_key: 'mentor_id'
      belongs_to_student_with_validations :pupil, validate_presence: false, foreign_key: 'pupil_id'
      belongs_to_program
      acts_as_role_based skip_validation: true
    end )

    Object.const_set("Toy", Class.new(ActiveRecord::Base) do
      belongs_to :shop
      belongs_to :user
      belongs_to_program foreign_key: 'shop_program_id'
      acts_as_filterable_for_member foreign_key: 'shop_program_id'
      scope :with_remote, -> { where(has_remote: true) }
    end )

    Object.const_set("Shop", Class.new(ActiveRecord::Base) do
      has_many :new_toys, class_name: 'Toy'
      acts_as_filterable_for_member foreign_key: 'shop_program_id', association: { name: 'new_toys', table: 'toys' }
    end )
  end

  def shutdown
    [Car, Bike, Toy, Shop].each do |klass|
      ActiveRecord::Base.direct_descendants.delete(klass)
      Object.send(:remove_const, klass.name)
    end
  end

  def setup_db
    ActiveRecord::Base.connection.create_table :cars, force: true, temporary: true do |t|
      t.column :admin_id,    :integer
      t.column :mentor_id,    :integer
      t.column :pupil_id,    :integer
      t.column :role,         :integer
      t.column :name,         :string
      t.column :description,  :string
      t.timestamps null: false
    end

    ActiveRecord::Base.connection.create_table :bikes, force: true, temporary: true do |t|
      t.column :admin_id,    :integer
      t.column :mentor_id,    :integer
      t.column :student_id,    :integer
      t.column :pupil_id,     :integer

      t.references :program
      t.column :driver_type, :integer
    end

    ActiveRecord::Base.connection.create_table :toys, force: true, temporary: true do |t|
      t.integer :shop_program_id
      t.integer :shop_id
      t.references :user
      t.boolean :has_remote
    end

    ActiveRecord::Base.connection.create_table :shops, force: true, temporary: true do |t|
    end
  end

  def teardown_db
    ActiveRecord::Base.connection.drop_table(:cars, temporary: true)
    ActiveRecord::Base.connection.drop_table(:bikes, temporary: true)
    ActiveRecord::Base.connection.drop_table(:toys, temporary: true)
    ActiveRecord::Base.connection.drop_table(:shops, temporary: true)
  end

  def setup
    super
    setup_db
  end

  def teardown
    super
    teardown_db
  end

  def test_belongs_to_with_validations
    car = Car.new
    assert !car.valid?
    assert_equal ["can't be blank"], car.errors[:admin]
    assert_equal ["can't be blank"], car.errors[:mentor]
    assert_equal ["can't be blank"], car.errors[:pupil]

    car = Car.new(
      admin: users(:f_mentor),
      mentor: users(:f_student),
      pupil: users(:f_admin))
    assert !car.valid?
    assert_equal ["is not admin"], car.errors[:admin]
    assert_equal ["is not mentor"], car.errors[:mentor]
    assert_equal ["is not student"], car.errors[:pupil]

    car = Car.new(admin: users(:f_admin), mentor: users(:f_mentor), pupil_id: users(:f_student).id)
    assert car.valid?
  end

  def test_belongs_to_with_validations_with_options
    bike = Bike.new
    assert bike.valid?

    bike_1 = Bike.new(
      admin: users(:f_mentor),
      mentor: users(:f_student),
      pupil_id: users(:f_admin).id)

    assert !bike_1.valid?
    assert_equal ["is not admin"], bike_1.errors[:admin]
    assert_equal ["is not mentor"], bike_1.errors[:mentor]
    assert_equal ["is not student"], bike_1.errors[:pupil]

    bike_2 = Bike.new(admin: users(:f_admin),
      mentor: users(:f_mentor),
      pupil: users(:f_student))
    assert bike_2.valid?
  end

  def test_acts_as_filterable_for_member
    ceg_toy = Toy.create!(user: users(:ceg_admin), program: programs(:ceg), has_remote: true)
    psg_toy = Toy.create!(user: users(:student_3), program: programs(:psg), has_remote: false)

    assert_equal [ceg_toy], Toy.accessible_to(members(:sarat_mentor_ceg))
    assert_equal [ceg_toy], Toy.accessible_to(members(:sarat_mentor_ceg)).with_remote
    assert_equal [ceg_toy], Toy.with_remote.accessible_to(members(:sarat_mentor_ceg))

    assert_equal [psg_toy], Toy.accessible_to(members(:psg_mentor1))
    assert Toy.accessible_to(members(:psg_mentor1)).with_remote.empty?
    assert Toy.with_remote.accessible_to(members(:psg_mentor1)).empty?

    assert_equal [ceg_toy, psg_toy], Toy.accessible_to(members(:anna_univ_mentor))
    assert_equal [ceg_toy], Toy.accessible_to(members(:anna_univ_mentor)).with_remote
    assert_equal [ceg_toy], Toy.with_remote.accessible_to(members(:anna_univ_mentor))

    shop_1 = Shop.create!
    shop_2 = Shop.create!

    toy_1 = Toy.create!(program: programs(:albers), shop: shop_1)
    toy_2 = Toy.create!(program: programs(:ceg), shop: shop_2)

    assert_equal [toy_1], shop_1.new_toys
    assert_equal [toy_2], shop_2.new_toys

    assert_equal [shop_1], Shop.accessible_to(members(:f_mentor))
    assert_equal [shop_2], Shop.accessible_to(members(:f_mentor_ceg))
    assert_equal [shop_2], Shop.accessible_to(members(:anna_univ_mentor))
  end

  #
  # Tests the HTML sanitization behaviour of ActiveRecord::Base.sanitize_html_attributes
  #
  def test_sanitize_html_attributes
    car = Car.new(
      admin: users(:f_admin),
      mentor: users(:f_mentor),
      pupil: users(:f_student)
    )

    # Open office comment
    car.name = "Toyota&lt;!--     @page { size: 21cm 29.7cm; margin: 2cm }    P { margin-bottom: 0.21cm }   --&gt; Innova"
    car.description = "Good car. Mileage is <!--[if gte mso 9]><xml> Normal   0         false   false   false                             MicrosoftInternetExplorer4 </xml><![endif]--> pretty ok"
    car.expects(:sanitize_attribute).with(:name).once
    car.expects(:sanitize_attribute).with(:description).once
    car.save!

    # Make sure no exception is thrown.
    car.name = nil
    car.description = nil
    car.expects(:sanitize_attribute).with(:name).once
    car.expects(:sanitize_attribute).with(:description).once
    car.save!
  end

  #
  # Tests the HTML sanitization behaviour of ActiveRecord::Base.sanitize_html_attributes
  #
  def test_sanitize_attribute
    car = Car.new(
      admin: users(:f_admin),
      mentor: users(:f_mentor),
      pupil: users(:f_student)
    )

    # Open office comment
    car.name = "Toyota&lt;!--     @page { size: 21cm 29.7cm; margin: 2cm }    P { margin-bottom: 0.21cm }   --&gt; Innova"
    car.description = "Good car. Mileage is <!--[if gte mso 9]><xml> Normal   0         false   false   false                             MicrosoftInternetExplorer4 </xml><![endif]--> pretty ok"
    car.sanitize_attribute(:name)
    assert_equal "Toyota Innova", car.name
    assert_equal "Good car. Mileage is <!--[if gte mso 9]><xml> Normal   0         false   false   false                             MicrosoftInternetExplorer4 </xml><![endif]--> pretty ok", car.description

    car.sanitize_attribute(:description)
    assert_equal "Good car. Mileage is  pretty ok", car.description

    # Make sure no exception is thrown.
    car.name = nil
    car.sanitize_attribute(:name)
  end

  def test_pluralize
    assert_equal "IIT AluMnus", "IIT AluMni".singularize
    assert_equal "AluMni", "AluMnus".pluralize
    assert_equal "Alumnus Mentors", "Alumnus Mentor".pluralize
    assert_not_equal "aluMni", "AluMnus".pluralize
  end

  def test_humanized_model_name
    assert_equal "Mentor Requests", MentorRequest.humanized_model_name
    assert_equal "Tasks", MentoringModel::Task.humanized_model_name
  end

  def test_fetch_with_offset
    assert_equal User.fetch_with_offset(4, 4, include: :ratings), User.includes(:ratings).limit(4).offset(4)
    assert_equal User.fetch_with_offset(4, 4, {}), User.limit(4).offset(4)
  end

  def test_strip_whitespace_from
    password = Password.new(email: "  acbc@sad.com  ")
    assert_equal "acbc@sad.com", password.strip_whitespace_from(password.email)
  end

  def test_org_setting_allow_vulnerable_content_by_admin
    announcement = Announcement.last
    assert_false announcement.nil?
    program = announcement.program
    organization = program.organization
    assert_equal ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V2, organization.security_setting.sanitization_version
    announcement.sanitization_version = organization.security_setting.sanitization_version
    admin_member = organization.members.where(admin: true).first
    test_body_content = "test<script>alert(1)</script>"

    organization.security_setting.update_attribute(:allow_vulnerable_content_by_admin, false)
    announcement.current_member = admin_member
    announcement.body = test_body_content
    announcement.save
    assert_equal "testalert(1)", announcement.reload.body

    organization.security_setting.update_attribute(:allow_vulnerable_content_by_admin, true)
    announcement.current_member = admin_member.reload
    announcement.body = test_body_content
    announcement.save
    assert_equal test_body_content, announcement.reload.body
  end

  def test_get_attachment
    group = groups(:group_5)
    task_1 = create_mentoring_model_task(group: group, user: group.students.first, from_template: false)
    comment = create_task_comment(task_1, content: "Test Comment comment", attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text"))
    attachment = comment.get_attachment
    assert_equal attachment.original_filename, comment.attachment_file_name
    assert_equal attachment.content_type, comment.attachment_content_type
  end

  def test_source_audit_key_column
    # with timestamps
    assert ActiveRecord::Base.connection.column_exists?(:cars, SOURCE_AUDIT_KEY.to_sym)
    # without timestamps
    assert_false ActiveRecord::Base.connection.column_exists?(:cars, :shops)
    assert_gem_version "activerecord", "5.1.4", "#timestamps method in ActiveRecord::ConnectionAdapters::TableDefinition is overridden to add a column source_audit_key"
    # all the tables should have column source_audit_key
    connection = ActiveRecord::Base.connection
    result = connection.exec_query("SELECT table_name FROM INFORMATION_SCHEMA.TABLES T WHERE T.table_schema = '#{connection.current_database}' AND T.TABLE_TYPE = 'BASE TABLE' AND NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS C WHERE C.TABLE_SCHEMA = T.TABLE_SCHEMA AND C.TABLE_NAME = T.TABLE_NAME AND C.COLUMN_NAME = '#{SOURCE_AUDIT_KEY}')")
    tables = result.rows.try(:flatten)
    tables -=["schema_migrations"]
    assert_equal 0, tables.count
  end

  def test_assoc_based_methods
    assert_equal [:vulnerable_content_logs, :role_references, :roles, :user, :program, :campaign_jobs, :status, :emails, :event_logs, :job_logs], ProgramInvitation.reflect_on_all_associations.collect(&:name)
    assert_equal [:role_references, :campaign_jobs, :status, :job_logs], ProgramInvitation.get_eager_loadables_for_destroy
    assert_equal_hash( {
      "vulnerable_content_logs" => "ref_obj_id",
      "role_references" => "ref_obj_id",
      "campaign_jobs" => "abstract_object_id",
      "status" => "abstract_object_id",
      "emails" => "abstract_object_id",
      "job_logs" => "ref_obj_id",
    }, ProgramInvitation.get_assoc_name_foreign_key_map)
  end

  def test_update_columns_patch_for_es_delta_indexing
    ChronusElasticsearch.skip_es_index = false
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:f_mentor).id]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:f_student).id]).once
    users(:f_mentor).update_columns(updated_at: Time.now)
    # with reload
    users(:f_student).reload.update_columns(updated_at: Time.now)
    # skip delta indexing
    users(:f_student).update_columns(updated_at: Time.now, skip_delta_indexing: true)
    ChronusElasticsearch.skip_es_index = true
  end

  def test_update_column_patch_for_es_delta_indexing
    ChronusElasticsearch.skip_es_index = false
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:f_mentor).id]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:f_student).id]).once
    users(:f_mentor).update_column(:updated_at, Time.now)
    # with reload
    users(:f_student).reload.update_column(:updated_at, Time.now)
    ChronusElasticsearch.skip_es_index = true
  end

  def test_update_all_patch_for_es_delta_indexing
    ChronusElasticsearch.skip_es_index = false
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:f_mentor).id]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [users(:f_student).id]).once
    User.where(id: users(:f_mentor).id).update_all(updated_at: Time.now)
    # with reload
    User.where(id: users(:f_student).id).reload.update_all(updated_at: Time.now)
    # skip delta indexing
    User.where(id: users(:f_student).id).update_all(updated_at: Time.now, skip_delta_indexing: true)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [12]).once
    # es_reindex
    ConnectionMembershipStateChange.where(id: connection_membership_state_changes(:connection_membership_state_changes_3)).update_all(updated_at: Time.now)
    ChronusElasticsearch.skip_es_index = true
  end

  def test_delete_all_patch_for_es_delta_indexing
    ChronusElasticsearch.skip_es_index = false

    message1 = create_message
    message2 = create_message
    message3 = create_message

    DelayedEsDocument.expects(:delayed_bulk_delete_es_documents).with(AbstractMessage, [message1.id]).once
    DelayedEsDocument.expects(:delayed_bulk_delete_es_documents).with(AbstractMessage, [message2.id]).once
    DelayedEsDocument.expects(:delayed_bulk_delete_es_documents).with(AbstractMessage, [message3.id]).times(0)
    AbstractMessage.where(id: message1.id).delete_all
    # with reload
    AbstractMessage.where(id: message2.id).reload.delete_all
    # skip delta indexing
    AbstractMessage.where(id: message3.id).reload.delete_all(skip_delta_indexing: true)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [42]).once
    # es_reindex
    ConnectionMembershipStateChange.where(id: connection_membership_state_changes(:connection_membership_state_changes_4)).delete_all
    ChronusElasticsearch.skip_es_index = true
  end

  def test_delete_patch_for_es_delta_indexing
    ChronusElasticsearch.skip_es_index = false

    message1 = create_message
    message2 = create_message

    DelayedEsDocument.expects(:delayed_bulk_delete_es_documents).with(AbstractMessage, [message1.id]).once
    DelayedEsDocument.expects(:delayed_bulk_delete_es_documents).with(AbstractMessage, [message2.id]).once
    AbstractMessage.where(id: message1.id).delete_all
    # with reload
    AbstractMessage.where(id: message2.id).reload.delete_all
    ChronusElasticsearch.skip_es_index = true
  end

  def test_update_and_delete_patch_for_skip_delta_indexing_block
    ChronusElasticsearch.skip_es_index = false
    message1 = create_message
    DelayedEsDocument.expects(:arel_delta_indexer).never
    DelayedEsDocument.skip_es_delta_indexing do
      AbstractMessage.where(id: message1.id).delete_all
    end

    DelayedEsDocument.expects(:arel_delta_indexer).never
    DelayedEsDocument.skip_es_delta_indexing do
      AbstractMessage.where(id: message1.id).update_all(updated_at: Time.now)
    end
    ChronusElasticsearch.skip_es_index = true
  end
end