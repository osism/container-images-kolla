{% extends parent_template %}

{% set openstack_base_pip_packages_append = ['pip', 'git+https://github.com/sapcc/openstack-audit-middleware.git'] %}

{% set glance_base_pip_packages_append = ['boto3'] %}

{% block horizon_header %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends build-essential libmariadb-dev-compat ${"\\"}
    && SETUPTOOLS_USE_DISTUTILS=stdlib python3 -m pip --no-cache-dir install --upgrade mysqlclient ${"\\"}
    && apt-get remove -y build-essential ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*
{% endblock %}

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

{% set cinder_volume_pip_packages = [ 'cinderlib', 'purestorage', 'infinisdk', 'python-linstor' ] %}
{% block cinder_volume_footer %}
RUN {{ macros.install_pip(cinder_volume_pip_packages | customizable("pip_packages")) }}
{% endblock %}

{% set manila_base_additional_pip_packages = [ 'pywinrm' ] %}
{% block manila_base_footer %}
RUN {{ macros.install_pip(manila_base_additional_pip_packages | customizable("pip_packages")) }}
{% endblock %}

{% set gnocchi_base_packages_append = ['python3-rados'] %}

{% block grafana_footer %}
RUN curl -o /tmp/kolla-operations.tar.gz https://github.com/osism/kolla-operations/tarball/main ${"\\"}
    && mkdir -p /operations ${"\\"}
    && tar --strip-components=1 -xvzf /tmp/kolla-operations.tar.gz -C /operations ${"\\"}
    && rm -f /tmp/kolla-operations.tar.gz
{% endblock %}

{% block keystone_footer %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends ${"\\"}
           libapache2-mod-auth-openidc ${"\\"}
           libmemcached11 ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/* ${"\\"}
    && curl -o /tmp/liboauth2.deb "https://github.com/zmartzone/liboauth2/releases/download/v1.4.5.2/liboauth2_1.4.5.2-1.jammy_amd64.deb" ${"\\"}
    && dpkg -i /tmp/liboauth2.deb ${"\\"}
    && rm -f /tmp/liboauth2.deb ${"\\"}
    && curl -o /tmp/liboauth2-apache.deb "https://github.com/zmartzone/liboauth2/releases/download/v1.4.5.2/liboauth2-apache_1.4.5.2-1.jammy_amd64.deb" ${"\\"}
    && dpkg -i /tmp/liboauth2-apache.deb ${"\\"}
    && rm -f /tmp/liboauth2-apache.deb ${"\\"}
    && curl -o /tmp/libapache2-mod-oauth2.deb "https://github.com/zmartzone/mod_oauth2/releases/download/v3.3.0/libapache2-mod-oauth2_3.3.0-1.jammy_amd64.deb" ${"\\"}
    && dpkg -i /tmp/libapache2-mod-oauth2.deb ${"\\"}
    && rm -f /tmp/libapache2-mod-oauth2.deb ${"\\"}
    && a2enmod oauth2 ${"\\"}
    && a2enmod auth_openidc
{% endblock %}

{% block footer %}
RUN rm -rf /usr/share/doc/* ${"\\"}
    && rm -rf /usr/share/man/*

RUN apt-get remove -y build-essential ${"\\"}
    && apt-get autoremove -y
{% endblock %}

{% block labels %}
LABEL "build-date"="{{ build_date }}" ${"\\"}
      "name"="{{ image_name }}" ${"\\"}
      "de.osism.commit.docker_images_kolla"="${hash_docker_images_kolla}" ${"\\"}
      "de.osism.commit.kolla"="${hash_kolla}" ${"\\"}
      "de.osism.commit.kolla_version"="${kolla_version}" ${"\\"}
      "de.osism.commit.release"="${hash_release}" ${"\\"}
      "de.osism.release.openstack"="${openstack_version}" ${"\\"}
      "de.osism.version"="${version}" ${"\\"}
      "org.opencontainers.image.created"="${created}" ${"\\"}
      "org.opencontainers.image.documentation"="https://docs.osism.tech" ${"\\"}
      "org.opencontainers.image.licenses"="ASL 2.0" ${"\\"}
      "org.opencontainers.image.source"="https://github.com/osism/container-images-kolla" ${"\\"}
      "org.opencontainers.image.title"="{{ image_name }}" ${"\\"}
      "org.opencontainers.image.url"="https://www.osism.tech" ${"\\"}
      "org.opencontainers.image.vendor"="OSISM GmbH" ${"\\"}
      "org.opencontainers.image.version"="${version}"
{% endblock %}
