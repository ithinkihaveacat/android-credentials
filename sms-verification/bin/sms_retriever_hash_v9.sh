#!/usr/bin/env bash

# If any command in the pipelines (see below) fail, the entire pipeline fails.
# This improves robustness in the face of missing commands, unexpected output, 
# etc.
set -o pipefail

KEYSTORE=
PACKAGE=com.google.samples.smartlock.sms_verify
ALIAS=androiddebugkey

while getopts ":p:k:a:" opt; do
  case $opt in
    p)
      PACKAGE=$OPTARG
      ;;
    k)
      KEYSTORE=$OPTARG
      ;;
    a)
      ALIAS=$OPTARG
      ;;
    \?)
      echo "error: invalid option -$OPTARG"
      exit 1
      ;;
  esac
done

if [ -z "$KEYSTORE" ]; then
  echo "error: -k not specified"
  exit 1
fi

if [ ! -r $KEYSTORE ]; then
  echo "error: can't read $KEYSTORE"
  exit 1
fi  

# Generate hash as per algorithm at:
# https://developers.google.com/identity/sms-retriever/verify#computing_your_apps_hash_string

CERT=$(
  keytool -alias $ALIAS -exportcert -keystore $KEYSTORE | xxd -p | tr -d "[:space:]" # 1. "Get your app's public key certificate"
)

if [ $? -ne 0 ]; then
  echo "error: couldn't extract cert from keystore ${KEYSTORE} (maybe alias ${ALIAS} doesn't exist?)"
  exit 1
fi

HASH=$(
  printf "%s %s" ${PACKAGE} ${CERT} | # 2. "Append the hex string to your app's package name, separated by a single space."
  shasum -a 256 |                     # 3. "Compute the SHA-256 sum of the combined string."
  cut -c1-64 | xxd -r -p | base64 |   # 4. "Base64-encode the binary value of the SHA-256 sum."
  cut -c1-11                          # 5. "Your app's hash string is the first 11 characters of the base64-encoded hash."
)

if [ $? -ne 0 ]; then
  echo "error: couldn't generate hash from cert"
  exit 1
fi

echo "Hash string: $HASH"

exit 0

# Debugging
echo "CERT = $CERT"
echo "PACKAGE = $PACKAGE"
echo "KEYSTORE = $KEYSTORE"
echo "ALIAS = $ALIAS"
echo "HASH = $HASH"
