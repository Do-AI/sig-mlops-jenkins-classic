#!/bin/bash

# ENSURE WE ARE IN THE DIR OF SCRIPT
cd -P -- "$(dirname -- "$0")"
# SO WE CAN MOVE RELATIVE TO THE ACTUAL BASE DIR

export GITOPS_REPO="seldon-gitops"
export GITOPS_ORG="Do-AI"
export STAGING_FOLDER="staging"
export PROD_FOLDER="production"

# This is the user that is going to be assigned to PRs
export GIT_MANAGER="litiblue"

export UUID=$(cat /proc/sys/kernel/random/uuid)

echo "=== clone ${GITOPS_REPO} ==="
git clone https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GITOPS_ORG}/${GITOPS_REPO}

cd ${GITOPS_REPO}
cp -r ../charts/* ${STAGING_FOLDER}/.
ls ${STAGING_FOLDER}

# Check if any modifications identified
echo "=== aaa ==="
git add -N ${STAGING_FOLDER}/
git --no-pager diff --exit-code --name-only origin/master ${STAGING_FOLDER}
STAGING_MODIFIED=$?
if [[ $STAGING_MODIFIED -eq 0 ]]; then
  echo "Staging env not modified"
  exit 0
fi

echo "=== bbb ==="
# Adding changes to staging repo automatically
git add ${STAGING_FOLDER}/
echo "=== bbb - commit ==="
git commit -m '{"Action":"Deployment created","Message":"","Author":"","Email":""}'
echo "=== bbb - push ==="
git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GITOPS_ORG}/${GITOPS_REPO}

echo "=== ccc ==="
# Add PR to prod
cp -r ../charts/* production/.

echo "=== ddd ==="
# Create branch and push
git checkout -b ${UUID}
git add ${PROD_FOLDER}/
git commit -m '{"Action":"Moving deployment to production repo","Message":"","Author":"","Email":""}'
git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GITOPS_ORG}/${GITOPS_REPO} ${UUID}

echo "=== eee ==="
# Create pull request
export PR_RESULT=$(curl \
  -u ${GIT_USERNAME}:${GIT_PASSWORD} \
  -v -H "Content-Type: application/json" \
  -X POST -d "{\"title\": \"SeldonDeployment Model Promotion Request - UUID: ${UUID}\", \"body\": \"This PR contains the deployment for the Seldon Deploy model and has been allocated for review and approval for relevant manager.\", \"head\": \"${UUID}\", \"base\": \"master\" }" \
  https://api.github.com/repos/$GITOPS_ORG/$GITOPS_REPO/pulls)
export ISSUE_NUMBER=$(echo \
  $PR_RESULT |
  python -c 'import json,sys;obj=json.load(sys.stdin);print(obj["number"])')

echo "=== fff ==="
# Assign PR to relevant user
curl \
  -u ${GIT_USERNAME}:${GIT_PASSWORD} \
  -v -H "Content-Type: application/json" \
  -X POST -d "{\"assignees\": [\"${GIT_MANAGER}\"] }" \
  https://api.github.com/repos/$GITOPS_ORG/$GITOPS_REPO/issues/$ISSUE_NUMBER
