# fuse - parent profile

### Overview
This example showcases the use of the Fabric profile hierarchy to deal with environment-dependent properties.
An abstract parent profile is used to gather all the environment-specific properties in one or many files.
Each application defines this profile as its parent and can therefore ihnerit from the environment-specific properties.

In the source Maven project, the parent profile application contains the properties for all the environments.
The project is built according to a Maven profile corresponding to one environment.
The result of the build is an artifact containing only the properties specific to that environment.

### Detailed description

# pprofile
 - Fuse 6.2 -> bom
 - maven bundle plugin
 - maven deploy plugin
 - fabric8-maven-plugin v1.1.0.CR5 instead of 1.2.0.redhat-133
   -> require jboss repository https://repository.jboss.org/

# environment
 - pprofile_env
 - src/main/fabric8
 - profiles
    - resource fitlering
    - resources plugin -> copy files
    - fabric8 maven plugin specific conf (abstract profile)

# app
 - blueprint property placeholder PID=env.properties
   --> require xmlns:cm="http://aries.apache.org/blueprint/xmlns/blueprint-cm/v1.0.0"
 - pprofile_app + parent profile
 - camel-blueprint feature
 - fabric8 maven plugin specific conf (abstract profile)

### Demo
1) deploy pprofile_env (must be first)
2) deploy app_env
3) assign app_env to a container

