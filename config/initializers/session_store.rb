# Use the database for sessions instead of the cookie-based default, which shouldn't be used to store highly confidential information

ChronusMentorBase::Application.config.session_store :active_record_store, key: '_mentor_session', domain: :all, tld_length: 4