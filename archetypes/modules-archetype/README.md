# Generic Parent Archetype for a project with submodules


## Artifact generation
groupId="myGroupId" 

artifactId="myArtifactId" 

artifactVersion="myArtifactversion"

archetypeGroupId=org.rh.integration 

archetypeArtifactId=modules-archetype 

archetypeVersion=1.0.0

archetypeRepository="myArchetypeRepository"

*

*

>>
>> mvn archetype:generate                                  

      -DarchetypeGroupId=$archetypeGroupId                \

      -DarchetypeArtifactId=$archetypeArtifactId         \

      -DarchetypeVersion=$archetypeVersion                \

      -DgroupId=$groupId                                \

      -DartifactId=$artifactId                          \

      -Dversion=$artifactVersion                        \

      -DarchetypeRepository=$archetypeRepository $*


