#!/bin/bash

if [ $# -ne 2 ] ; then
  echo "Usage: $0 phone password"
  exit 1
fi

PHONE="$1"
PASSWORD="$2"

# Some useful headers to impersonate a browser
# And to avoid Error 406
USERAGENT="Mozilla/5.0 (X11; Linux x86_64; rv:51.0) Gecko/20100101 Firefox/51.0"
KEEPALIVE="Connection: keep-alive"
ACCEPTLANGUAGE="Accept-Language: en-US,en;q=0.5"
ACCEPTENCODING="Accept-Encoding: gzip, deflate, br"
ACCEPTCONTENT="Accept: text/html;q=0.9,*/*;q=0.8"
UPGRADEINSECURE="Upgrade-Insecure-Requests: 1"

# Target URLs
LOGINURL="https://login.mts.ru/amserver/UI/Login?service=lk&amp;goto=http://lk.ssl.mts.ru/"
LOGIN_PLAIN_URL="http://login.mts.ru:80/amserver/UI/Login?service=lk&amp;goto=http://lk.ssl.mts.ru/"

VALIDATEURL="https://login.mts.ru:443/amserver/UI/Login?service=ihelper-sib&amp;goto=https%3A%2F%2Fihelper.sib.mts.ru%3A443%2Fselfcare%2Faccount-status.aspx"
BALANCEURL="https://ihelper.sib.mts.ru/selfcare/account-status.aspx"

LOGINPATH="/amserver/UI/Login?amp%3Bgoto%3Dhttp%3A%2F%2Flk.ssl.mts.ru%2F%26gx_charset%3DUTF-8%26service%3Dlk"

XMLHEAD="<?xml version=\"1.0\" encoding=\"utf-8\"?>"

# Remove the cookie jar and start from scratch
rm -f cookie.txt

# STEP 1: Get the csrf tokens

CSRFSTRING=$( curl -k -v -H "$KEEPALIVE" -H "$ACCEPTLANGUAGE" -H "$ACCEPTENCODING" \
    -H "$UPGRADEINSECURE" -H "$ACCEPTCONTENT" -A "$USERAGENT" \
    -b cookie.txt -c cookie.txt "${LOGIN_PLAIN_URL}" 2>&1 | tee first.html | grep csrf )

CSRFNAMES=( $( echo "${XMLHEAD}<html><body><form>$CSRFSTRING" |\
	xmlstarlet sel -t -v '//form/input/@name' ) )

CSRFVALUES=( $( echo "<?xml version=\"1.0\" encoding=\"utf-8\"?><html><body><form>$CSRFSTRING" |\
	xmlstarlet sel -t -v '//form/input/@value' ) )

declare -A CSRF

CSRF=( ["${CSRFNAMES[0]#csrf.}"]="${CSRFVALUES[0]}" \
            ["${CSRFNAMES[1]#csrf.}"]="${CSRFVALUES[1]}" )

# STEP 2: Get authorization for the current session

curl -k -v -H "$KEEPALIVE" -H "$ACCEPTLANGUAGE" \
    -H "$UPGRADEINSECURE" -H "$ACCEPTCONTENT" -A "$USERAGENT" \
    -b cookie.txt -c cookie.txt "$VALIDATEURL" -d \
    "IDToken2=${PASSWORD}&IDToken1=${PHONE}&IDButton=Submit&loginURL=${LOGINPATH}&csrf.sign="${CSRF[sign]}"&csrf.ts=${CSRF[ts]}" > /dev/null 2>&1 

# STEP 3: Request the balance

BALANCEXML=$( curl -k -v -H "$KEEPALIVE" -H "$ACCEPTLANGUAGE" \
    -H "$UPGRADEINSECURE" -H "$ACCEPTCONTENT" -A "$USERAGENT" \
    -b cookie.txt -c cookie.txt "$BALANCEURL" 2>&1 | grep -A1 "текущий баланс" )

echo "${XMLHEAD}${BALANCEXML}" | xmlstarlet sel -t -v "//th/strong"
echo 

