#!/bin/bash

#set -exuo pipefail
set -euo pipefail

green=$(tput setaf 2)
cyan=$(tput setaf 6)
normal=$(tput sgr0)

CONJUR_SERVER_DNS=dapmaster.conjur.dev
conjur_host=azure-apps
secret_id=test-variable

function main() {

    system_assigned_identity_token_endpoint="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F"
    system_assigned_identity_host_name="az-tools"

    # use Azure system-assigned-identity to get Conjur access token
    getConjurTokenWithAzureIdentity $system_assigned_identity_token_endpoint $system_assigned_identity_host_name

    getConjurSecret $conjur_access_token
}

function getConjurTokenWithAzureIdentity() {
    azure_token_endpoint="$1"
    conjur_role="$2"

    getAzureAccessToken $azure_token_endpoint $conjur_role

    getConjurToken $azure_access_token
}

function getAzureAccessToken(){
    printf "\n\n%40s" "${normal}Retrieving Azure access token from $azure_token_endpoint..."

    # Get an Azure access token
    azure_access_token=$(curl -s\
      "$azure_token_endpoint" \
      -H Metadata:true -s | jq -r '.access_token')

    printf "\n%40s\n\n" "${cyan}$azure_access_token${normal}"
}

function getConjurToken() {
    # Get a Conjur access token for host azure-apps/system-assigned-identity-app or user-assigned-identity-app using the Azure token details
    printf "\n%s%s%s\n" "${normal}Get Conjur access token for " "${cyan}$conjur_role " "${normal}using its Azure access token..."

    authn_azure_response=$(curl -sk -X POST \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data "jwt=$azure_access_token" \
      https://dapmaster.conjur.dev:443/authn-azure/dev/cyberark/host%2F$conjur_host/authenticate)

    conjur_access_token=$(echo -n "$authn_azure_response" | base64 | tr -d '\r\n')

    printf "%s\n\n" "${cyan}$conjur_access_token"
}

function getConjurSecret(){
    printf "%s\n" "${normal}Retrieve a secret using the Conjur access token..."

    # Retrieve a Conjur secret using the authn-azure Conjur access token
    secret=$(curl -sk -H "Authorization: Token token=\"$conjur_access_token\"" \
      "https://dapmaster.conjur.dev:443/secrets/cyberark/variable/$secret_id")

    printf "%s%s%s\n\n" "${normal}Retrieved secret " "${green}${secret} " "${normal}from Conjur."
}

main