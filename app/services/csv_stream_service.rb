class CSVStreamService
  def initialize(response)
    @response = response
  end

  def setup!(file_name, controller_instance, &block)
    set_csv_file_headers(file_name)
    set_streaming_headers

    controller_instance.status = HttpConstants::SUCCESS
    # Byte Order Mark (BOM) is added to render the CSV with accented characters in MS Excel 2007+
    # http://stackoverflow.com/a/155176
    # https://chronus.atlassian.net/browse/AP-14084?focusedCommentId=50542&page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel#comment-50542
    controller_instance.response_body = Enumerator.new { |stream| stream << UTF8_BOM; block.call(stream) }
  end

  private

  def set_csv_file_headers(file_name)
    @response.headers["Content-Type"] = "text/csv"
    @response.headers["Content-disposition"] = %{attachment; filename="#{file_name}"}
  end

  def set_streaming_headers
    @response.headers['X-Accel-Buffering'] = 'no'
    @response.headers['Last-Modified'] = Time.now.httpdate.to_s
    @response.headers.delete("Content-Length")
  end
end