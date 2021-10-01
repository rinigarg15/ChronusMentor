require_relative '../test_helper'

class OrganizationLanguageObserverTest < ActiveSupport::TestCase
  def test_after_save
    program = programs(:foster)
    org = program.organization

    Mailer::Template.destroy_all
    Mailer::Widget.destroy_all

    t1 = Mailer::Template.create!(:program => program, :uid => ProgramReportAlert.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t2 = Mailer::Template.create!(:program => org, :uid => MemberSuspensionNotification.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    w1 = Mailer::Widget.create!(:program => org, :uid => WidgetSignature.widget_attributes[:uid], :source => "Thank you,")
    w2 = Mailer::Widget.create!(:program => program, :uid => WidgetSignature.widget_attributes[:uid], :source => "Thank you,")
    mentor_request_instruction = MentorRequest::Instruction.create!(:program => program, :content => "hello")

    num_programs = org.programs.count
    role_count = org.programs.collect(&:roles_without_admin_role).flatten.count
    assert_equal num_programs, 1

    OrganizationLanguage.any_instance.expects(:handle_enabled_program_languages).at_least(1)
    assert_difference 'Program::Translation.count', num_programs do
      assert_difference 'Mailer::Template::Translation.count', 2 do
        assert_difference 'Mailer::Widget::Translation.count', 2 do
          assert_difference 'MentorRequest::Instruction::Translation.count', num_programs do
            assert_difference 'OrganizationLanguage.count', 1 do
              assert_difference 'Role::Translation.count', role_count do
                ol = org.organization_languages.create!(language: languages(:hindi), enabled: OrganizationLanguage::EnabledFor::ALL)
              end
            end
          end
        end
      end
    end

    org.programs.each do |prog|
      assert_equal "program_settings_strings.content.zero_match_score_message_placeholder".translate(locale: :de), prog.translation_for("de").zero_match_score_message
    end

    assert_no_difference 'Program::Translation.count' do
      assert_no_difference 'Mailer::Template::Translation.count' do
        assert_no_difference 'Mailer::Widget::Translation.count' do
          assert_no_difference 'MentorRequest::Instruction::Translation.count' do
            assert_no_difference 'OrganizationLanguage.count' do
              assert_no_difference 'Role::Translation.count' do
                ol = org.organization_languages.create!(language: languages(:telugu), enabled: OrganizationLanguage::EnabledFor::NONE)
              end
            end
          end
        end
      end
    end

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [38]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [38]).once
    organization_language = organization_languages(:hindi)
    organization_language.update_attribute(:title, "Oriya")
  end

  def test_after_save_for_portal
    portal = programs(:primary_portal)
    program = programs(:nch_mentoring)
    org = program.organization

    Mailer::Template.destroy_all
    Mailer::Widget.destroy_all

    t1 = Mailer::Template.create!(:program => portal, :uid => ProgramReportAlert.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t2 = Mailer::Template.create!(:program => program, :uid => ProgramReportAlert.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    t3 = Mailer::Template.create!(:program => org, :uid => MemberSuspensionNotification.mailer_attributes[:uid], :source => "Yours sincerely", :subject => "Subject", :enabled => true, :content_changer_member_id => 1, :content_updated_at => Time.now)
    w1 = Mailer::Widget.create!(:program => org, :uid => WidgetSignature.widget_attributes[:uid], :source => "Thank you,")
    w2 = Mailer::Widget.create!(:program => program, :uid => WidgetSignature.widget_attributes[:uid], :source => "Thank you,")
    w3 = Mailer::Widget.create!(:program => portal, :uid => WidgetSignature.widget_attributes[:uid], :source => "Thank you,")

    mentor_request_instruction = MentorRequest::Instruction.create!(:program => program, :content => "hello")

    num_programs = org.programs.count

    OrganizationLanguage.any_instance.expects(:handle_enabled_program_languages)
    role_count = org.programs.collect(&:roles_without_admin_role).flatten.count
    assert_equal num_programs, 2
    assert_difference 'Program::Translation.count', 1 do
      assert_difference 'Mailer::Template::Translation.count', 3 do
        assert_difference 'Mailer::Widget::Translation.count', 3 do
          assert_difference 'MentorRequest::Instruction::Translation.count', 1 do
            assert_difference 'OrganizationLanguage.count', 1 do
              assert_difference 'Role::Translation.count', role_count do
                ol = org.organization_languages.create!(:language => languages(:telugu), enabled: OrganizationLanguage::EnabledFor::ALL)
              end
            end
          end
        end
      end
    end

    org.tracks.each do |prog|
      assert_equal "program_settings_strings.content.zero_match_score_message_placeholder".translate(locale: :de), prog.translation_for("de").zero_match_score_message
    end
  end

  def test_before_create
    program = programs(:albers)
    org = program.organization
    org.organization_languages.delete_all
    language = Language.first
    ol = org.organization_languages.create!(:language => language)
    assert_equal ol.language_name , language.language_name
  end
end