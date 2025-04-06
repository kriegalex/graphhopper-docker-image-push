#!/bin/bash

usage() (
cat <<USAGE
Build a docker image for GraphHopper and optionally push it to Docker Hub

Usage:
  ./build.sh [[--push] [--api-key <api_key>] <tag>]
  ./build.sh --help

Argument:
  <tag>         Build an image for the given graphhopper repository tag [default: master]

Option:
  --push        Push the image to Docker Hub
  --api-key     GraphHopper API key to inject into config.js
  --help        Print this message
  
Docker Hub credentials are needed for pushing the image. If they are not provided using the
DOCKERHUB_USER and DOCKERHUB_TOKEN environment variables, then they will be asked interactively.
USAGE
)

push="false"
api_key=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --push)
      push="true"
      docker login --username "${DOCKERHUB_USER}" --password "${DOCKERHUB_TOKEN}" || exit $?
      shift
      ;;
    --api-key)
      api_key="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      # Assume it's the tag
      tag="$1"
      shift
      ;;
  esac
done

if [ ! -d graphhopper ]; then
  echo "Cloning graphhopper"
  git clone -b develop https://github.com/kriegalex/graphhopper.git
else
  echo "Pulling graphhopper"
  (cd graphhopper; git checkout develop; git pull)
fi

if [ -n "$api_key" ]; then
  echo "Injecting GraphHopper API key into config.js"
  sed -i "s/graphhopper: \"\"/graphhopper: \"$api_key\"/g" ./graphhopper/web-bundle/src/main/resources/com/graphhopper/maps/config.js;
fi

# Clone graphhopper-maps repository
if [ ! -d graphhopper-maps ]; then
  echo "Cloning graphhopper-maps"
  git clone -b develop https://github.com/kriegalex/graphhopper-maps.git
else
  echo "Pulling graphhopper-maps"
  (cd graphhopper-maps; git checkout develop; git pull)
fi

imagename="kriegalex/graphhopper:${tag:-latest}"
if [ "$tag" ]; then
  echo "Checking out graphhopper:$tag"
  (cd graphhopper; git checkout --detach "$tag")
fi

echo "Creating new builder instance for multi-platform (linux/amd64, linux/arm64/v8) builds to use for building Graphhopper"
docker buildx create --use --name graphhopperbuilder


if [ "${push}" == "true" ]; then
  echo "Building docker image ${imagename} for linux/amd64 and linux/arm64/v8 and pushing to Docker Hub"
  docker buildx build --platform linux/amd64,linux/arm64/v8 -t "${imagename}" --push .
else
  echo "Building docker image ${imagename} for linux/amd64"
  docker buildx build --platform linux/amd64 -t "${imagename}" --load .
  echo "Use \"docker push ${imagename}\" to publish the image on Docker Hub"
fi

# Remove the builder instance after use
docker buildx rm graphhopperbuilder
