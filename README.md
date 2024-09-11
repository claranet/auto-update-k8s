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
