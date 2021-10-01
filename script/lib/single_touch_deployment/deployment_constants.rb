module DeploymentConstants
  PROG_NAME = "Single Touch Deployment"
  ENV_VARIABLES_PATH = "/usr/local/chronus/config/.env"
  PROD_ENV = ["demo", "productioneu", "veteransadmin", "production", "nch"]
  GIT_DEVELOP_MASTER = { #add new branch pair below, "develop" => "master" should be first
    "develop" => "master",
    "nch_develop" => "nch_deploy"
  }
  BRANCH_ENV = {
    "develop" => ["demo", "productioneu", "veteransadmin", "production"],
    "nch_develop" =>  ["nch"]
  }
  MASTER_BRANCH = "master"
  DEVELOP_BRANCH = "develop"
  EMAIL_RETRY_TIMES = 5
  EMAIL_RETRY_INTERVAL = 5 #seconds
  ENV_COLOR = {
    "demo" => :magenta,
    "production" => :cyan,
    "productioneu" => :yellow,
    "veteransadmin" => :magenta,
    "nch" => :light_magenta,
    "opstesting" => :magenta,
    "releasestaging2" => :cyan,
    "releasestaging1" => :yellow,
    "standby" => :light_green,
    "default" => :light_green,
  }
  SENDER_EMAIL_ID = "deployment_info@chronus.com"
  RECEIVER_EMAIL_ID = "apollodev@chronus.com"
  OPS_EMAIL_ID = "apolloops@chronus.com"
  API_RETRY_TIMES = 3 #seconds
  API_RETRY_INTERVAL = 5 #seconds
  BUILD_SLEEP_TIME = 300 #seconds
  BUILD_RETRY_COUNT = 8
  PAGERDUTY_MAINTENANCE = {
    "Pingdom alerts" => "PDLLEN3",
    "newrelic-alerts" => "P7RCWZL"
  }
  RETRY_DEPLOYMENT_STEPS_FILE = "/tmp/deployment_step_check.txt"
  PAGERDUTY_MAINTENANCE_TIME = 1800 #seconds
  PAGERDUTY_REQUEST_ID = "monitor@chronus.com"
  CRUCIBLE_API_URL = "http://chronus-corp.innoscale.net:443/rest-service"
  CRUCIBLE_AUTHOR_USERNAME = "ops"
  CRUCIBLE_AUTHOR_DISPLAYNAME = "ops"
  CRUCIBLE_AUTHOR_AVATARURL = "https://chronus-corp.innoscale.net/avatar/ops?s=48"
  DEPLOYMENT_ENV_VAR = {
    :force_full_deployment => 'FORCE_FULL_DEPLOYMENT',
    :skip_sphinx_restart => 'DISABLE_SPHINX_RESTART',
    :skip_match_indexing => 'DISABLE_MATCH_INDEXING',
    :full_es_reindex => 'FULL_ES_REINDEX',
    :skip_es_reindex => 'DISABLE_ES_REINDEX',
    :skip_delayed_job_restart => 'DISABLE_DELAYED_JOB_RESTART',
    :skip_clear_cache => 'DISABLE_CLEAR_CACHE',
    #:skip_recovery_setup => 'SKIP_RECOVERY_SETUP',
    :perform_match_indexing_now => 'PERFORM_MATCH_INDEXING_NOW'
    }
end
