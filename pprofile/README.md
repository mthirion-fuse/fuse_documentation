# fuse - parent profile

# Overview
This example showcases the use of the Fabric8 v1 profile hierarchy to deal with environment-dependent properties.
An abstract parent profile is used to gather all the environment-specific properties in one or many files.
Each application defines this unique profile as its parent and can therefore inherit the environment-specific properties from that hierarchy.

In the source Maven project, the parent profile application will contain the properties for each environment.
The project will be built according to a Maven "profile" corresponding to one environment.
As a result, the build will create an artifact containing only the properties specific to the corresponding environment.

# Detailed description

The Maven project is made of 3 elements: a parent and 2 submodules.

## pprofile
  The parent module gathers the information reusable by the submodules like:
  - The bom file of Fuse v6.2
  - The declaration of the maven bundle plugin
    It uses the fabric8-maven-plugin v1.1.0.CR5 (instead of v1.2.0.redhat-133)
    This version of the plugin requires an extra library available @ https://repository.jboss.org/
    Notice that the maven deploy goal changes the "version" attribute to a timestamped version when working with snapshots.
    If combined with the "fabric8:deploy" goal this leads to an issue in the resulting fabric8 profile that will contain wrong maven coordinates.  The wrong version can be seen in the json request when maven is executed with -e -X options (the version is made of 0.0.1-timestamp instead of 0.0.1-Snapshot)

## environment
  The pprofile_env submodule create an environment-dependent profile that contains properties for one specific environment.
  It only contains properties; no binary code.
  In the example it uses an env.properties file declared under src/main/fabric8
  The module is built for a specific maven profile (here dev or prd).
  Here we choose to store a different env.properties file under a directory corresponding to an environment (dev & prd).
  The profile will copy the corresponding file into /src/main/fabric8 using the maven resources plugin and the copy-file action.
  Another possibility would for example be to change the "profileConfigDir" parameter of the fabric8-maven-plugin to directly read the properties from the "dev" or "prd" according to the chosen profile. 
  
  The module also provides specific values for some fabric8-maven-plugin properties (here it simply declares the profile as abstract).

## app
  The pprofile_app submodule simulates an application profile to be deployed on a karaf container managed by a Fabric.
  It declares a blueprint property placeholder with a pid value of "env", which corresponds to the "env.properties" file exposed by the parent profile.
  It also declares the pprofile_env as its parent.
  The Blueprint property placeholder element belongs to the "http://aries.apache.org/blueprint/xmlns/blueprint-cm/v1.0.0" namespace.
  The elements from this namespace are provided by the camel-blueprint feature which is declared as a dependency feature through a fabric8 property.
 
  As for the code, the application simply logs the values of some of the environment-specific variables every 5 sec

# Demo
For a better experience with the example, install Fuse v6 and create 2 Fabrics; one for dev and one for prod.
 A
 - build the pprofile_env profile with the "dev" Maven profile and deploy it to the "dev" environment.
   "mvn -U package fabric8:deploy -Pdev -DjolokiaUrl=http://dev_hostname:port/jolokia"
 - build the pprofile_env profile with the "prd" Maven profile and deploy it to the "dev" environment.
   "mvn -U package fabric8:deploy -Pprd -DjolokiaUrl=http://prod_hostname:port/jolokia"

 - deploy the exact same pprofile_app profile twice, one in each environemnt
   "mvn -U package fabric8:deploy -DjolokiaUrl=..."

 - create a "default" child container in each Fabric and assign to it the pprofile_app profile
 - check the log.  
   you should see the application logging some environment-specific properties values every 5 sec.
   though it's the exact same application deployed in both environment, you'll see it logging different values

 
# Fuse without Fabric
The principle is applicable with Fuse standalone.
In that case, the environment-dependent property file(s) will simply have to be placed in $FUSE_HOME/etc (with a .cfg extension instead of .properties).


# Links
* [Fabric8 maven plugin](http://fabric8.io/gitbook/mavenPlugin.html)

