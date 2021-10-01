#!/usr/bin/env sh

set -e

if [ ${CC_TEST_REPORTER_ID} ]
then
  S3_FOLDER="s3://chronus-cc-coverage/coverage/${TDDIUM_CURRENT_COMMIT}"
  MERGED_REPORT_FILE="coverage/codeclimate-${TDDIUM_SESSION_ID}-${TDDIUM_CURRENT_COMMIT}.json"

  echo "TDDIUM_BUILD_STATUS = ${TDDIUM_BUILD_STATUS}"
  if [ "passed" != "${TDDIUM_BUILD_STATUS}" ]
  then
    echo "Will only report coverage on passed builds"
  else
    echo "Downloading partial Coverage files from ${S3_FOLDER}"
    sleep 30 # wait for worker hooks to complete
    aws s3 sync "${S3_FOLDER}" coverage/

    if [ `ls -1 coverage/codeclimate.*.json | wc -l` = 8 ]
    then
      echo "Summing partial Coverage from `ls coverage/codeclimate.*.json` to ${MERGED_REPORT_FILE}"
      ./cc-test-reporter sum-coverage --output "${MERGED_REPORT_FILE}" coverage/codeclimate.*.json

      echo "Uploading merged Coverage from ${MERGED_REPORT_FILE} to CodeClimate"
      ./cc-test-reporter upload-coverage --input "${MERGED_REPORT_FILE}"
    else
      echo "Some partial coverage files are missing!"
    fi
  fi

  echo "Cleaning ${S3_FOLDER}"
  aws s3 rm "${S3_FOLDER}" --recursive
fi