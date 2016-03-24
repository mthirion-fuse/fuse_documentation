# fuse - parent profile

### Overview
This example showcases the use of the Fabric profile hierarchy to deal with environment-dependent properties.
An abstract parent profile is used to gather all the environment-specific properties in one or many files.
Each application defines this profile as its parent and can therefore ihnerit from the environment-specific properties.

In the source Maven project, the parent profile application contains the properties for all the environments.
The project is built according to a Maven profile corresponding to one environment.
The result of the build is an artifact containing only the properties specific to that environment.

### Detailed description


### Demo

