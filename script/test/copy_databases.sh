#!/bin/bash

green='\e[0;32m'
NC='\e[0m' # No Color

function print_and_execute {
  echo -e "${green}$1 ${NC}"
  eval $1
}

processId=`ruby -e "puts ENV[:TEST_ENV_NUMBER.to_s]"`
password=$1

if [ $processId ]
then
  print_and_execute "rails db:create RAILS_ENV=test TEST_ENV_NUMBER=$processId"
  print_and_execute "rails db:environment:set RAILS_ENV=test TEST_ENV_NUMBER=$processId"
  print_and_execute "rails db:drop db:create RAILS_ENV=test TEST_ENV_NUMBER=$processId"
  if [ $password ]
  then
    print_and_execute "mysql -uroot -p$password groups_test$processId < tmp/sqldump.sql"
  else
    print_and_execute "mysql -uroot groups_test$processId < tmp/sqldump.sql"
  fi
  print_and_execute "mongorestore -d matching_test$processId --dir=tmp/matching_test --drop --quiet"
  print_and_execute "bundle exec rake es_indexes:copy_indices TEST_ENV_NUMBER=$processId RAILS_ENV=test"
fi