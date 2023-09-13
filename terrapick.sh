#!/usr/bin/env bash

function showUsage () {
    echo "Usage: $0 <COMMAND> [OPTION]... REGEX..."
    echo ""
    echo "Runs Terraform commands for specific resources only."
    echo ""
    echo "List of available commands"
    echo "  plan                    Run terraform plan."
    echo "  apply                   Run terraform apply."
    echo "  destroy                 Run terraform destroy."
    echo ""
    echo "List of available options"
    echo "  -w WORKING_DIR          Change to WORKING_DIR for command execution."
    echo "  -h                      Show this help and exit."
    echo "  -d                      Enable debug mode."
    echo ""
    echo "Example: $0 plan -w /path/to/files datadog"
    echo ""
}

function parseArguments () {
    if [[ $# == 0 ]]; then
        showUsage; exit 0
    elif [[ $# < 2 ]]; then
        echo "ERROR: Insufficient arguments."; exit 1
    elif ( grep -vwq -- $1 <<< "plan apply destroy" ); then
        echo "ERROR: Unknown command '$1'"; exit 1
    fi

    declare -gr COMMAND=$1; shift

    while getopts "w:hd" opt; do
        case $opt in
            w) declare -gr WORKING_DIR=$(realpath -e "$OPTARG") || exit 1;;
            h) showUsage; exit 0;;
            d) set -o xtrace;;
            ?|*) exit 1;;
        esac
    done; shift $((OPTIND - 1))

    declare -gr REGEX="$@"

    if [[ ! $REGEX ]]; then
        echo "ERROR: No REGEX defined."; exit 1
    fi
}

function getDeploymentTool () {
    if ( ls ${WORKING_DIR:-$PWD} | egrep -q '\.hcl$' ); then
        declare -gr TOOL=$(which terragrunt)
    elif ( ls ${WORKING_DIR:-$PWD} | egrep -q '\.tf$' ); then
        declare -gr TOOL=$(which terraform)
    else
        echo "ERROR: No deployment files found (*.hcl|*.tf)"; exit 1
    fi
}

function runDeployment () {
    pushd ${WORKING_DIR:-$PWD} > /dev/null
    $TOOL state list \
        | sed -n "s/^.*$REGEX.*$/-target='&'/p" \
        | xargs --open-tty $TOOL $COMMAND
    popd > /dev/null
}

function runDeployment_v2 () {
    pushd ${WORKING_DIR:-$PWD} > /dev/null
    $TOOL show \
        | sed -nr "s/^#[[:space:]](.*$REGEX.*):$/-target='\1'/p" \
        | xargs --open-tty $TOOL $COMMAND
    popd > /dev/null
}

set -o pipefail
parseArguments "$@"
getDeploymentTool
runDeployment_v2
