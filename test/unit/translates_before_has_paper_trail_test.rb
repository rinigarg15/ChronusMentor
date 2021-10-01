require_relative './../test_helper.rb'

class TranslatesBeforeHasPaperTrailTest < ActiveSupport::TestCase

  # Ensures that 'translates' is called before 'has_paper_trail' in ActiveRecord::Base inherited classes
  def test_ensure_translates_called_before_has_paper_trail
    ApplicationEagerLoader.load
    ActiveRecord::Base.descendants.each do |klass|
      next unless klass.respond_to?(:paper_trail_options?) && klass.translates?

      help_message = "Ensure translates called before has_paper_trail in #{klass}"
      paper_trail_callback_location = "#{Gem.loaded_specs['paper_trail'].full_gem_path}/lib/paper_trail/model_config.rb"
      after_update_callbacks = klass._update_callbacks.select { |cb| cb.kind.eql?(:after) }.map(&:raw_filter)
      after_update_callbacks = after_update_callbacks.map { |filter| filter.is_a?(Proc) ? filter.source_location[0] : filter }

      assert_equal [:update], klass.paper_trail_options[:on]
      assert after_update_callbacks.index(:save_translations!) > after_update_callbacks.index(paper_trail_callback_location), help_message
    end
  end

  def test_why_translates_before_has_paper_trail
    announcement = announcements(:assemble)
    assert_equal 1, announcement.version_number

    announcement.update_attributes!(title: "New Title")
    # if 'has_paper_trail' is declared before 'translates', both the below assertions will fail
    assert_equal 2, announcement.version_number
    assert_equal_hash( { "title" => ["All come to audi small", "New Title"] }, announcement.versions.last.modifications.pick("title"))
  end
end