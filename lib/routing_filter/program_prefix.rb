module RoutingFilter
  class ProgramPrefix < Filter
    def around_recognize(path, request, &block)
      # Extract the program root at the start of the path and replace it with empty
      # string.
      path.sub!(%r(^/#{SubProgram::PROGRAM_PREFIX}([^/]+))) { "" }
      path.replace("/") if path.blank?
      program_root = $1

      request.env['CURRENT_PROGRAM_ROOT'] = program_root if program_root
      yield.tap do |params|
        # Add the program root to the params if specified.
        params[:root] = program_root if program_root
      end
    end

    def around_generate(*args, &block)
      # Extract the :root option
      program_root = args.extract_options!.delete(:root)

      yield.tap do |result|
        url = result.is_a?(Array) ? result.first : result

        # Prefix the generated url with the program root if specified.
        url.sub!(%r(^(http.?://[^/]*)?(.*))) { "#{$1}/#{SubProgram::PROGRAM_PREFIX}#{program_root}#{$2}" } if program_root
      end
    end
  end
end
