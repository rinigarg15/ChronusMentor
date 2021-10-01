require_relative './../test_helper.rb'
require_relative './../../lib/ChronusTerminologyVerifier/terminology_verifier.rb'

class CustomizedTermTest < ActiveSupport::TestCase
  def test_belongs_to_ref_object
    assert_equal CustomizedTerm.first.ref_obj, programs(:org_primary)
  end

  def test_presence_of_ref_object
    ct = CustomizedTerm.create(:term => 'Test', :term_downcase => 'test', :pluralized_term => 'Tests', :pluralized_term_downcase => 'tests', :articleized_term => 'A Test', :articleized_term_downcase => 'a test', :term_type => 'test_type')
    assert_false ct.valid?
    assert_equal ["can't be blank"], ct.errors[:ref_obj]
  end

  def test_presence_of_different_forms_of_terms
    ref_obj = programs(:albers)
    ct = ref_obj.customized_terms.create(:term_type => 'test_type')
    assert_false ct.valid?
    assert_equal ["can't be blank"], ct.errors[:term]
    assert_equal ["can't be blank"], ct.errors[:term_downcase]
    assert_equal ["can't be blank"], ct.errors[:pluralized_term]
    assert_equal ["can't be blank"], ct.errors[:pluralized_term_downcase]
    assert_equal ["can't be blank"], ct.errors[:articleized_term]
    assert_equal ["can't be blank"], ct.errors[:articleized_term_downcase]
  end

  def test_presence_of_term_type
    ref_obj = programs(:albers)
    ct = ref_obj.customized_terms.create(:term => 'Test', :term_downcase => 'test', :pluralized_term => 'Tests', :pluralized_term_downcase => 'tests', :articleized_term => 'A Test', :articleized_term_downcase => 'a test')
    assert_false ct.valid?
    assert_equal ["can't be blank"], ct.errors[:term_type]
  end

  def test_uniqueness_of_term_type
    ref_obj = programs(:albers)
    ct1 = ref_obj.customized_terms.create(:term => 'Test', :term_downcase => 'test', :pluralized_term => 'Tests', :pluralized_term_downcase => 'tests', :articleized_term => 'A Test', :articleized_term_downcase => 'a test', :term_type => 'test_type')
    assert ct1.valid?
    ct2 = ref_obj.customized_terms.create(:term => 'Test2', :term_downcase => 'test2', :pluralized_term => 'Tests2', :pluralized_term_downcase => 'tests2', :articleized_term => 'A Test2', :articleized_term_downcase => 'a test2', :term_type => 'test_type')
    assert_false ct2.valid?
    assert_equal ["has already been taken"], ct2.errors[:term_type]
  end

  def test_save_term
    ct1 = programs(:albers).customized_terms.new.save_term('Test', CustomizedTerm::TermType::ROLE_TERM)
    assert ct1.valid?
    assert_equal programs(:albers), ct1.ref_obj
    assert_equal 'Test', ct1.term
    assert_equal 'Test'.downcase, ct1.term_downcase
    assert_equal 'Test'.pluralize, ct1.pluralized_term
    assert_equal 'Test'.pluralize.downcase, ct1.pluralized_term_downcase
    assert_equal 'Test'.articleize, ct1.articleized_term
    assert_equal 'Test'.articleize.downcase, ct1.articleized_term_downcase
    assert_equal CustomizedTerm::TermType::ROLE_TERM, ct1.term_type

    ct2 = programs(:albers).customized_terms.new.save_term('Another', 'some thing')
    assert ct2.valid?
    assert_equal programs(:albers), ct2.ref_obj
    assert_equal 'Another', ct2.term
    assert_equal 'Another'.downcase, ct2.term_downcase
    assert_equal 'Another'.pluralize, ct2.pluralized_term
    assert_equal 'Another'.pluralize.downcase, ct2.pluralized_term_downcase
    assert_equal 'Another'.articleize, ct2.articleized_term
    assert_equal 'Another'.articleize.downcase, ct2.articleized_term_downcase
    assert_equal 'some thing', ct2.term_type

    ct = programs(:albers).term_for(CustomizedTerm::TermType::RESOURCE_TERM)
    ct.destroy
    ct2 = programs(:albers).customized_terms.new.save_term('Helpdesk', CustomizedTerm::TermType::RESOURCE_TERM)
    assert_equal 'Helpdesk', ct2.term
    assert_equal 'helpdesk', ct2.term_downcase
    assert_equal 'Helpdesks', ct2.pluralized_term
    assert_equal 'helpdesks', ct2.pluralized_term_downcase
    assert_equal 'a Helpdesk', ct2.articleized_term
    assert_equal 'a helpdesk', ct2.articleized_term_downcase
    assert_equal CustomizedTerm::TermType::RESOURCE_TERM, ct2.term_type
  end

  def test_update_term
    ct1 = programs(:albers).customized_terms.new.save_term('Test', 'some thing')
    term_params = {:term => 'e1', :term_downcase => 'e2', :pluralized_term => 'e3', :pluralized_term_downcase => 'e4', :articleized_term => 'e5', :articleized_term_downcase => 'e6'}
    ct1.update_term(term_params)
    assert_equal programs(:albers), ct1.ref_obj
    assert_equal 'e1', ct1.term
    assert_equal 'e2', ct1.term_downcase
    assert_equal 'e3', ct1.pluralized_term
    assert_equal 'e4', ct1.pluralized_term_downcase
    assert_equal 'e5', ct1.articleized_term
    assert_equal 'e6', ct1.articleized_term_downcase
    
    term_params = {:term => 'Trial', :term_downcase => 'trial', :articleized_term => 'a Trial', :articleized_term_downcase => 'a trial'}
    ct1.update_term(term_params)
    assert_equal programs(:albers), ct1.ref_obj
    assert_equal 'Trial', ct1.term
    assert_equal 'trial', ct1.term_downcase
    assert_equal 'Trials', ct1.pluralized_term
    assert_equal 'trials', ct1.pluralized_term_downcase
    assert_equal 'a Trial', ct1.articleized_term
    assert_equal 'a trial', ct1.articleized_term_downcase

    term_params = {:term => 'Run'}
    ct1.update_term(term_params)
    assert_equal programs(:albers), ct1.ref_obj
    assert_equal 'Run', ct1.term
    assert_equal 'run', ct1.term_downcase
    assert_equal 'Runs', ct1.pluralized_term
    assert_equal 'runs', ct1.pluralized_term_downcase
    assert_equal 'a Run', ct1.articleized_term
    assert_equal 'a run', ct1.articleized_term_downcase
  end

  def test_catch_terms_not_customized
    result_hash = MissingCustomTerms.catch_terms_not_customized
    assert_equal ({}), result_hash
  end

  def test_catch_terms_not_customized_in_mails
    yaml_dir = "/config/locales/mails/*.en.yml"
    result_hash = MissingCustomTerms.catch_terms_not_customized(yaml_dir, true)
    assert_equal ({}), result_hash
  end

  def test_to_downcase
    assert_equal "abcd efgh", CustomizedTerm.first.to_downcase("AbCd EFgh")
  end
end