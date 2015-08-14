#!/bin/bash
#
# =================================================================
# SCRIPT 	: fuse_deploy.sh
# AUTHOR	: Michael Thirion
# COMPANY	: Red HAT
# DATE		: August, 5th 2015
# VERSION	: 1.0
#
# DESCRIPTION
# 	The script is used to deploy Int applicaiton on JBoss Fuse
# APPLICATION
#	Sapphire project @STC
#	Riyadh, Saudi Arabia
# ================================================================



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


# LOGS
# ----
LOGS=$BASE/logs
LOG_FILE=$LOGS/deploy.log
TRANLOG=$LOGS/deploy.xlog

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
echo "--------------" >> $LOG_FILE


# FUNCTIONS
# ---------

# cleanup tmp dir
function cleanup {
        rm -rf $TMP
}
# display usage information
usage() {
	echo "Usage: "
	echo "$0 -p <project name> -v <project version> -e <env> -c <fuse container> [-g <fabric version>] [-n] [-f] [-a]" 1>&2; 
	echo ""
	echo "-p <project name>    : project name in GIT repository (project.git)"
	echo "-v <project version> : release tag version in GIT"
	echo "-e <environment>	   : environment (DEV or STAGE)"
	echo "-c <fuse container>  : depoy on the specified Fuse container if it exists or create a new Fuse container for deployment" 1>&2;
	echo "[-g <fabric version>]: optional; specify the Fuse Fabric version (default to 1.0)" 1>&2;
	echo "[-n]                 : deploy on Nexus only, not on Fuse (used for maven libraries)"
	echo "[-f]                 : deploy on Fuse only, not Nexus (used exceptionally if the artifact already exist in Nexus)";
	echo "                       -f takes precedence over -n"
	echo "[-a]		   : only deploy in the registry but do not assign profile to container"
	echo ""
}

# execute commands remotely via SSH
function fuse_remote {
    ssh $FUSE_REMOTE_OWNER@$FABRIC8_HOST $FUSE_CLIENT \"$1\" 2>/dev/null
}

# INPUT PARAMETERS
# ----------------
#
# Variables
# 	PROJECT
#	VERSION
#	CONTAINER
#	VFABRIC
#	NEXUS_ONLY
#	FUSE_ONLY
#	NO_ASSIGN
#
NEXUS_ONLY="false"
FUSE_ONLY="false"
NO_ASSIGN="false"
VFABRIC="1.0"
while getopts "p:v:e:c:g:fna" o; do
    case "${o}" in
        p)
            PROJECT=${OPTARG}
            ;;
        v)
            VERSION=${OPTARG}
            ;;
        e)
            ENV=${OPTARG}
            ;;
        c)
            CONTAINER=${OPTARG}
	    ;;
	g)  
	    VFABRIC=${OPTARG}
            ;;
	n)  
	    NEXUS_ONLY="true"
            ;;
	f)  
	    FUSE_ONLY="true"
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

if [ -z "${PROJECT}" ] || [ -z "${VERSION}" ] || [ -z "$ENV" ] ; then
    echo "Missing parameter"
    usage
    exit 2
fi
if [[ $ENV != "DEV" && $ENV != "STAGE" ]]
then
    echo "Invalid environment"
    usage
    exit 2
fi
if [[ $NEXUS_ONLY == "false" ]]
then
	if [[ $NO_ASSIGN == "false" && -z $CONTAINER ]]
	then
	    echo "Invalid parameter"
	    usage
	    exit 2
	fi
fi

if [[ ! -z $VFABRIC ]]
then
	FABRIC8_VERSION=$VFABRIC
fi
    
echo "+++INPUT+++" >> $LOG_FILE
echo "--------------" >> $LOG_FILE
echo "project = $PROJECT" >> $LOG_FILE
echo "version = $VERSION" >> $LOG_FILE
echo "container = $CONTAINER" >> $LOG_FILE
echo "vfabric = $VFABRIC" >> $LOG_FILE
echo "nexus only flag = $NEXUS_ONLY" >> $LOG_FILE
echo "fuse only flag = $FUSE_ONLY" >> $LOG_FILE
echo "--------------" >> $LOG_FILE


# ENVIRONMENT
# -----------
if [[ $ENV == "DEV" ]]
then
	if [[ ! -f $ETC/deploy.dev.env || ! -r $ETC/deploy.dev.env ]]
        then
		. "$ETC/deploy.dev.env"
	else
		echo "Error: unable to read $ETC/deploy.dev.env"
		exit 1
	fi
fi
if [[ $ENV == "STAGE" ]]
then
	if [[ ! -f $ETC/deploy.stage.env || ! -r $ETC/deploy.stage.env ]]
        then
		. "$ETC/deploy.stage.env"
	else
		echo "Error: unable to read $ETC/deploy.stage.env"
		exit 1
	fi
fi

echo "FABRIC8_JOLOKIA_URL=$FABRIC8_JOLOKIA_URL"
echo "FABRIC8_USER=$FABRIC8_USER"
echo "FABRIC8_PSWD=$FABRIC8_PSWD"
echo "FABRIC8_VERSION=$FABRIC8_VERSION"

echo "GIT_SERVER_URL=$GIT_SERVER_URL"
echo "NEXUS_SERVER_URL=$NEXUS_SERVER_URL"
echo "NEXUS_HOSTED_REPOSITORY=$NEXUS_HOSTED_REPOSITORY"

echo "FUSE_HOME=$FUSE_HOME"
echo "FUSE_REMOTE_OWNER=$FUSE_REMOTE_OWNER"

echo "ENSEMBLE_NAME=$ENSEMBLE_NAME"
echo "..."

echo "--------------" >> $LOG_FILE

if [[ ! -f $ETC/settings.xml ]]
then
	echo "ERROR: cannot find $ETC/settings.xml"
	exit 1
fi


# SYSTEM CHECKS
# =============

# Verifying if 'git' is installed
# -------------------------------
if  [[ -z `which git` ]]
then
        echo "ERROR: <git> is not installed or cannot be found in PATH!" 
        exit 1
fi

# Verifying if 'Maven' is installed
# -------------------------------
if  [[ -z `which mvn` ]]
then
        echo "ERROR: <mvn> is not installed or cannot be found in PATH!  exiting..." 
        exit 1
fi



# curl-based checks
# -----------------
if  [[ -z `which curl` ]]
then
        echo "ERROR: <curl> is not installed or cannot be found in PATH! The target system URL will not be checked "
else
	if [[ ! -z `curl $FABRIC8_JOLOKIA_URL 2>/dev/null` ]]
	then
		echo "ERROR: the Fuse dev environment is unreachable at address: $FABRIC8_JOLOKIA_URL" 
		exit 1
	fi
	if [[ ! -z `curl $NEXUS_SERVER_URL 2>/dev/null` ]]
	then
		echo "ERROR: Nexus is unreachable: $NEXUS_SERVER_URL" 
		exit 1
	fi

#	if [[ ! -z `curl $GIT_SERVER_URL 2>/dev/null` ]]
#	then
#		echo "ERROR: the GIT server is unreachable : $GIT_SERVER_URL"
#		exit 1
#	fi

fi


# ============
# MAIN SECTION
# ============
clear

if [[ $NEXUS_ONLY == "true" ]]
then
	echo "NEXUS_ONLY is enabled"
fi
if [[ $FUSE_ONLY == "true" ]]
then
	echo "FUSE_ONLY is enabled"
fi
if [[ $NO_ASSIGN == "true" ]]
then
	echo "NO_ASSIGN is enabled"
fi



# Go to tmp directory
# -------------------
CURR=$PWD
cd $TMP
if [[ $? -ne 0 ]]
then
	echo "ERROR: cannot enter $TMP directory ! exiting..." 
	exit 1
fi
echo "clearing tmp directory..." 
rm -rf $TMP/*


# ----------------------
# 1. EXTRACT SOURCE CODE
# ----------------------
echo "importing project from GIT server..."

echo "+++ COMMAND +++" >> $LOG_FILE

GIT_CLONE="git clone $GIT_SERVER_URL/${PROJECT}.git"

$GIT_CLONE >> $LOG_FILE 2>&1
if [[ $? -ne 0 ]]
then
	echo "ERROR: the project $PROJECT cannot be found on GIT server : $GIT_SERVER_URL"
	cd $CURR
	exit 1
fi
cd $PROJECT

GIT_CHECKOUT="git checkout $VERSION"

$GIT_CHECKOUT >> $LOG_FILE 2>&1
if [[ $? -ne 0 ]]
then
	echo "ERROR: the project version $VERSION cannot be found in GIT repository"
	cd $CURR
	exit 1
fi


# Checking importing project
# --------------------------
echo "checking the imported project..."
if [[ ! -f pom.xml ]]
then
	echo "ERROR: cannot find pom.xml in imported project.  The project doesn't seem to be a maven project"
	cd $CURR
	exit 1
fi

# The below checks are just to avoid errors in normal circumstances
if [[ -z `grep '<distributionManagement>' pom.xml | grep -v '#' ` ]]
then
	echo "ERROR: cannot find a distributionManagement section in the pom.xml of the imported project."
	cd $CURR
	exit 1
fi
if [[ $FUSE_ONLY == "false" && -z `grep "$NEXUS_HOSTED_REPOSITORY" pom.xml | grep -v '#' | grep '<url>' ` ]]
then
	echo "ERROR: the Nexus repository URL is not correct for the imported project.  Please check the pom.xml of the project."
	cd $CURR
	exit 1
fi 
if [[ $FUSE_ONLY == "false" && -z `grep '<artifactId>maven-deploy-plugin</artifactId>' pom.xml | grep -v '#'  ` ]]
then
        echo "ERROR: the maven deploy plugin is not defined in the pom.xml of the project."
        cd $CURR
        exit 1
fi
if [[ $NEXUS_ONLY == "false" && -z `grep  '<artifactId>fabric8-maven-plugin</artifactId>' pom.xml | grep -v '#'  ` ]]
then
	echo "ERROR: the fabric8 maven plugin is not defined in the pom.xml of the project."
	cd $CURR
	exit 1
fi 


# ---------------------------------- 
# 2. COMPILE PROJECT
#    DEPLOY ARTIFACT TO NEXUS
#    DEPLOY FUSE PROFILE TO FUSE DEV
# ----------------------------------

# USED VARIABLES
#	FABRIC8_PROFILE_NAME
#	FABRIC8_VERSION
#
FABRIC8_PROFILE_NAME=${PROJECT}_${VERSION}
MVN_BASE="mvn -s $ETC/settings.xml -e"
MVN_BASE="$MVN_BASE -Dmaven.test.skip=true"
MVN_COMPILE="$MVN_BASE compile"
MVN_PACKAGE="$MVN_BASE package"
MVN_DEPLOY="$MVN_BASE deploy"
MVN_FABRIC_DEPLOY="$MVN_BASE io.fabric8:fabric8-maven-plugin:1.2.0.Beta4:deploy -Dfabric8.jolokiaUrl=$FABRIC8_JOLOKIA_URL -DskipTests -Dfabric8.profile=$FABRIC8_PROFILE_NAME -Dfabric8.profileVersion=$FABRIC8_VERSION"

# Build and package maven artifact to test the validity of the project
# ....................................................................
echo "compiling and packaging maven project..."
$MVN_PACKAGE > $TMP/mvn.log 2>&1
ret=$?
cat $TMP/mvn.log >> $LOG_FILE
if [[ $? -ne 0 ]]
then
	echo "ERROR: cannot build maven project"
	cat $TMP/mvn.log && rm $TMP/mvn.log
	cd $CURR
	exit 1
fi


if [[ $FUSE_ONLY == "true" ]]
then
	echo "deploying onto Fabric..."

	if [[ ! -d ./src/main ]]
	then
		mkdir ./src && mkdir ./src/main
	fi

	$MVN_FABRIC_DEPLOY > $TMP/mvn.log 2>&1
	ret=$?
	cat $TMP/mvn.log >> $LOG_FILE
	if [[ $ret -ne 0 ]]
	then
		echo "ERROR: cannot deploy the profile on Fuse"
		cat $TMP/mvn.log && rm $TMP/mvn.log
		cd $CURR
		exit 1
	fi
else
	echo "deploying to Nexus..."
	$MVN_DEPLOY > $TMP/mvn.log 2>&1
	ret=$?
	cat $TMP/mvn.log >> $LOG_FILE
        if [[ $ret -ne 0 ]]
        then
                echo "ERROR: cannot deploy the profile on Fuse"
                cat $TMP/mvn.log && rm $TMP/mvn.log
                cd $CURR
                exit 1
        fi
	if [[ $NEXUS_ONLY != "true" ]]
	then
		echo "deploying to Fabric..."
		$MVN_FABRIC_DEPLOY > $TMP/mvn.log 2>&1
		ret=$?
		cat $TMP/mvn.log >> $LOG_FILE
		if [[ $ret -ne 0 ]]
		then
			echo "ERROR: cannot deploy the profile on Fuse"
			cat $TMP/mvn.log && rm $TMP/mvn.log
			cd $CURR
			exit 1
		fi
	fi
fi
rm $TMP/mvn.log
	

# -------------------------------------------
# 3. CREATE FUSE CHILD CONTAINER IN DEV
#    ASSIGNE FABRIC PROFILE TO FUSE CONTAINER
# -------------------------------------------

if [[ $NO_ASSIGN == "false" ]]
then

	# Check if Fuse is running
	# ------------------------
	fuse_remote "info" > $TMP/result.tmp
	if [[ ! -z `cat $TMP/result.tmp | grep 'Failed to get the session' ` ]]
	then
		echo "Error: cannot connect to FUSE as a client"
		exit 1
	fi

	# Check if container exist
	# ------------------------
	echo "looking up container $CONTAINER..."
	CONTAINER_EXIST="container-info $CONTAINER"
	fuse_remote "$CONTAINER_EXIST" > $TMP/result.tmp
	if [[ ! -z `cat $TMP/result.tmp | grep "Container $CONTAINER does not exists" ` ]]
	then
		# create a new child container
		echo "The container $CONTAINER does not exist"
		echo "Creating container $CONTAINER..."
		CONTAINER_CREATE="container-create-child --version $FABRIC8_VERSION $ENSEMBLE_NAME $CONTAINER "
		fuse_remote "$CONTAINER_CREATE" > $TMP/result.tmp
		if [[ -z `cat $TMP/result.tmp | grep 'The following containers have been created successfully'` ]]
		then
			echo "Error in creating container $CONTAINER"
			echo ""
			exit
		fi
	fi

	# Assign the profile to the existing container
	# -------------------------------------------- 
	echo "Assigning profile $FABRIC8_PROFILE_NAME to container $CONTAINER"
	PROFILE_ASSIGN="container-add-profile $CONTAINER $FABRIC8_PROFILE_NAME "
	fuse_remote "$PROFILE_ASSIGN"

	echo ""
	echo "project $PROJECT deployed.  Recording the transaction..."
fi

# LOGGING THE DEPLOYMENT
# ----------------------
echo "=========================================="
echo "DEPLOYMENT $date" >> $TRANLOG
echo "-----------------------------" >> $TRANLOG
echo "$GIT_CLONE" >> $TRANLOG
echo "$GIT_CHECKOUT" >> $TRANLOG
echo "FUSE_ONLY = $FUSE_ONLY" >> $TRANLOG
if [[ $FUSE_ONLY == "true" ]]
then
	echo "$MVN_FABRIC_DEPLOY" >> $TRANLOG
else
	echo "$MVN_DEPLOY" >> $TRANLOG
	echo "NEXUS_ONLY = $NEXUS_ONLY" >> $TRANLOG
	if [[ $NEXUS_ONLY == "true" ]]
	then
		echo "$MVN_FABRIC_DEPLOY" >> $TRANLOG
	fi
fi

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
echo "deployment completed !"
echo ""

