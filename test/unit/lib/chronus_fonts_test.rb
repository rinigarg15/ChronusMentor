require_relative './../../test_helper.rb'

class ChronusFontsTest < ActionView::TestCase
  include ChronusFonts

  def test_update_fonts
    pdf = Prawn::Document.new
    ChronusFonts::update_fonts(pdf)
    assert_equal "OpenSans", pdf.font.basename
    assert_equal ["Meiryo"], pdf.fallback_fonts
  end

  def test_meiryo_font_styles
    pdf = Prawn::Document.new
    ChronusFonts::update_fonts(pdf)
    assert pdf.font_families.keys.include?("Meiryo")
    meiryo_family = pdf.font_families["Meiryo"]
    assert meiryo_family[:normal].present?
    assert meiryo_family[:bold].present?
    assert meiryo_family[:italic].present?
    assert meiryo_family[:bold_italic].present?
  end

  def test_open_sans_font_styles
    pdf = Prawn::Document.new
    ChronusFonts::update_fonts(pdf)
    assert pdf.font_families.keys.include?("OpenSans")
    meiryo_family = pdf.font_families["OpenSans"]
    assert meiryo_family[:normal].present?
    assert meiryo_family[:bold].present?
    assert meiryo_family[:italic].present?
    assert meiryo_family[:bold_italic].present?
  end
end
