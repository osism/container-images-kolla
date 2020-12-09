{% extends parent_template %}

{% set openstack_base_pip_packages_append = ['pip', 'git+https://github.com/sapcc/openstack-audit-middleware.git'] %}

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

{% block elasticsearch_header %}
# On systemd-based distributions, the installation scripts will attempt to set
# kernel parameters (e.g., vm.max_map_count); you can skip this by setting the
# environment variable ES_SKIP_SET_KERNEL_PARAMETERS to true.
ENV ES_SKIP_SET_KERNEL_PARAMETERS true

ENV PATH /usr/share/elasticsearch/bin:$PATH

# NOTE(berendt): install jre before elasticsearch because of https://github.com/elastic/elasticsearch/issues/31845
#                this will solve the "subprocess new pre-installation script returned error exit status 1" issue
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends default-jre-headless ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/*
{% endblock %}

{% block kibana_header %}
ENV PATH /usr/share/kibana/bin:$PATH
{% endblock %}

{% block keystone_footer %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends ${"\\"}
           libapache2-mod-auth-openidc ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/* ${"\\"}
    && a2enmod auth_openidc
{% endblock %}

{% block skydive_install %}
RUN curl -o /usr/bin/skydive -L "https://github.com/skydive-project/skydive/releases/download/v${infrastructure_projects['skydive']}/skydive" ${"\\"}
    && chmod +x /usr/bin/skydive
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
      "org.opencontainers.image.source"="https://github.com/osism/docker-images-kolla" ${"\\"}
      "org.opencontainers.image.title"="{{ image_name }}" ${"\\"}
      "org.opencontainers.image.url"="https://www.osism.de" ${"\\"}
      "org.opencontainers.image.vendor"="Betacloud Solutions GmbH" ${"\\"}
      "org.opencontainers.image.version"="${osism_version}"
{% endblock %}
