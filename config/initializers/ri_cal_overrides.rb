module RiCal
  class Component
    class Calendar < Component
      def chronus_ics_timezone_component=(vtimezone_string)
        @chronus_ics_timezone_component = vtimezone_string
      end

      def chronus_ics_timezone_component
        @chronus_ics_timezone_component
      end

      def export(to=nil)
        export_stream = FoldingStream.new(to)
        export_stream.puts("BEGIN:VCALENDAR")
        export_properties_to(export_stream)
        export_x_properties_to(export_stream)
        if chronus_ics_timezone_component.present?
          export_stream.puts(chronus_ics_timezone_component)
        else
          export_required_timezones(export_stream)
        end
        export_subcomponent_to(export_stream, events)
        export_subcomponent_to(export_stream, todos)
        export_subcomponent_to(export_stream, journals)
        export_subcomponent_to(export_stream, freebusys)
        subcomponents.each do |key, value|
          unless %{VEVENT VTODO VJOURNAL VFREEBUSYS}.include?(key)
            export_subcomponent_to(export_stream, value)
          end
        end
        export_stream.puts("END:VCALENDAR")
        if to
          nil
        else
          export_stream.string
        end
      end
    end
  end
end
