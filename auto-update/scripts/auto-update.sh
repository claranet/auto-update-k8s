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
sleep $((RANDOM % 120)) && git pull

IMAGE_VERSION=$(yq '.auto_update.app_version' < "${UPGRADE_FILE}")
yq -i "$VERSION_PATH = \"$1\"" "${RELEASE_PATH_FILE}"

# Possibility to add hook function
if [ "${HOOK}" != "" ]; then
  # shellcheck source=/dev/null
  source "${HOOK}"
fi

git add "${RELEASE_PATH_FILE}"
git commit -m "[AUTO-UPDATE][${SERVICE_NAME}] Helm chart version = ${VERSION} / app version = ${IMAGE_VERSION} ${POST_MESSAGE}"
git pull && git push
RESULT=$(echo $?)
if [ "$(( $RESULT + $DONT_PUBLISH ))" -eq 0 ]; then
  curl -X POST -H 'Content-type: application/json' --data "{'text':'[AUTO-UPDATE][${SERVICE_NAME}] Helm chart version = ${VERSION} / app version = ${IMAGE_VERSION} - ($CLUSTER_NAME)($ENV) ${POST_MESSAGE}'}" "${SLACK_HOOK_URL}"
fi

exit "${RESULT}"