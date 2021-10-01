#!/usr/bin/env sh

set -e

if [ ${CC_TEST_REPORTER_ID} ]
then
  PARTIAL_FILENAME="codeclimate.${TDDIUM_SESSION_ID}-${SOLANO_WORKER_NUM}.json"
  PARTIAL_FILE="coverage/${PARTIAL_FILENAME}"
  S3_FOLDER="s3://chronus-cc-coverage/coverage/${TDDIUM_CURRENT_COMMIT}"

  echo "### Formatting Coverage for CodeClimate to ${PARTIAL_FILE}"
  ./cc-test-reporter format-coverage --input-type simplecov --output "${PARTIAL_FILE}" --prefix "${TDDIUM_REPO_ROOT}" --debug

  echo "Uploading partial Coverage to ${S3_FOLDER}"
  aws s3 cp "${PARTIAL_FILE}" "${S3_FOLDER}/${PARTIAL_FILENAME}" --region "us-east-1" --sse
fi