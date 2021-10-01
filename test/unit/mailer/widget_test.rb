require_relative './../../test_helper.rb'

class Mailer::WidgetTest < ActiveSupport::TestCase
  
  def test_validations
    new_widget = Mailer::Widget.new()
    assert_false new_widget.valid?
    assert_equal ["can't be blank"], new_widget.errors[:uid]
    assert_equal ["can't be blank"], new_widget.errors[:program_id]

    widget = Mailer::Widget.create!(:program => programs(:org_primary), :uid => WidgetSignature.widget_attributes[:uid])
    new_widget = Mailer::Widget.new(:program => programs(:org_primary), :uid => WidgetSignature.widget_attributes[:uid])
    assert_false new_widget.valid?
    assert_equal ["has already been taken"], new_widget.errors[:uid]

    another_new_widget = Mailer::Widget.new(:program => programs(:org_anna_univ), :uid => WidgetSignature.widget_attributes[:uid])
    assert another_new_widget.valid?
  end

  def test_validate_source_tags
    widget = Mailer::Widget.new(:program => programs(:org_primary), :uid => WidgetSignature.widget_attributes[:uid])
    
    #Global tags
    widget.source = "{{program_name}}"
    assert widget.valid?

    #Specific tags
    widget.source = "{{program_name}} {{subprogram_or_program_name}}"
    assert widget.valid?

    #Invalid tags
    widget.source = "{{program_name}} {{subprogram_or_program_name}} {{invalidtag}}"
    assert_false widget.valid?
    assert_equal ["contains invalid tags - {{invalidtag}}"], widget.errors[:source]
  end

  def test_validate_source_tags_for_syntax_error
    widget = Mailer::Widget.new(:program => programs(:org_primary), :uid => WidgetSignature.widget_attributes[:uid])
    
    #Global tags
    widget.source = "{{<b>program_name</b>}}"
    assert_false widget.valid?
    assert_equal ["contains invalid syntax, donot apply any styles within flower braces of the tag"], widget.errors[:source]
  end

  def test_add_translation_for_existing_mailer_widgets
    program = programs(:albers)
    org = program.organization
    
    uid = WidgetSignature.widget_attributes[:uid]
    t1 = Mailer::Widget.create!(:program => org, :uid => uid, :source => "Thank you,")
    t2 = Mailer::Widget.create!(:program => program, :uid => uid, :source => "Thank you,")

    language = Language.first
    language.update_attribute(:language_name, "es")
    all_mailer_widgets = org.mailer_widgets

    org.programs.each {|program| all_mailer_widgets = all_mailer_widgets + program.mailer_widgets}
    all_mailer_widgets.collect(&:translations).flatten.select{|translation| translation.locale == :"es"}.each{|t| t.destroy}
    Mailer::Widget.add_translation_for_existing_mailer_widgets(org, language)
    GlobalizationUtils.run_in_locale("es") do
      (all_mailer_widgets.first(2) + [t1, t2]).uniq.each do |mailer_widget|
        assert_equal WidgetTag.get_descendant(mailer_widget.uid).default_template, mailer_widget.source
      end
    end
  end
end
