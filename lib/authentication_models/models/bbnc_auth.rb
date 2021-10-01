class BBNCAuth < ModelAuth
  #Blackbaud NetCommunity SSO Login - as requested by Singapore Management University
  #https://chronus.atlassian.net/browse/AP-586
  MAX_TIME_DIFF = 300 # The request timestamp should not differ by 300s
  def self.authenticate?(auth_obj, options = {})
    data = auth_obj.data[0]
    uid = data[:userid]
    ts = data[:ts]      # timestamp in http://msdn.microsoft.com/en-us/library/az4se3k1.aspx#Roundtrip string format
    sig   = data[:sig] # signature to verify the authenticity of request received
    private_key = options["private_key"]
    auth_obj.uid = uid
    # The request received is authentic if  sig = md5 (uid+ts+private_key)
    ((Time.parse(ts) - Time.now).abs < MAX_TIME_DIFF) && (sig == Digest::MD5.hexdigest(uid + ts + private_key)) 
  end
end

## Issues with BBNC Auth mechanism
# * prone to Man in Middle attack
# * any person monitoring the network can use the redirectURI with params and use it login posing as current user
#    Soln: Pass a one-time expiry token -- using timestamp to solve this to some extent
