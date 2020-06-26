#!/usr/bin/env bash

if [[ "$TRAVIS" != "true" ]]; then
    sudo apt-key adv --fetch-keys https://download.docker.com/linux/ubuntu/gpg
fi

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get -y install \
    docker-ce \
    parallel \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel
echo '{ "features": { "buildkit": true }, "experimental": true }' | sudo tee /etc/docker/daemon.json
sudo service docker restart

if [[ "$TRAVIS" == "true" && "$TRAVIS_PULL_REQUEST" == "false" && ( "$TRAVIS_BRANCH" == "master" || -n "$TRAVIS_TAG" ) ]]; then
    echo $TRAVIS_DOCKER_PASSWORD | docker login $TRAVIS_DOCKER_REGISTRY --username="$TRAVIS_DOCKER_USERNAME" --password-stdin
fi

if [[ "$TRAVIS" != "true" ]]; then
    sudo apt-get upgrade
    sudo usermod -a -G docker ubuntu
fi

pip3 install -r requirements.txt
pip3 install -r test-requirements.txt
