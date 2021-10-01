require 'prawn'
require 'csv'

class MembershipRequestReport
  include ChronusFonts
  DefaultFontSize = 12
  SmallFontSize = 10
  ForegroundColors = {:default => "000000", :gray => "888888", :light_gray => "CCCCCC", :header => "900000"}
  BackgroundColors = {:light_1 => "F5F5F0", :light_2 => "FCFCF5", :white => "FFFFFF"}

  module CSV
    class << self
      def export_to_stream(stream, reqs, tab, with_header = true)
        program = reqs.first.program
        headers = MembershipRequest.header_for_exporting(program, tab)
        stream << ::CSV::Row.new(headers, headers).to_s if with_header
        MembershipRequest.data_for_exporting(program, reqs).each do |row_data|
          stream << ::CSV::Row.new(headers, row_data).to_s
        end
      end

      def generate(reqs, tab)
        ::CSV.generate { |csv| export_to_stream(csv, reqs, tab) }
      end
    end
  end

  module PDF
    class << self
      def generate(program, reqs, tab)
        pdf = Prawn::Document.new
        ChronusFonts.update_fonts(pdf)
        # Facing page
        facing_page(pdf, program)
        pdf.font_size DefaultFontSize # Reset font
        pdf.start_new_page

        header_fields = MembershipRequest.header_for_exporting(program, tab)
        data_array = MembershipRequest.data_for_exporting(program, reqs)

        # Print each request with student profile in a page
        data_array.each do |mem_req_data|
          request_details(pdf ,header_fields, mem_req_data)
        end
    
        pdf.render
      end

      def facing_page(pdf, program)
        pdf.move_down 200
        pdf.stroke_horizontal_rule
        pdf.move_down 50
        pdf.font_size 30
        pdf.text program.name, :align => :center
        pdf.font_size 20
        pdf.text "feature.membership_request.header.membership_requests".translate, :align => :center
        pdf.text "As on #{Date.today}", :align => :center
        pdf.move_down 50
        pdf.stroke_horizontal_rule
      end

      def request_details(pdf, header_fields, mem_req_data)
        request_info_rows = []
    
        # Remove rows (header + data) that do not have data.
        mem_req_data.each_with_index do |data, i|
          next unless data # No data, so skip this header+data field

          # Convert numbers to string with a trailing space so that they render
          # properly. Bug in prawn?
          request_info_rows << [header_fields[i], data]
        end

        request_info_rows.each do |q, ans|
          pdf.fill_color "4A4A4A"
          pdf.text "#{q} :", :align => :left, :style => :bold
          pdf.fill_color "000000"
          pdf.move_down 5
          pdf.text ans, :align => :left
          pdf.move_down 15
        end

        section_footer(pdf)
      end

      def section_footer(pdf)
        # 10pt margin top
        pdf.move_down 10
        pdf.fill_color ForegroundColors[:light_gray]
        pdf.stroke_horizontal_rule
        pdf.fill_color ForegroundColors[:default]

        # 10pt margin bottom
        pdf.move_down 10
      end
    end
  end
end
