module SanitizationsHelper
  def format_insecure_content(original_content, sanitized_content)
  	simplediff = Diffy::Diff.new(original_content, sanitized_content, :diff => ['-B', '--suppress-blank-empty', '-w', '-U 0'])
    htmldiff = simplediff.to_s(:html).html_safe
  end
end