{% extends parent_template %}

{% set fluentd_plugins = [
    'fluent-plugin-grok-parser',
    'fluent-plugin-prometheus',
    'fluent-plugin-rewrite-tag-filter',
    'fluent-plugin-grafana-loki',
] %}

{% set openstack_base_pip_packages_append = ['pip', 'git+https://github.com/sapcc/openstack-audit-middleware.git'] %}

{% set glance_base_pip_packages_append = ['boto3'] %}

{% set nova_libvirt_packages_packages_append = ['mdevctl'] %}

{% block nova_libvirt_footer %}
RUN chgrp tss /var/lib/swtpm-localca ${"\\"}
    && chmod g+w /var/lib/swtpm-localca
## The `efi-virtio.rom` used to be 512kb in 2024.1 and shrunk to 256kb in 2024.2.
## A change in size causes an error in libvirt/qemu and breaks live migration, therefore we inflate it with zeros to match the expected size.
## https://github.com/osism/issues/issues/1289
RUN truncate --size=524288 /usr/lib/ipxe/qemu/efi-virtio.rom
{% endblock %}

{% block horizon_header %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends build-essential libmariadb-dev-compat ${"\\"}
    && python3 -m pip --no-cache-dir install --upgrade setuptools mysqlclient ${"\\"}
    && apt-get remove -y build-essential ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*
{% endblock %}

{% block horizon_footer %}
RUN curl -q -L -o /tmp/openstack-themes.tar.gz https://github.com/osism/openstack-themes/archive/main.tar.gz ${"\\"}
    && tar xzvf /tmp/openstack-themes.tar.gz --directory=/var/lib/kolla/venv/lib/python3/site-packages/openstack_dashboard/themes --strip-components 2 openstack-themes-main/horizon ${"\\"}
    && rm /tmp/openstack-themes.tar.gz
{% endblock %}

{% block base_header %}
COPY apt_preferences.{{ base_distro }} /etc/apt/preferences
COPY *.gpg /etc/kolla/apt-keys/

RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends locales ca-certificates ${"\\"}
    && locale-gen en_US.UTF-8 ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*
{% endblock %}

{% block openstack_base_header %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends python3-setuptools ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*
{% endblock %}

{% set glance_base_packages_append = ['nvme-cli'] %}

{% set kolla_toolbox_packages_append = ['iputils-ping', 'traceroute'] %}

{% set cinder_volume_packages_append = ['multipath-tools'] %}

{% set cinder_volume_pip_packages = [ 'py-pure-client', 'infinisdk', 'python-linstor' ] %}
{% block cinder_volume_footer %}
RUN {{ macros.install_pip(cinder_volume_pip_packages | customizable("pip_packages")) }}
{% endblock %}

{% set manila_base_additional_pip_packages = [ 'pywinrm' ] %}
{% block manila_base_footer %}
RUN {{ macros.install_pip(manila_base_additional_pip_packages | customizable("pip_packages")) }}
{% endblock %}

{% set magnum_base_additional_pip_packages = [ 'magnum-cluster-api' ] %}
{% block magnum_base_footer %}
RUN {{ macros.install_pip(magnum_base_additional_pip_packages | customizable("pip_packages")) }}
RUN curl -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.15.2-linux-amd64.tar.gz ${"\\"}
    && tar --strip-components=1 -xvzf /tmp/helm.tar.gz -C /usr/local/bin linux-amd64/helm
{% endblock %}

{% set gnocchi_base_packages_append = ['python3-rados'] %}
{% block gnocchi_base_footer %}
RUN mkdir -p /var/lib/gnocchi/tmp ${"\\"}
    && chown -R gnocchi: /var/lib/gnocchi/tmp
{% endblock %}

{% block grafana_footer %}
RUN curl -o /tmp/kolla-operations.tar.gz https://github.com/osism/kolla-operations/tarball/main ${"\\"}
    && mkdir -p /operations ${"\\"}
    && tar --strip-components=1 -xvzf /tmp/kolla-operations.tar.gz -C /operations ${"\\"}
    && rm -f /tmp/kolla-operations.tar.gz
{% endblock %}

{% block keystone_footer %}
RUN python3 -m pip --no-cache-dir install keystone-keycloak-backend
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends ${"\\"}
           libapache2-mod-shib ${"\\"}
           libapache2-mod-auth-openidc ${"\\"}
           libldap-common ${"\\"}
           libmemcached11 ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/* ${"\\"}
    && a2enmod auth_openidc ${"\\"}
    && a2dismod shib ${"\\"}
    && rm -f /etc/apache2/conf-enabled/shib.conf
{% endblock %}

{% block footer %}
RUN rm -rf /usr/share/doc/* ${"\\"}
    && rm -rf /usr/share/man/* ${"\\"}
    && apt-get remove -y build-essential ${"\\"}
    && apt-get autoremove -y ${"\\"}
    && if [ -e /var/lib/kolla/venv/bin/python3 ]; then /var/lib/kolla/venv/bin/pip3 install --no-cache-dir pyclean==3.0.0; /var/lib/kolla/venv/bin/pyclean /var/lib/kolla/venv; /var/lib/kolla/venv/bin/pyclean /usr; /var/lib/kolla/venv/bin/pip3 uninstall -y pyclean; fi
{% endblock %}

{% block labels %}
LABEL "build-date"="{{ build_date }}" ${"\\"}
      "name"="{{ image_name }}" ${"\\"}
      "de.osism.commit.docker_images_kolla"="${hash_docker_images_kolla}" ${"\\"}
      "de.osism.commit.kolla"="${hash_kolla}" ${"\\"}
      "de.osism.commit.kolla_version"="${kolla_version}" ${"\\"}
      "de.osism.commit.release"="${hash_release}" ${"\\"}
      "de.osism.os_id"="${base}" ${"\\"}
      "de.osism.os_version_id"="${base_tag}" ${"\\"}
      "de.osism.release.openstack"="${openstack_version}" ${"\\"}
      "de.osism.version"="${version}" ${"\\"}
      "org.opencontainers.image.created"="${created}" ${"\\"}
      "org.opencontainers.image.documentation"="https://osism.tech/docs/" ${"\\"}
      "org.opencontainers.image.licenses"="ASL 2.0" ${"\\"}
      "org.opencontainers.image.source"="https://github.com/osism/container-images-kolla" ${"\\"}
      "org.opencontainers.image.title"="{{ image_name }}" ${"\\"}
      "org.opencontainers.image.url"="https://quay.io/organization/osism" ${"\\"}
      "org.opencontainers.image.vendor"="OSISM GmbH"
{% endblock %}

{% block ovs_install %}
COPY --from=osism.harbor.regio.digital/packages/ovs-ubuntu-noble:v3.4.3 /*.deb /tmp/packages/
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends ${"\\"}
        python3-netifaces ${"\\"}
        tcpdump ${"\\"}
    && apt-get install -y -f /tmp/packages/openvswitch-common*.deb ${"\\"}
    && apt-get install -y -f /tmp/packages/python3-openvswitch*.deb ${"\\"}
    && apt-get install -y -f /tmp/packages/openvswitch-switch*.deb ${"\\"}
    && rm -rf /tmp/packages ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*
{% endblock %}
