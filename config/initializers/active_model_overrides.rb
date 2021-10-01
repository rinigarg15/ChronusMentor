module ActiveModel
  module Type
    class Integer < Value
      private

      def ensure_in_range(value)
        unless range.cover?(value)
          # Airbrake is generated to find out how many out of range values are being entered in our application.
          Airbrake.notify("#{value} is out of range for #{self.class} with limit #{_limit} bytes")
        end
      end
    end
  end
end