class ClamScanner
  def self.scan_file(file_path)
    scanner = self.clamd_running? ? "clamdscan" : "clamscan"
    result = `#{scanner} "#{file_path.shellescape}"`
    !(result =~ /Infected files: 0\n/).nil?
  end

  private
  
  def self.clamd_running?
    clamd_pidfile = '/var/run/clamav/clamd.pid'
    if File.file?(clamd_pidfile)
      begin
        true if Process.kill(0, File.read(clamd_pidfile).to_i)
      rescue Errno::ESRCH => process_killed
        false
      end
    else
      false
    end
  end
end