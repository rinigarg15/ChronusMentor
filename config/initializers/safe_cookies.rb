SafeCookies.configure do |config|
  config.register_cookie AutoLogout::Cookie::SESSION_ACTIVE, expire_after: 1.year, http_only: false
end