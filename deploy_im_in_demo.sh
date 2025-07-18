#!/bin/bash
# This script should only be used without modification to deploy the Image Mode Workshop from https://github.com/chipatredhat/ImageModeWorkshop in the Red Hat demo environment utilizing a baremetal server from:
# https://catalog.demo.redhat.com/catalog?search=baremetal
# ALL OTHER USES SHOULD MODIFY THIS SCRIPT AS NECESSARY
# You can use the "small" deployment size for the demo
# Once you have the deployment created you can build it out by:
# Download this script to your preferred location and make it executeable with: 
# curl -sO https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/deploy_im_in_demo.sh && chmod +x deploy_im_in_demo.sh
# Now simply run this script to deploy the ImageModeWorkshop into the demo enironment with ./deploy_im_in_demo.sh
### NOTE:  This script will self update if there are updates, so once it is deployed, you shouldn't ever have to check for later versions, just run it

VERSION=2025071801

# Display help if requested:
[[ "${1}" = "-h" ]] || [[ "${1}" = "--help" ]] && printf "\n\nUsage: %s <username@hostname> <ssh_port> \nExample: $0 lab-user@ssh.ocpv999.demo.net 30124\n\n" "$0" && exit

# Check if this is the latest version and update if not:
GITVER=$(curl -s https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/deploy_im_in_demo.sh | grep VERSION | head -1 | cut -d = -f 2)
if test ${GITVER} -gt ${VERSION} ; then
    sudo rm -f $0
    sudo curl -s https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/deploy_im_in_demo.sh > $0
    sudo chmod +x $0
    echo -e "\n\nThis script has been updated and is relaunching\n\n"
    exec bash "$0" "$@" # Have script restart after updating
    exit  # Just a failsafe in case the update goes awry
fi

###### Check to see if the files to deploy exist and write them if not:

# Location where you store your secrets for this script:
SECRETS_DIRECTORY=~/.secrets
API_TOKEN_FILE=${SECRETS_DIRECTORY}/.api_token
REGISTRY_TOKEN_FILE=${SECRETS_DIRECTORY}/.registry_token
REGISTRY_ACCOUNT_FILE=${SECRETS_DIRECTORY}/.registry_account

# Get the API Token if ${API_TOKEN_FILE} doesn't exist:
if [ ! -f ${API_TOKEN_FILE} ] ; then
    echo -e "\n\nYour API Token isn't stored in ${API_TOKEN_FILE}.  If you do not currently have one, you can create one at https://access.redhat.com/management/api"
    read -p "What is your API Token? " API_TOKEN
    echo -e "\n"
    read -n1 -p "Would you like to save your API Token to ${API_TOKEN_FILE} to allow deployments to automatically build? (Y/N) " SAVE_API_TOKEN
    if [ "${SAVE_API_TOKEN}" = "Y" ] || [ "${SAVE_API_TOKEN}" = "y" ] ; then
        [[ -d ${SECRETS_DIRECTORY} ]] || mkdir ${SECRETS_DIRECTORY}
        echo ${API_TOKEN} > ${API_TOKEN_FILE}
        echo -e "\n"
    fi
else
    API_TOKEN=$(cat ${API_TOKEN_FILE})
fi

# Get the Registry Token if {REGISTRY_TOKEN_FILE} doesn't exist:
if [ ! -f ${REGISTRY_TOKEN_FILE} ] ; then
    echo -e "\n\nYour Registry Token isn't stored in ${REGISTRY_TOKEN_FILE}.  If you do not currently have one, you can create one at https://access.redhat.com/terms-based-registry"
    read -p "What is your Registry Token? " REGISTRY_TOKEN
    echo -e "\n"
    read -n1 -p "Would you like to save your Registry Token to ${REGISTRY_TOKEN_FILE} to allow deployments to automatically build? (Y/N) " SAVE_REGISTRY_TOKEN
    if [ "${SAVE_REGISTRY_TOKEN}" = "Y" ] || [ "${SAVE_REGISTRY_TOKEN}" = "y" ] ; then
        [[ -d ${SECRETS_DIRECTORY} ]] || mkdir ${SECRETS_DIRECTORY}
        echo ${REGISTRY_TOKEN} > ${REGISTRY_TOKEN_FILE}
        echo -e "\n"
    fi
else
    REGISTRY_TOKEN=$(cat ${REGISTRY_TOKEN_FILE})
fi

# Get the Registry Account Name if {REGISTRY_ACCOUNT_FILE} doesn't exist:
if [ ! -f ${REGISTRY_ACCOUNT_FILE} ] ; then
    echo -e "\n\nYour Registry Account file isn't stored in ${REGISTRY_ACCOUNT_FILE}.  If you do not currently have one, you can create one at https://access.redhat.com/terms-based-registry"
    read -p "What is your Registry Account Name? " REGISTRY_ACCOUNT
    echo -e "\n"
    read -n1 -p "Would you like to save your Registry Account Name to ${REGISTRY_ACCOUNT_FILE} to allow deployments to automatically build? (Y/N) " SAVE_REGISTRY_ACCOUNT
    if [ "${SAVE_REGISTRY_ACCOUNT}" = "Y" ] || [ "${SAVE_REGISTRY_ACCOUNT}" = "y" ] ; then
        [[ -d ${SECRETS_DIRECTORY} ]] || mkdir ${SECRETS_DIRECTORY}
        echo ${REGISTRY_ACCOUNT} > ${REGISTRY_ACCOUNT_FILE}
        echo -e "\n"
    fi
else
REGISTRY_ACCOUNT=$(cat ${REGISTRY_ACCOUNT_FILE})
fi

# Verify the token is current:
token=$(curl -s https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token -d grant_type=refresh_token -d client_id=rhsm-api -d refresh_token=$API_TOKEN | jq --raw-output .access_token)
if [ "${token}" = "null" ] ; then
    echo "Your API Token is not valid.  Please create an updated token at https://access.redhat.com/management/api"
    rm -f ${API_TOKEN_FILE} # Delete the token file since it's no longer valid
    read -p "Press any key to restart this script and enter a new API Token" -n1 -s
    exec bash "$0" "$@" # Have script restart after updating
fi

##### Start the deployment
[[ -z $1 ]] && read -p "What is the hostname of the demo server.  EX: ssh.opcv00.rhdp.net? " CNVHOST || CNVHOST=${1}
[[ -z $2 ]] && read -p "What port is used for ssh? " CNVPORT || CNVPORT=${2}

# This just makes the connection without asking to confirm the ssh key.  THIS IS INSECURE and should never be used outside of a transient demo environment such as this.
ssh-copy-id -oStrictHostKeyChecking=no -p ${CNVPORT} lab-user@${CNVHOST}

# The demo environment has a blank disk that we use for the images we create:
ssh -p ${CNVPORT} -t lab-user@${CNVHOST} "curl -s https://raw.githubusercontent.com/chipatredhat/misc/refs/heads/main/demo_make_disk.sh >/tmp/make_demo_disk.sh"
ssh -p ${CNVPORT} -t lab-user@${CNVHOST} 'bash /tmp/make_demo_disk.sh'

# Now connect again, download and run the workshop using the varibles needed to build it out:
ssh -p ${CNVPORT} -t lab-user@${CNVHOST} "curl -s https://raw.githubusercontent.com/chipatredhat/ImageModeWorkshop/refs/heads/main/prep.sh | bash -s -- '${API_TOKEN}' '${REGISTRY_ACCOUNT}' '${REGISTRY_TOKEN}' ; bash"
