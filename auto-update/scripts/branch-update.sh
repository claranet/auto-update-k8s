VERSION="$1"
RELEASE_PATH_FILE="$2"
UPGRADE_FILE="$3"
SERVICE_NAME="$4"
CLUSTER_NAME="${CLUSTER_NAME:=""}"
ENV="${ENV:="prod"}"
POST_MESSAGE="${POST_MESSAGE:=""}"
DONT_PUBLISH="${DONT_PUBLISH:=0}"
VERSION_PATH="${VERSION_PATH:=".spec.chart.spec.version"}"

if [ "${VERSION}" == "null" ]; then
  echo "No version" > /dev/stderr && exit 0
fi

if [ "${VERSION}" == "" ]; then
  echo "No version" > /dev/stderr && exit 0
fi

# No if regex in shell
TEST=$(echo "${VERSION}" | grep -E "[0-9]+.[0-9]+.[0-9]+")
if [ "${TEST}" == "" ]; then
  echo "Bad format : ${VERSION}" > /dev/stderr && exit 0
fi

# Random sleep
sleep $((RANDOM % 120))

echo "Branch for new version ${ENV}/${SERVICE_NAME}-${VERSION}"
IMAGE_VERSION=$(yq '.target_update.app_version' < "${UPGRADE_FILE}")
if [ "$IMAGE_VERSION" == "null" ]; then
  echo "No image version found" && exit 0
fi

AUTO_UPDATE=$(yq '.auto_update.app_version' < "${UPGRADE_FILE}")

if [ "$AUTO_UPDATE" == "$IMAGE_VERSION" ]; then
  echo "Nothing to do, auto update version" && echo 0
fi

BRANCH_EXISTS=$(git branch -a | grep "${ENV}/${SERVICE_NAME}-${VERSION}")
if [ "$BRANCH_EXISTS" == "" ]; then
  yq -i "$VERSION_PATH = \"${VERSION}\"" "${RELEASE_PATH_FILE}"

  if [ "${HOOK}" != "" ]; then
    # shellcheck source=/dev/null
    source "${HOOK}"
  fi

  git checkout -b "${ENV}/${SERVICE_NAME}-${VERSION}"
  git add "${RELEASE_PATH_FILE}"
  git commit -m "[BRANCH-UPDATE][${ENV}/${SERVICE_NAME}] Helm chart version = ${VERSION} / app version = $IMAGE_VERSION ${POST_MESSAGE}"
  git push --set-upstream origin "${ENV}/${SERVICE_NAME}-${VERSION}"
  export GITLAB_TOKEN="${AUTO_UPDATE_TOKEN}"
  glab mr create -s "${ENV}/${SERVICE_NAME}-${VERSION}" -b "${TARGET_BRANCH}" -t "${ENV}/${SERVICE_NAME}-${VERSION}" -d "${ENV}/${SERVICE_NAME}-${VERSION}" --remove-source-branch -y --assignee "$ASSIGNEE"
  RESULT=$(echo $?)
  if [ "$(( $RESULT + $DONT_PUBLISH ))" -eq 0 ] && [ "$SLACK_HOOK_URL" != "" ]; then
    curl -X POST -H 'Content-type: application/json' --data "{'text':'[MERGE-REQUEST][${ENV}/${SERVICE_NAME}] Helm chart version = ${VERSION} / app version = $IMAGE_VERSION - ($CLUSTER_NAME) ${POST_MESSAGE}'}" "${SLACK_HOOK_URL}"
  fi
  exit "${RESULT}"
fi