# docker-kolla-docker

[![Build Status](https://travis-ci.org/osism/docker-kolla-docker.svg?branch=master)](https://travis-ci.org/osism/docker-kolla-docker)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-osism-blue.svg)](https://hub.docker.com/r/osism)
[![Quay](https://img.shields.io/badge/Quay-osism-blue.svg)](https://quay.io/organization/osism)

## Requirements

* Docker must be usable on the system.
* It makes sense to run this build wrapper on a dedicated system. All existing Docker images
  and containers should be removed before execution.

  ```
  $ docker stop $(docker ps -a -q)
  $ docker rm $(docker ps -a -q)
  $ docker system prune -a -f
  ```
* After checking out the repository, update the submodules: ``git submodule update --init --recursive``

## Usage

```
$ export OPENSTACK_VERSION=train
$ export UBUNTU_VERSION=18.04
```

It is possible to build only certain images.

```
$ export KOLLA_IMAGES="^keystone"
```

To build a particular tag, check it out in advance.

``OSISM_VERSION`` will then be set to ``2019.4.0`` on tag ``v2019.4.0``.
Otherwise ``OSISM_VERSION`` is set to ``latest``.

### Step by step

```
$ bash scripts/prepare.sh
$ bash scripts/generate.sh
$ bash scripts/patch.sh
$ bash scripts/build.sh
$ bash scripts/tag.sh
$ bash scripts/push.sh
```

## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Author information

This build wrapper for the Kolla images was created by [Betacloud Solutions GmbH](https://www.betacloud-solutions.de).
