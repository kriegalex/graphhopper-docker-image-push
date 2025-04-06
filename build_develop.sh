#!/bin/bash

usage() (
cat <<USAGE
Build a docker image for GraphHopper and optionally push it to Docker Hub

Usage:
  ./build.sh [[--push] <tag>]
  ./build.sh --help

Argument:
  <tag>         Build an image for the given graphhopper repository tag [default: master]

Option:
  --push        Push the image to Docker Hub
  --help        Print this message
  
Docker Hub credentials are needed for pushing the image. If they are not provided using the
DOCKERHUB_USER and DOCKERHUB_TOKEN environment variables, then they will be asked interactively.
USAGE
)

if [ "$1" == "--push" ]; then
  push="true"
  docker login --username "${DOCKERHUB_USER}" --password "${DOCKERHUB_TOKEN}" || exit $?
  shift
else
  push="false"
fi

if [ $# -gt 1 ] || [ "$1" == "--help" ]; then
  usage
  exit
fi

if [ ! -d graphhopper ]; then
  echo "Cloning graphhopper"
  git clone -b develop https://github.com/kriegalex/graphhopper.git
else
  echo "Pulling graphhopper"
  (cd graphhopper; git checkout develop; git pull)
fi

# Clone graphhopper-maps repository
if [ ! -d graphhopper-maps ]; then
  echo "Cloning graphhopper-maps"
  git clone -b develop https://github.com/kriegalex/graphhopper-maps.git
else
  echo "Pulling graphhopper-maps"
  (cd graphhopper-maps; git checkout develop; git pull)
fi

imagename="kriegalex/graphhopper:${1:-latest}"
if [ "$1" ]; then
  echo "Checking out graphhopper:$1"
  (cd graphhopper; git checkout --detach "$1")
fi

echo "Creating new builder instance for multi-platform (linux/amd64, linux/arm64/v8) builds to use for building Graphhopper"
docker buildx create --use --name graphhopperbuilder


if [ "${push}" == "true" ]; then
  echo "Building docker image ${imagename} for linux/amd64 and linux/arm64/v8 and pushing to Docker Hub\n"
  docker buildx build --platform linux/amd64,linux/arm64/v8 -t "${imagename}" --push .
else
  echo "Building docker image ${imagename} for linux/amd64 and linux/arm64/v8\n"
  docker buildx build --platform linux/amd64 -t "${imagename}" --load .
  echo "Use \"docker push ${imagename}\" to publish the image on Docker Hub"
fi

# Remove the builder instance after use
docker buildx rm graphhopperbuilder
