#!/bin/bash

# Magento 2 Bash Install Script
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# @copyright Copyright (c) 2015 by Yaroslav Voronoy (y.voronoy@gmail.com)
# @license   http://www.gnu.org/licenses/

VERBOSE=1
CURRENT_DIR_NAME=$(basename $(pwd))
HTTP_HOST=http://mage2.dev/
BASE_PATH=${CURRENT_DIR_NAME}
BASE_URL=${HTTP_HOST}${BASE_PATH}/
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=
DB_NAME=
USE_SAMPLE_DATA=
MAGENTO_EE_PATH=
CONFIG_NAME=.m2install.conf
USE_WIZARD=1

function printVersion()
{
    echo "0.1.2-beta"
}

function askValue()
{
    MESSAGE=$1
    READ_DEFAULT_VALUE=$2
    READVALUE=
    if [ "${READ_DEFAULT_VALUE}" ]
    then
        MESSAGE="${MESSAGE} (default: ${READ_DEFAULT_VALUE})"
    fi
    MESSAGE="${MESSAGE}: "
    read -r -p "$MESSAGE" READVALUE
    if [ -z "${READVALUE}" ] && [ "${READ_DEFAULT_VALUE}" ]
    then
        READVALUE=${READ_DEFAULT_VALUE}
    fi
}

askConfirmation() {
    if [ "$1" ]
    then
        echo -n $1
    else
        echo -n "Are you sure (Y/N)? "
    fi
    while read -r -n 1 -s answer; do
        if [[ $answer = [YyNn] ]]; then
            [[ $answer = [Yy] ]] && retval=0
            [[ $answer = [Nn] ]] && retval=1
            break
        fi
    done
    echo ""
    return $retval
}

function printLine()
{
    printf '%50s\n' | tr ' ' -
}

function runCommand()
{
    if [[ "$VERBOSE" -eq 1 ]]
    then
        echo $CMD;
    fi

    eval $CMD;
}

function extract()
{
     if [ -f $EXTRACT_FILENAME ] ; then
         case $EXTRACT_FILENAME in
             *.tar.bz2)   tar xjf $EXTRACT_FILENAME;;
             *.tar.gz)    gunzip -c $EXTRACT_FILENAME | gunzip -cf | tar -x ;;
             *.gz)        gunzip $EXTRACT_FILENAME;;
             *.tbz2)      tar xjf $EXTRACT_FILENAME;;
             *)           echo "'$EXTRACT_FILENAME' cannot be extracted";;
         esac
     else
         echo "'$EXTRACT_FILENAME' is not a valid file"
     fi
}

function mysqlQuery()
{
    SQLQUERY_RESULT=$(mysql -h$DB_HOST -u${DB_USER} --password=${DB_PASSWORD} --execute="${SQLQUERY}" 2>/dev/null);
}

function generateDBName()
{
    DB_NAME=${DB_USER}_$(echo "$BASE_PATH" | sed "s/\//_/g" | sed "s/[^a-zA-Z0-9_]//g" | tr '[A-Z]' '[a-z]');
}

function wizard()
{
    askValue "Enter Server Name of Document Root" ${HTTP_HOST}
    HTTP_HOST=${READVALUE}
    askValue "Enter Base Path" ${BASE_PATH}
    BASE_PATH=${READVALUE}
    BASE_PATH=$(echo ${BASE_PATH} | sed "s/^\///g" | sed "s/\/$//g" );
    askValue "Enter DB Host" ${DB_HOST}
    DB_HOST=${READVALUE}
    askValue "Enter DB User" ${DB_USER}
    DB_USER=${READVALUE}
    askValue "Enter DB Password" ${DB_PASSWORD}
    DB_PASSWORD=${READVALUE}
    generateDBName
    askValue "Enter DB Name" ${DB_NAME}
    DB_NAME=${READVALUE}
    askValue "Install Sample Data"
    USE_SAMPLE_DATA=${READVALUE}
    askValue "Enter Absoulute Path to Enterprise Edition"
    MAGENTO_EE_PATH=${READVALUE}
}

function printConfirmation()
{
    BASE_URL=${HTTP_HOST}${BASE_PATH}/
    echo "BASE URL: ${BASE_URL}"
    echo "DB PARAM: ${DB_USER}@${DB_HOST}"
    echo "DB NAME: ${DB_NAME}"
    if [ "${USE_SAMPLE_DATA}" ]
    then
        echo "Sample Data will be installed"
    fi
    if [ "${MAGENTO_EE_PATH}" ]
    then
        echo "Magento EE will be installed"
        echo "Magento EE Path: ${MAGENTO_EE_PATH}"
    fi
}

function showWizard()
{
    I=1;
    while [ "$I" -eq 1 ]
    do
        if [ "$USE_WIZARD" -eq 1 ]
        then
            wizard
        fi
        printConfirmation
        if askConfirmation
        then
            I=0
        else
            USE_WIZARD=1
        fi
    done
}

function loadConfigFile()
{
    NEAREST_CONFIG_FILE=`(find \`pwd\` -maxdepth 1 -name $CONFIG_NAME ;\
        x=\`pwd\`;\
        while [ "$x" != "/" ] ;\
        do x=\`dirname "$x"\`;\
            find "$x" -maxdepth 1 -name $CONFIG_NAME;\
        done) | tail -r`
    if [ "$NEAREST_CONFIG_FILE" ]
    then
        echo "Configuration loaded from:"
        for FILE in $NEAREST_CONFIG_FILE
        do
            CMD="source $FILE"
            runCommand
        done
        USE_WIZARD=0
    fi
}

function promptSaveConfig()
{
    if [ "$NEAREST_CONFIG_FILE" ]
    then
        return;
    fi
    if askConfirmation "Do you want save config to ~/$CONFIG_NAME (Y/N)"
    then
        cat << EOF > ~/$CONFIG_NAME
HTTP_HOST=$HTTP_HOST
BASE_PATH=$BASE_PATH
DB_HOST=$DB_HOST
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF
        echo "Config file has been created in ~/$CONFIG_NAME";
    fi
}

function dropDB()
{
    CMD="mysqladmin -h${DB_HOST} -u${DB_USER}"
    if [ "${DB_PASSWORD}" ]
    then
        CMD="${CMD} -p${DB_PASSWORD}"
    fi
    CMD="${CMD} -f drop ${DB_NAME}"
    runCommand
}

function createNewDB()
{
    CMD="mysqladmin -h${DB_HOST} -u${DB_USER}"
    if [ "${DB_PASSWORD}" ]
    then
        CMD="${CMD} -p${DB_PASSWORD}"
    fi
    CMD="${CMD} -f create ${DB_NAME}"

    runCommand
}

function getCodeDumpFilename()
{
    FILENAME_CODE_DUMP=$(ls -1 *.tbz2 *.tar.bz2 2> /dev/null | head -n1)
    if [ "${FILENAME_CODE_DUMP}" == "" ]
    then
        FILENAME_CODE_DUMP=$(ls -1 *.tar.gz 2> /dev/null | grep -v 'logs.tar.gz' | head -n1)
    fi
}

function getDbDumpFilename()
{
    FILENAME_DB_DUMP=$(ls -1 *.sql.gz 2> /dev/null | head -n1)
}

function foundSupportBackupFiles()
{
    getCodeDumpFilename
    if [ ! -f "$FILENAME_CODE_DUMP" ]
    then
        return 1;
    fi

    getDbDumpFilename
    if [ ! -f "$FILENAME_DB_DUMP" ]
    then
        return 1;
    fi

    return 0;
}

function restoreDB()
{
    echo "Please wait DB dump starts restore"

    getDbDumpFilename

    if which pv > /dev/null
    then
        CMD="pv ${FILENAME_DB_DUMP} | gunzip -c | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h$DB_HOST -u$DB_USER --password=$DB_PASSWORD --force $DB_NAME";
        runCommand;
    else
        CMD="gunzip -c $FILENAME_DB_DUMP | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h$DB_HOST -u$DB_USER --password=$DB_PASSWORD --force $DB_NAME"
        runCommand;
    fi
}

function extractCode()
{
    echo -n "Please wait Code dump start extract - "
    getCodeDumpFilename

    EXTRACT_FILENAME=$FILENAME_CODE_DUMP
    extract

    mkdir -p var pub/media
    echo "OK"
}

function updateBaseUrl()
{
    SQLQUERY="UPDATE ${DB_NAME}.core_config_data AS e SET e.value = '${BASE_URL}' WHERE e.path IN ('web/secure/base_url', 'web/unsecure/base_url')"
    mysqlQuery
}

function updateMagentoEnvFile()
{
    cp app/etc/env.php app/etc/env.php.merchant
    cat << EOF > app/etc/env.php
<?php
return array (
  'backend' =>
  array (
    'frontName' => 'admin',
  ),
  'queue' =>
  array (
    'amqp' =>
    array (
      'host' => '',
      'port' => '',
      'user' => '',
      'password' => '',
      'virtualhost' => '/',
      'ssl' => '',
    ),
  ),
  'db' =>
  array (
    'connection' =>
    array (
      'indexer' =>
      array (
        'host' => '${DB_HOST}',
        'dbname' => '${DB_NAME}',
        'username' => '${DB_USER}',
        'password' => '${DB_PASSWORD}',
        'model' => 'mysql4',
        'engine' => 'innodb',
        'initStatements' => 'SET NAMES utf8;',
        'active' => '1',
        'persistent' => NULL,
      ),
      'default' =>
      array (
        'host' => '${DB_HOST}',
        'dbname' => '${DB_NAME}',
        'username' => '${DB_USER}',
        'password' => '${DB_PASSWORD}',
        'model' => 'mysql4',
        'engine' => 'innodb',
        'initStatements' => 'SET NAMES utf8;',
        'active' => '1',
      ),
    ),
    'table_prefix' => '',
  ),
  'install' =>
  array (
    'date' => 'Fri, 27 Nov 2015 12:24:54 +0000',
  ),
  'crypt' =>
  array (
    'key' => 'ec3b1c29111007ac5d9245fb696fb729',
  ),
  'session' =>
  array (
    'save' => 'files',
  ),
  'resource' =>
  array (
    'default_setup' =>
    array (
      'connection' => 'default',
    ),
  ),
  'x-frame-options' => 'SAMEORIGIN',
  'MAGE_MODE' => 'default',
  'cache_types' =>
  array (
    'config' => 1,
    'layout' => 1,
    'block_html' => 1,
    'collections' => 1,
    'reflection' => 1,
    'db_ddl' => 1,
    'eav' => 1,
    'full_page' => 1,
    'config_integration' => 1,
    'config_integration_api' => 1,
    'target_rule' => 1,
    'translate' => 1,
    'config_webservice' => 1,
  ),
);
EOF
}

function deployStaticContent()
{
    CMD="php -d memory_limit=2G bin/magento setup:static-content:deploy"
    runCommand
}

function installSampleData()
{
    if [ "${USE_SAMPLE_DATA}" ]
    then
        CMD="php -dmemory_limit=2G bin/magento sampledata:deploy"
        runCommand
        CMD="composer update"
        runCommand
        CMD="php -dmemory_limit=2G bin/magento setup:upgrade"
        runCommand
    fi
}

function linkEnterpriseEdition()
{
    if [ "${MAGENTO_EE_PATH}" ]
    then
        CMD="php ${MAGENTO_EE_PATH}/dev/tools/build-ee.php --ce-source $(pwd) --ee-source=${MAGENTO_EE_PATH}"
        runCommand
        CMD="cp ${MAGENTO_EE_PATH}/composer.json $(pwd)/"
        runCommand
        CMD="rm -rf $(pwd)/composer.lock"
        runCommand
    fi
}

function installMagento()
{
    CMD="cd ./bin"
    runCommand

    CMD="php ./magento --no-interaction setup:uninstall"
    runCommand

    dropDB
    createNewDB

    CMD="php -d memory_limit=2G ./magento setup:install --base-url=${BASE_URL} \
    --db-host=${DB_HOST} --db-name=${DB_NAME} --db-user=${DB_USER}  \
    --admin-firstname=Magento --admin-lastname=User --admin-email=mail@magento.com \
    --admin-user=admin --admin-password=123123q --language=en_US \
    --currency=USD --timezone=America/Chicago --use-rewrites=1 --backend-frontname=admin"
    if [ "${DB_PASSWORD}" ]
    then
        CMD="${CMD} --db-password=${DB_PASSWORD}"
    fi
    runCommand

    CMD="cd ../"
    runCommand
}

################################################################################

echo Current Directory: `pwd`
loadConfigFile
generateDBName
printLine
showWizard
promptSaveConfig

if foundSupportBackupFiles
then
    dropDB
    createNewDB
    restoreDB
    extractCode
    updateBaseUrl
    updateMagentoEnvFile
else
    linkEnterpriseEdition

    CMD="composer update"
    runCommand
    CMD="composer install"
    runCommand

    installMagento
    installSampleData
fi

deployStaticContent

CMD="chmod -R 0777 ./var ./pub/media ./pub/static ./app/etc"
runCommand

printLine

echo ${BASE_URL}
echo ${BASE_URL}admin
echo "User: admin"
echo "Pass: 123123q"

