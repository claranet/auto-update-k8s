CONFIG_CI_FILE="${CONFIG_CI_FILE:="config.yml"}"
GENERATED_CI_PATH="${GENERATED_CI_PATH:="generated-ci.yml"}"
ROOT_CI_FILE="${ROOT_CI_FILE:=".gitlab-ci.yml"}"

rm -f "${GENERATED_CI_PATH}"

INCLUDES="""
include:
  - remote: 'https://raw.githubusercontent.com/claranet/auto-update-k8s/main/auto-update/gitlab-ci/.init.yml'
  - remote: 'https://raw.githubusercontent.com/claranet/auto-update-k8s/main/auto-update/gitlab-ci/.auto-update.yml'
"""

STAGES="""
stages:
  - check-version
  - auto-update
  - target-update
  - intermediate-update
"""

DEFAULTS="""
$(yq e 'with_entries(select(.key | test("default")))' ${ROOT_CI_FILE})
"""

VARIABLES="""
$(yq e 'with_entries(select(.key | test("variables")))' ${ROOT_CI_FILE})
"""

echo "${INCLUDES}${STAGES}${DEFAULTS}${VARIABLES}" >> "${GENERATED_CI_PATH}"

for service in $(yq e '.[] | path | .[]' "${CONFIG_CI_FILE}"); do
  SERVICE=$(yq e ".${service}.SERVICE" "${CONFIG_CI_FILE}")
  REPO=$(yq e ".${service}.REPO" "${CONFIG_CI_FILE}")
  RELEASE_PATH_FILE=$(yq e ".${service}.RELEASE_PATH_FILE" "${CONFIG_CI_FILE}")
  EXTRA_PARAM_CHECK=""
  EXTRA_PARAM_AUTO=""
  EXTRA_PARAM_TARGET=""

  AUTO_LEVEL=$(yq e ".${service}.AUTO_LEVEL" "${CONFIG_CI_FILE}")
  if [ "${AUTO_LEVEL}" != "null" ]; then 
    EXTRA_PARAM_CHECK="""${EXTRA_PARAM_CHECK}
    AUTO_LEVEL: ${AUTO_LEVEL}"""
  fi

  CHECK_HOOK=$(yq e ".${service}.CHECK_HOOK" "${CONFIG_CI_FILE}")
  if [ "${CHECK_HOOK}" != "null" ]; then 
    EXTRA_PARAM_CHECK="""${EXTRA_PARAM_CHECK}
    HOOK: ${CHECK_HOOK}"""
  fi

  AUTO_HOOK=$(yq e ".${service}.AUTO_HOOK" "${CONFIG_CI_FILE}")
  if [ "${AUTO_HOOK}" != "null" ]; then 
    EXTRA_PARAM_AUTO="""${EXTRA_PARAM_AUTO}
    HOOK: ${AUTO_HOOK}"""
  fi

  TARGET_HOOK=$(yq e ".${service}.TARGET_HOOK" "${CONFIG_CI_FILE}")
  if [ "${TARGET_HOOK}" != "null" ]; then 
    EXTRA_PARAM_TARGET="""${EXTRA_PARAM_TARGET}
    HOOK: ${TARGET_HOOK}"""
  fi

  SUFFIX=$(yq e ".${service}.SUFFIX" "${CONFIG_CI_FILE}")
  if [ "${SUFFIX}" != "null" ]; then 
    EXTRA_PARAM_AUTO="""${EXTRA_PARAM_AUTO}
    SUFFIX: ${SUFFIX}"""
  fi
  if [ "${SUFFIX}" != "null" ]; then 
    EXTRA_PARAM_TARGET="""${EXTRA_PARAM_TARGET}
    SUFFIX: ${SUFFIX}"""
  fi

  EXTRA_TARGET_STEP=$(yq e ".${service}.EXTRA_TARGET_STEP" "${CONFIG_CI_FILE}")

  CHECK_VERSION="""
Check version $service:
  extends: .check_version
  variables:
    SERVICE: ${SERVICE}
    REPO: ${REPO}
    RELEASE_PATH_FILE: ${RELEASE_PATH_FILE}${EXTRA_PARAM_CHECK}
"""

  AUTO_UPDATE="""
Auto update $service:
  extends: .auto_update
  variables:
    SERVICE: ${SERVICE}
    RELEASE_PATH_FILE: ${RELEASE_PATH_FILE}${EXTRA_PARAM_AUTO}
"""

  if [ "${AUTO_LEVEL}" == "fix" ]; then
    TARGET_UPDATE="""
Target update $service (minor):
  extends: .minor_update
  variables:
    SERVICE: ${SERVICE}
    RELEASE_PATH_FILE: ${RELEASE_PATH_FILE}${EXTRA_PARAM_TARGET}

Target update $service (major):
  extends: .major_update
  needs: ['Target update $service (minor)']
  variables:
    SERVICE: ${SERVICE}
    RELEASE_PATH_FILE: ${RELEASE_PATH_FILE}${EXTRA_PARAM_TARGET}
"""
  elif [ "${AUTO_LEVEL}" == "major" ]; then
    TARGET_UPDATE=""
  else
    TARGET_UPDATE="""
Target update $service:
  extends: .major_update
  variables:
    SERVICE: ${SERVICE}
    RELEASE_PATH_FILE: ${RELEASE_PATH_FILE}${EXTRA_PARAM_TARGET}
"""
  fi

  if [ "${EXTRA_TARGET_STEP}" != "null" ]; then
    if [ "${SUFFIX}" == "null" ]; then 
      EXTRA_PARAM_TARGET="""${EXTRA_PARAM_TARGET}
    SUFFIX: -BC"""
    else
      EXTRA_PARAM_TARGET=${EXTRA_PARAM_TARGET/"SUFFIX: ${SUFFIX}"/"SUFFIX: -BC${SUFFIX}"}
    fi

    EXTRA_TARGET_UPDATE="""
Intermediate update $service:
  extends: .${EXTRA_TARGET_STEP}
  variables:
    SERVICE: ${SERVICE}
    RELEASE_PATH_FILE: ${RELEASE_PATH_FILE}${EXTRA_PARAM_TARGET}
"""
  fi

  echo "${CHECK_VERSION}${AUTO_UPDATE}${TARGET_UPDATE}${EXTRA_TARGET_UPDATE}" >> "${GENERATED_CI_PATH}"
done
