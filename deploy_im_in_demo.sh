#!/bin/bash
# This script should only be used without modification to deploy the Image Mode Workshop from https://github.com/chipatredhat/ImageModeWorkshop in the Red Hat demo environment
# You can execute this with: "curl -o https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/deploy_im_in_demo.sh && bash ./deploy_im_in_demo.sh"

[ "$2" = "" ] && printf "\n\nUsage: %s <username@hostname> <ssh_port> \nExample: $0 lab-user@ssh.ocpv999.demo.net 30124\n\n" "$0" && exit

# Location where you store your secrets for this script:
API_TOKEN_FILE=~/.secrets/.api_token
REGISTRY_TOKEN_FILE=~/.secrets/.registry_token
REGISTRY_ACCOUNT_FILE=~/.secrets/.registry_account

# Verify the secrets files defined above exist:
[[ -f ${API_TOKEN_FILE} ]] || echo "Your api token file is not available.  Please ensure it is stored at ${API_TOKEN_FILE}. It may be created at https://access.redhat.com/management/api" || exit
[[ -f ${REGISTRY_TOKEN_FILE} ]] && echo "Your registry token file is not available.  Please ensure it is stored at ${REGISTRY_TOKEN_FILE}. It may be created at https://access.redhat.com/terms-based-registry" || exit
[[ -f ${REGISTRY_ACCOUNT_FILE} ]] && echo "Your registry account file is not available.  Please ensure it is stored at ${REGISTRY_ACCOUNT_FILE}. It may be created at https://access.redhat.com/terms-based-registry" || exit

# Set the variables from the secrets files
API_TOKEN=$(cat ${API_TOKEN_FILE})
REGISTRY_TOKEN=$(cat ${REGISTRY_TOKEN_FILE})
REGISTRY_ACCOUNT=$(cat ${REGISTRY_ACCOUNT_FILE})


# Verify the token is current:
token=$(curl https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token -d grant_type=refresh_token -d client_id=rhsm-api -d refresh_token=$API_TOKEN | jq --raw-output .access_token)
[[ "${token}" = "null" ]] && echo "Your token is not valid.  Please update your token at https://access.redhat.com/management/api and ensure it is stored in ~/.secrets/.api_token" && exit
[[ "${REGISTRY_TOKEN}" = "" ]] && echo "Your registry token is not available.  Please ensure it is stored at ~/.secrets/.registry_token. It may be created at https://access.redhat.com/terms-based-registry" && exit
[[ "${REGISTRY_ACCOUNT}" = "" ]] && echo "Your registry account is not available.  Please ensure it is stored at ~/.secrets/.registry_account. It may be created at https://access.redhat.com/terms-based-registry" && exit

# This just makes the connection without asking to confirm the ssh key.  THIS IS INSECURE and should never be used outside of a transient demo environment such as this.
ssh-copy-id -oStrictHostKeyChecking=no -p $2 $1

# The demo environment has a blank disk that we use for the images we create:
ssh -p $2 -t $1 "curl -s https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/demo_make_disk.sh >/tmp/make_demo_disk.sh"
ssh -p $2 -t $1 'bash /tmp/make_demo_disk.sh'

# Now connect again, download and run the workshop using the varibles needed to build it out:
ssh -p $2 -t $1 "curl -s https://raw.githubusercontent.com/chipatredhat/ImageModeWorkshop/refs/heads/main/prep.sh | bash -s -- '${API_TOKEN}' '${REGISTRY_ACCOUNT}' '${REGISTRY_TOKEN}' ; bash"
