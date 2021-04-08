# docker-images-kolla

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
$ export OPENSTACK_VERSION=ussuri
```

It is possible to build only certain images.

```
$ export KOLLA_IMAGES="^keystone"
```

To build a particular tag, check it out in advance.

``OSISM_VERSION`` will then be set to ``2019.4.0`` on tag ``v2019.4.0``.
Otherwise ``OSISM_VERSION`` is set to ``latest``.

To squash images set ``SQUASH`` to ``true``.

```
$ export SQUASH=true
```

### Step by step

```
$ virtualenv -p python3 .venv
$ source .venv/bin/activate
$ pip3 install -r requirements.txt
$ source scripts/defaults/$OPENSTACK_VERSION.sh
```

```
$ bash scripts/001-prepare.sh
$ bash scripts/002-generate.sh
$ bash scripts/003-patch.sh
$ bash scripts/004-build.sh
$ bash scripts/005-tag.sh
$ bash scripts/006-push.sh
```
