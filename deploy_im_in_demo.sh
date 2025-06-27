#!/bin/bash
# This script should only be used without modification to deploy the Image Mode Workshop from https://github.com/chipatredhat/ImageModeWorkshop in the Red Hat demo environment
# You can execute this with: "curl -s https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/deploy_im_in_demo.sh | bash -s --"

API_TOKEN=$(cat ~/.secrets/.api_token)
REGISTRY_TOKEN=$(cat ~/.secrets/.registry_token)
REGISTRY_ACCOUNT=$(cat ~/.secrets/.registry_account)

[ "$2" = "" ] && printf "\n\nUsage: %s <username@hostname> <ssh_port> \nExample: $0 lab-user@ssh.ocpv999.demo.net 30124\n\n" "$0" && exit

# Verify the token is current:
token=$(curl https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token -d grant_type=refresh_token -d client_id=rhsm-api -d refresh_token=$API_TOKEN | jq --raw-output .access_token)
[[ "${token}" = "null" ]] && echo "Your token is not valid.  Please update your token at https://access.redhat.com/management/api and ensure it is stored in ~/.secrets/.api_token" && exit
[[ "${REGISTRY_TOKEN}" = "" ]] && echo "Your registry token is not available.  Please ensure it is stored at ~/.secrets/.registry_token. It may be created at https://access.redhat.com/terms-based-registry" && exit
[[ "${REGISTRY_ACCOUNT}" = "" ]] && echo "Your registry account is not available.  Please ensure it is stored at ~/.secrets/.registry_account. It may be created at https://access.redhat.com/terms-based-registry" && exit

ssh-copy-id -oStrictHostKeyChecking=no -p $2 $1

ssh -p $2 -t $1 "curl -s https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/demo_make_disk.sh >/tmp/make_demo_disk.sh"

ssh -p $2 -t $1 'bash /tmp/make_demo_disk.sh'

ssh -p $2 -t $1 "curl -s https://raw.githubusercontent.com/chipatredhat/ImageModeWorkshop/refs/heads/main/prep.sh | bash -s -- '${API_TOKEN}' '${REGISTRY_ACCOUNT}' '${REGISTRY_TOKEN}' ; bash"
