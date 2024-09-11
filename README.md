# Auto Update K8S

## Overview

A Toolbox written in shell with minimum dependencies to auto update apps in kubernetes cluster managed by a gitops CD (like ArgoCD and FluxCD)

## Getting started

* Build your docker

> make docker-build registry=<your_registry> project_path=<path_to_your_docker> container_tag=<containter_tag>

* Create your config file (config.yaml by default)

```yaml
cert-manager:
  SERVICE: cert-manager
  REPO: cert-manager
  RELEASE_PATH_FILE: kubernetes/services/cert-manager/release.yaml
external-secrets:
  SERVICE: external-secrets
  REPO: external-secrets-operator
  RELEASE_PATH_FILE: kubernetes/services/external-secrets/release.yaml
traefik:
  SERVICE: traefik
  REPO: traefik
  RELEASE_PATH_FILE: kubernetes/services/external-secrets/release.yaml
```

* Add it in your Gitlab CI

```yaml
default:
  image: 
    name: <registry>/<container>:<tag>
    entrypoint:
      - /usr/bin/env
      - PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

variables:
  GIT_CONFIG_USER_EMAIL: gitlab-runner@localhost
  GIT_CONFIG_USER_NAME: Gitlab Runner
  AUTO_UPDATE_BOT: auto-merge
  TARGET_BRANCH: main
  CLUSTER_NAME: test
  ENV: dev
  # Protect these variables
  ASSIGNEE: <assignee>
  AUTO_UPDATE_TOKEN: <token>
  SLACK_HOOK_URL: <url>

stages:
  - generate-auto-update-ci
  - run-auto-update-ci

#### AUTO_UPDATE ####
generate_auto_update_ci:
  stage: generate-auto-update-ci
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
    - if: '$CI_PIPELINE_SOURCE == "web" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
  variables:
    CONFIG_CI_FILE: config.yaml
    GENERATED_CI_PATH: generated-ci.yaml
  script: 
    - /auto-update/scripts/generate-ci.sh
  artifacts:
    expire_in: 1 hour
    paths:
      - generated-ci.yaml

run_auto_update_ci:
  stage: run-auto-update-ci
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
    - if: '$CI_PIPELINE_SOURCE == "web" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
  needs:
    - generate_auto_update_ci
  trigger:
    include:
      - artifact: generated-ci.yaml
        job: generate_auto_update_ci
    strategy: depend
```

## Dig deeper

### Checking versions

By default, auto-update-k8s checks only the last 10 versions published on artifacthub. To increase this value, please add this global variable:

```yaml
variables:
  NB_CHECK_VERSION: 30
```

### Split auto-update-k8s

In a case, it can be interesting to split the auto-update-k8s in several jobs (split by environment, criticity, etc..). To do it, just use the variable CONFIG_CI_FILE to specify a different config for each job, the variable GENERATED_CI_PATH to generate the CI in a different file for each job and the variable RUN_STAGE to specify the stage used by the generated CI. See this example below:

```yaml
#### AUTO_UPDATE ####
generate_auto_update_ci_prod:
  stage: generate-auto-update-ci
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "prod"'
    - if: '$CI_PIPELINE_SOURCE == "web" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "prod"'
  variables:
    CONFIG_CI_FILE: config-prod.yml
    GENERATED_CI_PATH: generated-ci-prod.yml
  script: 
    - /auto-update/scripts/generate-ci.sh
  artifacts:
    expire_in: 1 hour
    paths:
      - generated-ci-prod.yml

run_auto_update_ci_prod:
  stage: run-auto-update-ci
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "prod"'
    - if: '$CI_PIPELINE_SOURCE == "web" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "prod"'
  needs:
    - generate_auto_update_ci_prod
  trigger:
    include:
      - artifact: generated-ci-prod.yml
        job: generate_auto_update_ci_prod
    strategy: depend

#### AUTO_UPDATE ####
generate_auto_update_ci_preprod:
  stage: generate-auto-update-ci
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "preprod"'
    - if: '$CI_PIPELINE_SOURCE == "web" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "preprod"'
  variables:
    CONFIG_CI_FILE: config-preprod.yml
    GENERATED_CI_PATH: generated-ci-preprod.yml
  script: 
    - /auto-update/scripts/generate-ci.sh
  artifacts:
    expire_in: 1 hour
    paths:
      - generated-ci-preprod.yml

run_auto_update_ci_preprod:
  stage: run-auto-update-ci
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "preprod"'
    - if: '$CI_PIPELINE_SOURCE == "web" && $BRANCH_UPDATE == null && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $ENV == "preprod"'
  needs:
    - generate_auto_update_ci_preprod
  trigger:
    include:
      - artifact: generated-ci-preprod.yml
        job: generate_auto_update_ci_preprod
    strategy: depend
```

To be scheduled by different pipeline, we added a condition in the rules by using the variable ENV to specify which pipeline to start.

### Override configuration

Some parameters are overridables in the configuration file, like:

* VERSION_PATH: By default, it's based on the HelmRelease format (FluxCD) and used this path to change (and check) the version : "spec.chart.spec.version".
* SUFFIX: Empty by default. Add a suffix in case of there are many instances of the same app install on the cluster.
* AUTO_LEVEL: By default, the same as the global variables (minor). To change the auto level update for a specific app.
* CHECK_HOOK: Not used by default. Add a hook at the check step. This the hook section below.
* AUTO_HOOK: Not used by default. Add a hook at the auto update step. This the hook section below.
* TARGET_HOOK: Not used by default. Add a hook at the target step. This the hook section below.

### Hook (experimental)

Can be used to add some actions in a step, use it with precautions.

#### Update another field in HelmRelease

For example, we want to change at the same time the image tag used by the HelmRelease. We added this variable:

```yaml
  AUTO_HOOK: .auto-update/runner/update-image-tag.sh
```

And create the hook file with the path specified (.auto-update/runner/update-image-tag.sh):

```shell
hook(){
  yq -i ".spec.values.image.tag = \"alpine-v$IMAGE_VERSION\"" "${RELEASE_PATH_FILE}"
}
hook
```
