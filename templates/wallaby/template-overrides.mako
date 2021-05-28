{% extends parent_template %}

{% set openstack_base_pip_packages_append = ['pip', 'git+https://github.com/sapcc/openstack-audit-middleware.git'] %}

{% set glance_base_pip_packages_append = ['boto3'] %}

{% block base_header %}
COPY apt_preferences.{{ base_distro }} /etc/apt/preferences
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends locales ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/* ${"\\"}
    && locale-gen en_US.UTF-8
{% endblock %}

{% block openstack_base_header %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends python3-setuptools ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*
{% endblock %}

{% set bifrost_deploy_packages_append = ['debootstrap', 'squashfs-tools', 'cpio'] %}

{% set kolla_toolbox_packages_append = ['iputils-ping', 'traceroute'] %}

{% set cinder_volume_packages_append = ['multipath-tools'] %}

{% set cinder_volume_pip_packages = [ 'cinderlib', 'purestorage' ] %}
{% block cinder_volume_footer %}
RUN {{ macros.install_pip(cinder_volume_pip_packages | customizable("pip_packages")) }}
{% endblock %}

{% set gnocchi_base_packages_append = ['python3-rados'] %}

{% block horizon_header %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends pypy3 ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*

RUN rm -rf /var/lib/kolla ${"\\"}
    && mkdir -p /var/lib/kolla ${"\\"}
    && virtualenv --python /usr/bin/pypy3 --system-site-packages /var/lib/kolla/venv ${"\\"}
    && ln -s /var/lib/kolla/venv.pypy/lib/python3.6 /var/lib/kolla/venv.pypy/lib/python3.8

<%text>
{% set horizon_pip_packages_append = [
        'Babel',
        'Mako',
        'MarkupSafe',
        'Paste',
        'PasteDeploy',
        'PyNaCl',
        'PyYAML',
        'Routes',
        'SQLAlchemy',
        'Tempita',
        'WebOb',
        'WSME',
        'alembic',
        'amqp',
        'anyjson',
        'aodhclient',
        'appdirs',
        'automaton',
        'bcrypt',
        'cachetools',
        'castellan',
        'click',
        'cliff',
        'cmd2',
        'cryptography',
        'contextlib2',
        'debtcollector',
        'decorator',
        'elasticsearch',
        'eventlet',
        'fasteners',
        'funcsigs',
        'futurist',
        'gnocchiclient',
        'greenlet',
        'httplib2',
        'iso8601',
        'jinja2',
        'jsonpatch',
        'jsonpointer',
        'jsonschema',
        'keystoneauth1',
        'keystonemiddleware',
        'kombu',
        'logutils',
        'monotonic',
        'mysqlclient',
        'netaddr',
        'netifaces',
        'os-client-config',
        'os-brick',
        'os-traits',
        'os-win',
        'oslo.concurrency',
        'oslo.config',
        'oslo.context',
        'oslo.db',
        'oslo.i18n',
        'oslo.log',
        'oslo.messaging',
        'oslo.middleware',
        'oslo.policy',
        'oslo.privsep',
        'oslo.reports',
        'oslo.rootwrap',
        'oslo.serialization',
        'oslo.service',
        'oslo.upgradecheck',
        'oslo.utils',
        'oslo.versionedobjects',
        'oslo.vmware',
        'osprofiler',
        'paramiko',
        'pbr',
        'pecan',
        'pika',
        'prettytable',
        'psutil',
        'pycadf',
        'pyinotify',
        'pymongo',
        'pymysql',
        'pyngus',
        'pyparsing',
        'pyroute2',
        'python-barbicanclient',
        'python-cinderclient',
        'python-cloudkittyclient',
        'python-dateutil',
        'python-designateclient',
        'python-editor',
        'python-glanceclient',
        'python-heatclient',
        'python-ironicclient',
        'python-keystoneclient',
        'python-magnumclient',
        'python-manilaclient',
        'python-memcached',
        'python-mistralclient',
        'python-muranoclient',
        'python-neutronclient',
        'python-novaclient',
        'python-openstackclient',
        'python-qpid-proton',
        'python-saharaclient',
        'python-swiftclient',
        'python-troveclient',
        'python-vitrageclient',
        'pytz',
        'repoze.lru',
        'requests',
        'requestsexceptions',
        'retrying',
        'setproctitle',
        'simplegeneric',
        'simplejson',
        'six',
        'sqlalchemy-migrate',
        'sqlparse',
        'stevedore',
        'tooz[consul,etcd,etcd3,etcd3gw,zake,redis,postgresql,mysql,zookeeper,memcached,ipc]',
        'unicodecsv',
        'warlock',
        'wrapt'
    ]
%}
</%text>
{% endblock %}

{% block keystone_footer %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends ${"\\"}
           libapache2-mod-auth-openidc ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/* ${"\\"}
    && a2enmod auth_openidc
{% endblock %}

{% block footer %}
RUN rm -rf /usr/share/doc/* ${"\\"}
    && rm -rf /usr/share/man/*
{% endblock %}

{% block labels %}
LABEL "build-date"="{{ build_date }}" ${"\\"}
      "name"="{{ image_name }}" ${"\\"}
      "de.osism.commit.docker_images_kolla"="${hash_docker_images_kolla}" ${"\\"}
      "de.osism.commit.kolla"="${hash_kolla}" ${"\\"}
      "de.osism.commit.release"="${hash_release}" ${"\\"}
      "de.osism.release.openstack"="${openstack_version}" ${"\\"}
      "de.osism.version"="${osism_version}" ${"\\"}
      "org.opencontainers.image.created"="${created}" ${"\\"}
      "org.opencontainers.image.documentation"="https://docs.osism.de" ${"\\"}
      "org.opencontainers.image.licenses"="ASL 2.0" ${"\\"}
      "org.opencontainers.image.source"="https://github.com/osism/container-images-kolla" ${"\\"}
      "org.opencontainers.image.title"="{{ image_name }}" ${"\\"}
      "org.opencontainers.image.url"="https://www.osism.de" ${"\\"}
      "org.opencontainers.image.vendor"="Betacloud Solutions GmbH" ${"\\"}
      "org.opencontainers.image.version"="${osism_version}"
{% endblock %}
