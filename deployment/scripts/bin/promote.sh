#!/bin/bash
#
# ==================================================================================
# SCRIPT        : fuse_promote.sh
# AUTHOR        : Michael Thirion
# COMPANY       : Red HAT
# DATE          : August, 5th 2015
# VERSION       : 1.0
#
# DESCRIPTION
#       The script is used to copy a Fabric profile frmo one environment to another
# APPLICATION
#       Sapphire project @STC
#       Riyadh, Saudi Arabia
# ==================================================================================



# USER
# ----
if [[ $USER != "deployer" ]]
then
        echo "Error: script must be run by user account = deployer"
        exit 1
fi

# SCRIPT VARIABLES
# ----------------
BASE=$PWD/..
BIN=$BASE/bin
ETC=$BASE/etc
TMP=$BASE/tmp
GIT1=$TMP/git1
GIT2=$TMP/git2

# LOGS
# ----
LOGS=$BASE/logs
LOG_FILE=$LOGS/promote.log
TRANLOG=$LOGS/promote.xlog

if [[ ! -f $LOG_FILE ]]
then
        touch $LOG_FILE
        if [[ $? -ne 0 ]]
        then
                echo "ERROR: cannot write into $LOGS"
                exit 1
        fi
fi
if [[ ! -f $TRANLOG ]]
then
        touch $TRANLOG
        if [[ $? -ne 0 ]]
        then
                echo "ERROR: cannot write into $TRANLOG"
                exit 1
        fi
fi

if [[ ! -w $LOG_FILE || ! -w $TRANLOG ]]
then
        echo "Error: cannot write to $LOG_FILE or $TRANLOG"
        exit 1
fi

echo "===================" >> $LOG_FILE
echo $date >> $LOG_FILE


# FUNCTIONS
# ---------

# cleanup tmp dir
function cleanup {
        rm -rf $GIT1
        rm -rf $GIT2
}

# display usage information
usage() {
        echo "Usage: "
        echo "$0 -p <profile name> -i from-env -o to-env -c <fuse container> [-g <origin fabric version>] [-h target fabric version]" 1>&2;
	echo "-p <profile_name>	: profile name as it exists in the origin Fabric, including the version"
	echo "-i from-env	: environment source, from which the profile has to be promoted"
	echo "-o to-env		: environment target, to which the profile has to be promoted"
	echo "-c container	: container on which to assign the profile on the target environment"
	echo "-g origin version	: optional; version of the Fabric registry on the source env, if not 1.0"
	echo "-h origin version	: optional; version of the Fabric registry on the target env, if not 1.0"
	echo "-a		: just deploy on the Fabric registry, but do not assign profile to container"
	echo " Valid environments are :DEV, TEST, PROD"
        echo ""
}

# execute commands remotely via SSH
function ssh_fuse_target {
	ssh ${FUSE_TARGET_REMOTE_OWNER}@${FABRIC8_TARGET_HOST} ${FUSE_TARGET_CLIENT} \"$1\" 2>/dev/null 
}
function ssh_fuse_src {
	ssh ${FUSE_SRC_REMOTE_OWNER}@${FABRIC8_SRC_HOST} ${FUSE_SRC_CLIENT} \"$1\" 2>/dev/null 
}


# INPUT PARAMETERS
# ----------------
#
# Variables
#       PROFILE
#       CONTAINER
#       VFABRIC
#       NEXUS_ONLY
#       FUSE_ONLY
#       NO_ASSIGN
#
NEXUS_ONLY="false"
FUSE_ONLY="false"
NO_ASSIGN="false"
VFABRIC="1.0"
NO_ASSIGN="false"

while getopts "p:c:i:o:g:h:a" o; do
    case "${o}" in
        p)
            PROFILE=${OPTARG}
            ;;
        c)
            CONTAINER=${OPTARG}
            ;;
        i)
            SRC_ENV=${OPTARG}
            ;;
        o)
            TARGET_ENV=${OPTARG}
            ;;
        g)
            SRC_VFABRIC=${OPTARG}
            ;;
        h)
            TARGET_VFABRIC=${OPTARG}
            ;;
        a)
            NO_ASSIGN="true"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${PROFILE}" ] || [ -z "${SRC_ENV}" ] || [ -z "${TARGET_ENV}" ]; then
    echo "Invalid parameter"
    usage
    exit 2
fi
if [[ $NO_ASSIGN == "false" && -z $CONTAINER ]]
then
    echo "Invalid parameter"
    usage
    exit 2
fi

if [[ ! -z $SRC_VFABRIC ]]
then
	FABRIC8_${SRC_ENV}_VERSION=SRC_VFABRIC
fi
if [[ ! -z $TARGET_VFABRIC ]]
then
	FABRIC8_${TARGET_ENV}_VERSION=$TARGET_VFABRIC
fi


# Verifying source and target environments
# ----------------------------------------
if [[ $SRC_ENV != "DEV" && $SRC_ENV != "TEST" && $SRC_ENV != "PROD" ]]
then
	echo "Invalid environment for option -i : valid values are DEV, TEST and PROD"
	exit 1
fi
if [[ $TARGET_ENV != "DEV" && $TARGET_ENV != "TEST" && $TARGET_ENV != "PROD" ]]
then
	echo "Invalid environment for option -o : valid values are DEV, TEST and PROD"
	exit 1
fi


echo "+++INPUT+++" >> $LOG_FILE
echo "--------------" >> $LOG_FILE
echo "profile = $PROFILE" >> $LOG_FILE
echo "container = $CONTAINER" >> $LOG_FILE
echo "origin env = $SRC_ENV" >> $LOG_FILE
echo "target env = $TARGET_ENV" >> $LOG_FILE
echo "origin fabric version = $SRC_VFABRIC" >> $LOG_FILE
echo "target fabric version = $TARGET_VFABRIC" >> $LOG_FILE
echo "no assign flag = $NO_ASSIGN" >> $LOG_FILE
echo "--------------" >> $LOG_FILE

PROFILE_PATHNAME="${PROFILE}.profile"
clear

# Loading environment-specific properties
# ---------------------------------------
echo "$SRC_ENV PROPERTIES"
echo "..................."
if [[ $SRC_ENV == "DEV" ]]
then
	. "$ETC/promote.dev.env"
fi
if [[ $SRC_ENV == "TEST" ]]
then
	. "$ETC/promote.test.env"
fi

FABRIC8_SRC_HOST=$FABRIC8_HOST
FABRIC8_SRC_GIT_URL=$FABRIC8_GIT_URL
FABRIC8_SRC_USER=$FABRIC8_USER
FABRIC8_SRC_PSWD=$FABRIC8_PSWD
FABRIC8_SRC_VERSION=$FABRIC8_VERSION

FUSE_SRC_HOME=$FUSE_HOME
FUSE_SRC_CLIENT=$FUSE_CLIENT
FUSE_SRC_REMOTE_OWNER=$FUSE_REMOTE_OWNER
FUSE_SRC_ENSEMBLE=$FUSE_ENSEMBLE

echo "FABRIC8_SRC_HOST=$FABRIC8_HOST"
echo "FABRIC8_SRC_GIT_URL=$FABRIC8_GIT_URL"
echo "FABRIC8_SRC_USER=$FABRIC8_USER"
echo "FABRIC8_SRC_PSWD=$FABRIC8_PSWD"
echo "FABRIC8_SRC_VERSION=$FABRIC8_VERSION"

echo "FUSE_SRC_HOME=$FUSE_HOME"
echo "FUSE_SRC_CLIENT=$FUSE_CLIENT"
echo "FUSE_SRC_REMOTE_OWNER=$FUSE_REMOTE_OWNER"
echo "FUSE_SRC_ENSEMBLE=$FUSE_ENSEMBLE"
echo "..."
echo ""

echo "$TARGET_ENV PROPERTIES"
echo "......................"
if [[ $TARGET_ENV == "DEV" ]]
then
	. "$ETC/promote.dev.env"
fi
if [[ $TARGET_ENV == "TEST" ]]
then
	. "$ETC/promote.test.env"
fi

FABRIC8_TARGET_HOST=$FABRIC8_HOST
FABRIC8_TARGET_GIT_URL=$FABRIC8_GIT_URL
FABRIC8_TARGET_USER=$FABRIC8_USER
FABRIC8_TARGET_PSWD=$FABRIC8_PSWD
FABRIC8_TARGET_VERSION=$FABRIC8_VERSION

FUSE_TARGET_HOME=$FUSE_HOME
FUSE_TARGET_CLIENT=$FUSE_CLIENT
FUSE_TARGET_REMOTE_OWNER=$FUSE_REMOTE_OWNER
FUSE_TARGET_ENSEMBLE=$FUSE_ENSEMBLE

echo "FABRIC8_TARGET_HOST=$FABRIC8_HOST"
echo "FABRIC8_TARGET_GIT_URL=$FABRIC8_GIT_URL"
echo "FABRIC8_TARGET_USER=$FABRIC8_USER"
echo "FABRIC8_TARGET_PSWD=$FABRIC8_PSWD"
echo "FABRIC8_TARGET_VERSION=$FABRIC8_VERSION"

echo "FUSE_TARGET_HOME=$FUSE_HOME"
echo "FUSE_TARGET_CLIENT=$FUSE_CLIENT"
echo "FUSE_TARGET_REMOTE_OWNER=$FUSE_REMOTE_OWNER"
echo "FUSE_TARGET_ENSEMBLE=$FUSE_ENSEMBLE"
echo "..."
echo ""



# ============
# MAIN SECTION
# ============


# Verifying if 'git' is installed
# -------------------------------
if  [[ -z `which git` ]]
then
	echo "Error: git is not installed !"
	exit 1
fi
http_proxy=""

# getting git master
# ------------------
CLUSTER_LIST="cluster-list | grep fabric-repo"
ssh_fuse_src "$CLUSTER_LIST" > $TMP/clist
GIT_MASTER_SRC_HOST=`cat $TMP/clist | cut -d':' -f2`
GIT_MASTER_SRC_PORTPP=`cat $TMP/clist | cut -d':' -f3`
GIT_MASTER_SRC_URL="http:$GIT_MASTER_HOST:$GIT_MASTER_PORTPP"

ssh_fuse_target "$CLUSTER_LIST" > $TMP/clist
GIT_MASTER_TARGET_HOST=`cat $TMP/clist | cut -d':' -f2`
GIT_MASTER_TARGET_PORTPP=`cat $TMP/clist | cut -d':' -f3`
GIT_MASTER_TARGET_URL="http:$GIT_MASTER_HOST:$GIT_MASTER_PORTPP"

# Initializing temporary directories
# ----------------------------------
CURR=$PWD
mkdir -p $GIT1
mkdir -p $GIT2
rm -rf $GIT1/*
rm -rf $GIT2/*

# Getting the profile from source env
# -----------------------------------
echo "getting profile $PROFILE from $SRC_ENV"
cd $GIT1
echo "GIT CLONE IN $SRC_ENV" >> $LOG_FILE
GIT_CLONE_SRC="git clone http://${FABRIC8_SRC_USER}:${FABRIC8_SRC_PSWD}@${FABRIC8_SRC_HOST}:$GIT_MASTER_SRC_PORTPP"
echo "$GIT_CLONE_SRC"
$GIT_CLONE_SRC >> $LOG_FILE 2>&1
if [[ $? != 0 ]]
then
	echo "Error: cannot access the profile registry in $SRC_ENV"
	cd $CURR
	exit 1
fi

cd fabric/
GIT_CHECKOUT_SRC="git checkout -t origin/${FABRIC8_SRC_VERSION}"
$GIT_CHECKOUT_SRC >> $LOG_FILE 2>&1
if [[ ! -d ./fabric/profiles/$PROFILE_PATHNAME ]]
then
	echo "Error: the profile $PROFILE does not exist in $SRC_ENV"
	cd $CURR
	exit 1
fi

# Pusing the profile in TARGET
# -----------------------------
echo "copying profile $PROFILE from $TARGET_ENV"
cd $GIT2
echo "GIT CLONE IN $TARGET_ENV" >> $LOG_FILE
GIT_CLONE_TARGET="git clone http://${FABRIC8_TARGET_USER}:${FABRIC8_TARGET_PSWD}@${FABRIC8_TARGET_HOST}:$GIT_MASTER_TARGET_PORTPP"
echo "$GIT_CLONE_TARGET" 
$GIT_CLONE_TARGET >> $LOG_FILE 2>&1
if [[ $? != 0 ]]
then
	echo "Error: cannot access the profile registry in $TARGET_ENV"
	cd $CURR
	exit 1
fi

cd fabric/


GIT_CHECKOUT_TARGET="git checkout -t origin/${FABRIC8_TARGET_VERSION}"
$GIT_CHECKOUT_TARGET >> $LOG_FILE 2>&1
if [[ $? != 0 ]]
then
	echo "Error: the version $FABRIC8_TARGET_VERSION does not exist in the Fabric of $SRC_ENV"
	cd $CURR
	exit 1
fi

echo "copy $GIT1/fabric/fabric/profiles/${PROFILE_PATHNAME}" >> $LOG_FILE 2>&1
COPY="cp -r $GIT1/fabric/fabric/profiles/${PROFILE_PATHNAME} ./fabric/profiles"
$COPY >> $LOG_FILE 2>&1


echo "GIT ADD files" >> $LOG_FILE
GIT_ADD="git add ./fabric/profiles/${PROFILE_PATHNAME}/*"
$GIT_ADD >> $LOG_FILE 2>&1

echo "GIT COMMIT TO TARGET ENV" >> $LOG_FILE
MESSAGE="update profile $PROFILE - `date`"
GIT_COMMIT="git commit -m \" $MESSAGE \" "
git commit -m "$MESSAGE" >> $LOG_FILE 2>&1  # done because of error with -m message when using variable substitution

echo "GIT PUSH TO TARGET ENV" >> $LOG_FILE
GIT_PUSH="git push origin ${FABRIC8_TARGET_VERSION}"
$GIT_PUSH >> $LOG_FILE 2>&1

echo ""
echo "profile promoted"
echo ""

if [[ $NO_ASSIGN == "false" ]]
then
	echo "assigning profile to container $CONTAINER"

        # Check if Fuse is running
        # ------------------------

        ssh_fuse_target "info" > $TMP/result.tmp

        if [[ ! -z `cat $TMP/result.tmp | grep 'Failed to get the session' ` ]]
        then
                echo "Error: cannot connect to FUSE as a client"
                exit 1
        fi


        # Check if container exist
        # ------------------------
        echo "looking up container $CONTAINER..."
        CONTAINER_EXIST="container-info $CONTAINER"
        ssh_fuse_target "$CONTAINER_EXIST" > $TMP/result.tmp
        if [[ ! -z `cat $TMP/result.tmp | grep "Container $CONTAINER does not exists" ` ]]
        then
                # create a new child container
                echo "The container $CONTAINER does not exist"
                echo "Creating container $CONTAINER..."
                CONTAINER_CREATE="container-create-child --version $FABRIC8_TARGET_VERSION $FUSE_TARGET_ENSEMBLE $CONTAINER "
                ssh_fuse_target "$CONTAINER_CREATE" >> $TMP/result.tmp
                if [[ -z `cat $TMP/result.tmp | grep 'The following containers have been created successfully'` ]]
                then
                        echo "Error in creating container $CONTAINER"
                        echo ""
                        exit
                fi
        fi

        # Assign the profile to the existing container
        # -------------------------------------------- 
        PROFILE_ASSIGN="container-add-profile $CONTAINER $PROFILE "
        ssh_fuse_target "$PROFILE_ASSIGN"

        echo ""
        echo "profile $PROFILE assigned."
	echo "Recording the transaction..."
fi



# LOGGING THE DEPLOYMENT
# ----------------------
echo "=========================================="
echo "PROMOTION $date" >> $TRANLOG
echo "----------------------------" >> $TRANLOG
echo "$GIT_CLONE_SRC" >> $TRANLOG
echo "$GIT_CHECKOUT_SRC" >> $TRANLOG
echo "$GIT_CLONE_TARGET" >> $TRANLOG
echo "$GIT_CHECKOUT_TARGET" >> $TRANLOG
echo "$COPY" >> $TRANLOG
echo "$GIT_ADD" >> $TRANLOG
echo "$GIT_COMMIT" >> $TRANLOG
echo "$GIT_PUSH" >> $TRANLOG

echo "ASSIGN = $NO_ASSIGN" >> $TRANLOG
if [[ $NO_ASSIGN == "false" ]]
then
        if [[ $CONTAINER_CREATE ]]
        then
                echo "$CONTAINER_CREATE" >> $TRANLOG
        fi
        echo "$PROFILE_ASSIGN" >> $TRANLOG
        echo '..'
fi

