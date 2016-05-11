# Generic Maven Archetype for a Fabric bundle
The generic maven archetype contains:
 * A pom.xml with
   - bundle packaging
   - fuse bom
   - fabric properties (parent, features, profile)
   - scm entry
   - repositories list
   - distributionManagement pointing to localhost:8081
   - basic dependencies
   - a default build profile embedding:
      - fabric8 resource filtering
      - basic plugins
         - surefire
         - bundle
         - fabric8
         - release

 * A blueprint.xml         

 * An empty java bean

 * 2 unit test files (java & blueprint)


# Artifact generation
groupId="myGroupId"
artifactId="myArtifactId"
artifactVersion="myArtifactversion"

archetypeGroupId=org.rh.integration
archetypeArtifactId=fabric-archetype
archetypeVersion=1.0.0

archetypeRepository="myArchetypeRepository"


mvn archetype:generate                                  \
      -DarchetypeGroupId=$archetypeGroupId                \
      -DarchetypeArtifactId=$archetypeArtifactId         \
      -DarchetypeVersion=$archetypeVersion                \
      -DgroupId=$groupId                                \
      -DartifactId=$artifactId                          \
      -Dversion=$artifactVersion                        \
      -DarchetypeRepository=$archetypeRepository $*


