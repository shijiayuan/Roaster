#!/bin/bash

set -xe

if [ ! "$CI_REGISTRY_IMAGE" ]; then
    echo "Please set environment variable CI_REGISTRY_IMAGE to a docker registry."
    exit 1
fi

if [ ! "$LOG_FILE" ]; then
    mkdir -p log
    export LOG_FILE="$(readlink -f "$(date -u '+log/%Y-%m-%d_%H-%M-%S.log')")"
    "$(which time)" -v "$0" 2>&1 | tee "$LOG_FILE"
    exit 0
fi

export BASE_DISTRO=centos

[ "$CI_COMMIT_REF_NAME" ] || export CI_COMMIT_REF_NAME=build-init

for CI_JOB_STAGE in init repo font pkg-{stable,skip} tex ss infra llvm util misc dl ort edit finish; do
    export CI_JOB_STAGE

    [ "$FIRST_STAGE" ] || [ "_$(sed 's/^[^\-]*\-//' <<< "$CI_COMMIT_REF_NAME")" = "_$CI_JOB_STAGE" ] || continue
    [ "$FIRST_STAGE" ] || FIRST_STAGE="$CI_JOB_STAGE"

    case "$CI_JOB_STAGE" in
    finish)
        [ "$PREV_CI_JOB_STAGE" ]
        sudo docker tag "$CI_REGISTRY_IMAGE/$BASE_DISTRO:"{"stage-$PREV_CI_JOB_STAGE",latest}
        sudo docker push "$CI_REGISTRY_IMAGE/$BASE_DISTRO:latest"
        sudo docker rmi "$CI_REGISTRY_IMAGE/$BASE_DISTRO:breakpoint" 2>/dev/null || true
        ;;
    *)
        gitlab-ci/build_stage.sh
        CI_JOB_NAME="push-$CI_JOB_STAGE" gitlab-ci/push_stage.sh &
        ;;
    esac

    PREV_CI_JOB_STAGE="$CI_JOB_STAGE"
done
wait

echo "Image \"$CI_REGISTRY_IMAGE/$BASE_DISTRO\" is ready."
