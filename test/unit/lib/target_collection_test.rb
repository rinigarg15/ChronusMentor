require_relative './../../test_helper.rb'

class TargetCollectionTest < ActiveSupport::TestCase
  #for details refer: https://docs.google.com/spreadsheets/d/1Zlyjhcu9p6FV6Ws43U4gjEF4kZqk8ksX3my6Un0ncZk/edit#gid=167212739

  MODELS_TO_IGNORE = ["Delayed::Backend::ActiveRecord::Job", "ActsAsTaggableOn::Tag", "SimpleCaptcha::SimpleCaptchaData","AbstractRequest", "Globalize::ActiveRecord::Translation", "ObjectPermission", "ActiveRecord::SessionStore::Session", "Location", "LocationLookup", "ProgramSurvey", "EngagementSurvey", "MeetingFeedbackSurvey", "ConnectionView", "FlagView", "MeetingRequestView", "MembershipRequestView", "MentorRequestView", "ProgramInvitationView", "ProjectRequestView", "CampaignManagement::AbstractCampaignMessage", "Ckeditor::AttachmentFile", "Ckeditor::Picture", "Language", "CampaignManagement::AbstractCampaignMessageJob", "CampaignManagement::AbstractCampaignStatus", "AbstractBulkMatch", "BookListItem", "SiteListItem", "Feature", "Permission", "ActiveRecord::Base", "ActiveRecord::SchemaMigration", "ChronusDocs::AppDocument", "AbstractNote", "ChrRakeTasks", "CalendarSyncNotificationChannel", "CalendarSyncErrorCases", "SchedulingAccount", "CalendarSyncRsvpLogs", "ActsAsTaggableOn::Tagging", "PaperTrail::Version", "PaperTrail::VersionAssociation", "FeedExporter::ConnectionConfiguration", "FeedExporter::MemberConfiguration", "AbstractPreference"]

  GLOBAL_MODELS = ["ActsAsTaggableOn::Tag", "ObjectPermission", "Location", "LocationLookup","Language","Feature", "Permission", "ChronusDocs::AppDocument"]

  def test_collect_data_to_be_deleted
    @visited = {}
    @collected_models = []
    ApplicationEagerLoader.load(skip_engines: true)
    collect_dependent_models
    total_models = get_all_models
    models_covered = @collected_models.uniq
    #Checking whether all the models are covered as part of deletion of an organization. If there is a failure here, please make sure that 
    #1. if you have added a new model, associate it with organization or some child of an organization or add it as part of GLOBAL_MODELS in this file
    #2. if you have removed a model, please make appropriate changes here also.
    #NOTE: make sure you don't add it to MODELS_TO_IGNORE unless its really necessary
    assert_equal_unordered total_models,(models_covered + MODELS_TO_IGNORE)
    #Checking if the global models are not included as part of models iterated
    assert (models_covered & GLOBAL_MODELS).empty?, "Global models should not be covered as part of this"
  end

  def test_check_destroy_callbacks_introduced
    expected_hash = YAML.load(IO.read(Rails.root.to_s + "/test/fixtures/files/instance_migrator/after_destroy_callbacks.ym"))

    output_hash = {}
    ApplicationEagerLoader.load
    ActiveRecord::Base.descendants.each do |model|
      callbacks = model._destroy_callbacks.select {|cb| cb.kind.eql?(:before) || cb.kind.eql?(:after) }.collect(&:filter)
      reject_list = ["lock!", "decrement_positions_on_lower_items", "zdt_delayed_delete_es_document", "_update_counts_after_destroy", "create_destroyed_version", "apply_orphan_strategy", "touch_ancestors_callback", "reload"]
      callbacks.reject!{|cb| cb.is_a?(Fixnum) || reject_list.include?(cb.to_s) }
      output_hash[model.name] ||= callbacks if callbacks.present?
    end
    message = "If any model’s after_destroy callback has to be invoked in target_deletion rake, then please add the corresponding model to OrganizationData::TargetDeletion::MODELS_TO_DESTROY constant and have the after_destroy functionality inside 'handle_destroy' method. Note: Reason is program level observer of TargetDeletion::MODELS_TO_DESTROY models are changing global level models state."
    assert_compare_hash output_hash, expected_hash, message
  end

  private

  def get_all_models(model = ActiveRecord::Base, keys=[])
    model.subclasses.each do |sub|
      keys = get_all_models(sub,keys)
    end
    keys << model.to_s
  end

  def collect_received_mails
    collect_models_recursively(ReceivedMail)
  end

  def collect_abstract_program
    collect_models_recursively(AbstractProgram)
  end

  def collect_article_content
    collect_models_recursively(ArticleContent)
  end

  def collect_organization
    collect_models_recursively(Organization)
  end

  def collect_models_recursively(parent_model)
    @collected_models << parent_model.to_s
    associations = OrganizationData::TargetCollection.get_dependent_associations_to_be_deleted(parent_model)
    return if associations.empty?
    associations.each do |association_key,association|
      uniqhash = OrganizationData::TargetCollection.get_uniq_key(parent_model.to_s + "=>" + association_key.to_s)
      unless @visited[uniqhash]
        child_model = association.klass
        @visited[uniqhash]=true
        collect_models_recursively(child_model)
      end
    end
  end

  def collect_dependent_models
    collect_received_mails
    collect_abstract_program
    collect_article_content
    collect_organization
  end

  def assert_compare_hash(a, b, message)
    a_minus_b = (a.to_a - b.to_a).to_h
    b_minus_a = (b.to_a - a.to_a).to_h
    assert_equal a, b, "#{message} \nAdditions: #{a_minus_b} \nRemovals: #{b_minus_a} \nDiscuss with Architecture team for further details.\n".green
  end
end