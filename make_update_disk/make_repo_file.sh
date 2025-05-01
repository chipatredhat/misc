#!/bin/sh

# This is the name of the repo file to create
CDREPONAME=cd.repo

# Get the location of the directory this is running from
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Use the directory this is running from unless a different directory is passed as ${1}
if [ -z ${1} ] ; then MYMNT=${SCRIPT_DIR} ; else MYMNT=${1} ; fi

# Display the file that will get created as ${CDREPONAME} and confirm it is ok to write it out
echo -e "\nDo you wish to create the following as /etc/yum.repos.d/${CDREPONAME}?"
sed -n '/name = Red Hat Enterprise Linux 8 for x86_64 - BaseOS (RPMs)/,/^$/p' /etc/yum.repos.d/redhat.repo | sed "s|https.*$|file:\/\/${MYMNT}|"

# Get only the first letter of the response, and capitalize it
read -p "(Y/N)? " READIN
READONE=${READIN:0:1}

# Write the file if confirmed, exit without writing if not
if [ "${READONE^}" = "Y" ] ; then
sed -n '/name = Red Hat Enterprise Linux 8 for x86_64 - BaseOS (RPMs)/,/^$/p' /etc/yum.repos.d/redhat.repo | sed "s|https.*$|file:\/\/${MYMNT}|" > /etc/yum.repos.d/${CDREPONAME} 
echo -e "\nOK, /etc/yum.repos.d/${CDREPONAME} created\n"
else
echo -e "\nOk, nothing has been written\n"
fi
