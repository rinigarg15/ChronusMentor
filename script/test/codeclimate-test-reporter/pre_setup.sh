#!/usr/bin/env sh

set -e

if [ ${CC_TEST_REPORTER_ID} ]
then
  echo "### Downloading CodeClimate's Test Reporter"
  curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > ./cc-test-reporter

  echo "### Making cc-test-reporter executable"
  chmod +x ./cc-test-reporter

  ./cc-test-reporter before-build
fi