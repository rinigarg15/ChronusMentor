module ChronusFonts
  def self.update_fonts(pdf)
    meriyo_font_path = "#{Rails.public_path}/fonts/Meiryo/Meiryo.ttf"
    pdf.font_families.update(
      "Meiryo" => {
        :normal => meriyo_font_path,
        :italic => meriyo_font_path,
        :bold => meriyo_font_path,
        :bold_italic => meriyo_font_path
      },
      "OpenSans" => {
        :normal => "#{Rails.public_path}/fonts/OpenSans/OpenSans-Regular.ttf",
        :italic => "#{Rails.public_path}/fonts/OpenSans/OpenSans-Italic.ttf",
        :bold => "#{Rails.public_path}/fonts/OpenSans/OpenSans-Bold.ttf",
        :bold_italic => "#{Rails.public_path}/fonts/OpenSans/OpenSans-BoldItalic.ttf"
      }
    )
    pdf.font("OpenSans")
    pdf.fallback_fonts = ["Meiryo"]
  end
end