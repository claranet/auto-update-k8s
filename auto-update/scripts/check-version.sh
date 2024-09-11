ACTUAL_VERSION="$1"
APP_PATH="$2"
AUTO_LEVEL="${AUTO_LEVEL:="minor"}" # fix / minor / major
TARGET_LEVEL="${TARGET_LEVEL:="major"}" # fix / minor / major
HEAD="${NB_CHECK_VERSION:=10}"
ACTUAL_MAJOR="$(echo "${ACTUAL_VERSION}" | cut -d '.' -f 1)"
ACTUAL_MINOR="$(echo "${ACTUAL_VERSION}" | cut -d '.' -f 2)"
ACTUAL_FIX="$(echo "${ACTUAL_VERSION}" | cut -d '.' -f 3)"

CANDIDATE_MINOR=0
CANDIDATE_FIX=0
CANDIDATE_MAJOR=0

ARTIFACTUB_PACKAGE="https://artifacthub.io/api/v1/packages/tekton-task/${APP_PATH}"
ARTIFACTUB_HELM="https://artifacthub.io/api/v1/packages/helm/${APP_PATH}"

if [ -z "${ACTUAL_VERSION}" ]; then
  echo "# No version" > /dev/stderr && exit 1
fi

if [ "${ACTUAL_VERSION}" == "" ]; then
  echo "# No version" > /dev/stderr && exit 0
fi

# No if regex in shell
echo "${ACTUAL_VERSION}" | grep -E "[0-9]+.[0-9]+.[0-9]+"  > /dev/null  || (echo "# Bad format : ${ACTUAL_VERSION}" && exit 1)

echo "# Auto-update level : ${AUTO_LEVEL}"

ACTUAL_APP_VERSION=$(curl -s -X 'GET' "${ARTIFACTUB_PACKAGE}/${ACTUAL_VERSION}" -H 'accept: application/json' | jq .app_version)

echo "checking_update:"
echo "  helm_chart_version: ${ACTUAL_VERSION}"
echo "  app_version: ${ACTUAL_APP_VERSION//\"}"

for version in $(curl -s -X 'GET' "${ARTIFACTUB_HELM}" -H 'accept: application/json' | jq '.available_versions | .[].version' | head -n "${HEAD}"); do 
  VERSION="${version//\"/}"
  MAJOR="$(echo "${VERSION}" | cut -d '.' -f 1)"
  MINOR="$(echo "${VERSION}" | cut -d '.' -f 2)"
  FIX="$(echo "${VERSION}" | cut -d '.' -f 3)"
  if [[ "$FIX" =~ [^0-9] ]]; then
    echo "# Skip version $VERSION"
    continue
  fi
  if [ "${MAJOR}" -gt "${ACTUAL_MAJOR}" ]; then
    if [ "${MAJOR}000${MINOR}000${FIX}" -gt "${CANDIDATE_MAJOR}" ]; then
      CANDIDATE_MAJOR="${MAJOR}000${MINOR}000${FIX}"
      CANDIDATE_VERSION_MAJOR="${VERSION}"
    else
      continue
    fi
  elif [ "${MAJOR}" -eq "${ACTUAL_MAJOR}" ]; then
    if [ "${MINOR}" -gt "${ACTUAL_MINOR}" ]; then
      if [ "${MINOR}000${FIX}" -gt "${CANDIDATE_MINOR}" ]; then
        CANDIDATE_MINOR="${MINOR}000${FIX}"
        CANDIDATE_VERSION_MINOR="${VERSION}"
      else
        continue
      fi
    elif [ "${MINOR}" -eq "${ACTUAL_MINOR}" ]; then
      if [ "${FIX}" -gt "${ACTUAL_FIX}" ]; then
        if [ "${FIX}" -gt "${CANDIDATE_FIX}" ]; then
          CANDIDATE_FIX="${FIX}"
          CANDIDATE_VERSION_FIX="${VERSION}"
        else
          continue
        fi
      else
        continue
      fi
    else
      continue
    fi
  else
    continue
  fi
done

if [ ! -z "${CANDIDATE_VERSION_MAJOR}" ]; then
  APP_VERSION_MAJOR=$(curl -s -X 'GET' "${ARTIFACTUB_PACKAGE}/${CANDIDATE_VERSION_MAJOR}" -H 'accept: application/json' | jq .app_version)  
  echo "major_update:"
  echo "  helm_chart_version: ${CANDIDATE_VERSION_MAJOR}"
  echo "  app_version: ${APP_VERSION_MAJOR//\"}"
fi
if [ ! -z "${CANDIDATE_VERSION_MINOR}" ]; then
  APP_VERSION_MINOR=$(curl -s -X 'GET' "${ARTIFACTUB_PACKAGE}/${CANDIDATE_VERSION_MINOR}" -H 'accept: application/json' | jq .app_version)  
  echo "minor_update:"
  echo "  helm_chart_version: ${CANDIDATE_VERSION_MINOR}"
  echo "  app_version: ${APP_VERSION_MINOR//\"}"
fi
if [ ! -z "${CANDIDATE_VERSION_FIX}" ]; then
    APP_VERSION_FIX=$(curl -s -X 'GET' "${ARTIFACTUB_PACKAGE}/${CANDIDATE_VERSION_FIX}" -H 'accept: application/json' | jq .app_version)
    echo "fix_update:"
    echo "  helm_chart_version: ${CANDIDATE_VERSION_FIX}"
    echo "  app_version : ${APP_VERSION_FIX//\"}"
fi

if [ "" == "${CANDIDATE_VERSION_MAJOR}${CANDIDATE_VERSION_MINOR}${CANDIDATE_VERSION_FIX}" ]; then echo "# Up to date" && exit 0; fi

case $AUTO_LEVEL in
  "major")
    if [ "" != "${CANDIDATE_VERSION_MAJOR}" ]; then
      echo "auto_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_MAJOR}"
      echo "  app_version: ${APP_VERSION_MAJOR//\"}"
    elif [ "" != "${CANDIDATE_VERSION_MINOR}" ]; then
      echo "auto_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_MINOR}"
      echo "  app_version: ${APP_VERSION_MINOR//\"}"
    elif [ "" != "${CANDIDATE_VERSION_FIX}" ]; then
      echo "auto_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_FIX}"
      echo "  app_version : ${APP_VERSION_FIX//\"}"
    else
      echo "# No auto_update"
    fi
  ;;
  "minor")
    if [ "" != "${CANDIDATE_VERSION_MINOR}" ]; then
      echo "auto_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_MINOR}"
      echo "  app_version: ${APP_VERSION_MINOR//\"}"
    elif [ "" != "${CANDIDATE_VERSION_FIX}" ]; then
      echo "auto_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_FIX}"
      echo "  app_version : ${APP_VERSION_FIX//\"}"
    else
      echo "# No auto_update"
    fi
  ;;
  "fix")
    if [ "" == "${CANDIDATE_VERSION_FIX}" ]; then 
      echo "# No auto_update";
    else
      echo "auto_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_FIX}"
      echo "  app_version : ${APP_VERSION_FIX//\"}"
    fi
  ;;
  "dry-run")
    echo "# Dry run, no auto-update, no target-update"
  ;;
  *)
    echo "Unusupported $AUTO_LEVEL, only major / minor / fix are supported."
  ;;
esac

case $TARGET_LEVEL in
  "major")
    if [ "" != "${CANDIDATE_VERSION_MAJOR}" ]; then
      echo "target_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_MAJOR}"
      echo "  app_version: ${APP_VERSION_MAJOR//\"}"
    fi
  ;;
  "minor")
    if [ "" != "${CANDIDATE_VERSION_MINOR}" ]; then
      echo "target_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_MINOR}"
      echo "  app_version: ${APP_VERSION_MINOR//\"}"
    fi
  ;;
  "fix")
    if [ "" != "${CANDIDATE_VERSION_FIX}" ]; then
      echo "target_update:"
      echo "  helm_chart_version: ${CANDIDATE_VERSION_FIX}"
      echo "  app_version: ${APP_VERSION_FIX//\"}"
    fi
  ;;
  "dry-run")
    echo "# Dry run, no auto-update, no target-update"
  ;;
  *)
    echo "Unusupported $AUTO_LEVEL, only major / minor / fix are supported."
  ;;
esac

if [ "${HOOK}" != "" ]; then
  echo "# HOOK : ${HOOK}"
  # shellcheck source=/dev/null
  source "${HOOK}"
fi