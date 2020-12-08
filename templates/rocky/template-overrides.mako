{% extends parent_template %}

{% set base_apt_keys_append = ['0A9AF2115F4687BD29803A206B73A36E6026DFCA'] %}

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

{% set kolla_toolbox_packages_append = ['iputils-ping', 'traceroute'] %}

{% set cinder_volume_packages_append = ['multipath-tools'] %}

{% set cinder_volume_pip_packages = ['purestorage' ] %}
{% block cinder_volume_footer %}
RUN {{ macros.install_pip(cinder_volume_pip_packages | customizable("pip_packages")) }}
{% endblock %}

{% set rabbitmq_packages_remove = ['https://www.rabbitmq.com/releases/rabbitmq-server/v3.6.5/rabbitmq-server_3.6.5-1_all.deb'] %}
{% set rabbitmq_packages_append = ['erlang-base-hipe', 'rabbitmq-server', 'wget'] %}

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

{% block horizon_footer %}
RUN pip --no-cache-dir install MySQL-python
{% endblock %}

{% block keystone_footer %}
RUN apt-get update ${"\\"}
    && apt-get -y install --no-install-recommends ${"\\"}
           libapache2-mod-auth-openidc ${"\\"}
    && apt-get clean ${"\\"}
    && rm -rf /var/lib/apt/lists/* ${"\\"}
    && a2enmod auth_openidc
{% endblock %}

{% block elasticsearch_footer %}
RUN elasticsearch-plugin install -b https://github.com/vvanholl/elasticsearch-prometheus-exporter/releases/download/${infrastructure_projects['elasticsearch']}.0/prometheus-exporter-${infrastructure_projects['elasticsearch']}.0.zip
{% endblock %}

{% block kibana_footer %}
RUN kibana-plugin install https://github.com/sivasamyk/logtrail/releases/download/v${integrated_projects['logtrail']}/logtrail-${infrastructure_projects['kibana']}-${integrated_projects['logtrail']}.zip
COPY logtrail.json /usr/share/kibana/plugins/logtrail/logtrail.json
{% endblock %}

{% block rabbitmq_footer %}
 RUN curl -L -o /usr/lib/rabbitmq/lib/rabbitmq_server-3.6/plugins/accept-${integrated_projects['prometheus_rabbitmq_exporter_accept']}.ez https://github.com/deadtrickster/prometheus_rabbitmq_exporter/releases/download/rabbitmq-${integrated_projects['prometheus_rabbitmq_exporter_release']}/accept-${integrated_projects['prometheus_rabbitmq_exporter_accept']}.ez ${"\\"}
     && curl -L -o /usr/lib/rabbitmq/lib/rabbitmq_server-3.6/plugins/prometheus-${integrated_projects['prometheus_rabbitmq_exporter_prometheus']}.ez https://github.com/deadtrickster/prometheus_rabbitmq_exporter/releases/download/rabbitmq-${integrated_projects['prometheus_rabbitmq_exporter_release']}/prometheus-${integrated_projects['prometheus_rabbitmq_exporter_prometheus']}.ez ${"\\"}
     && curl -L -o /usr/lib/rabbitmq/lib/rabbitmq_server-3.6/plugins/prometheus_httpd-${integrated_projects['prometheus_rabbitmq_exporter_prometheus_httpd']}.ez https://github.com/deadtrickster/prometheus_rabbitmq_exporter/releases/download/rabbitmq-${integrated_projects['prometheus_rabbitmq_exporter_release']}/prometheus_httpd-${integrated_projects['prometheus_rabbitmq_exporter_prometheus_httpd']}.ez ${"\\"}
     && curl -L -o /usr/lib/rabbitmq/lib/rabbitmq_server-3.6/plugins/prometheus_rabbitmq_exporter-v${integrated_projects['prometheus_rabbitmq_exporter_release']}.ez https://github.com/deadtrickster/prometheus_rabbitmq_exporter/releases/download/rabbitmq-${integrated_projects['prometheus_rabbitmq_exporter_release']}/prometheus_rabbitmq_exporter-v${integrated_projects['prometheus_rabbitmq_exporter_release']}.ez ${"\\"}
     && curl -L -o /usr/lib/rabbitmq/lib/rabbitmq_server-3.6/plugins/prometheus_process_collector-${integrated_projects['prometheus_rabbitmq_exporter_prometheus_process_collector']}.ez https://github.com/deadtrickster/prometheus_rabbitmq_exporter/releases/download/rabbitmq-${integrated_projects['prometheus_rabbitmq_exporter_release']}/prometheus_process_collector-${integrated_projects['prometheus_rabbitmq_exporter_prometheus_process_collector']}.ez ${"\\"}
     && rabbitmq-plugins enable --offline accept ${"\\"}
     && rabbitmq-plugins enable --offline prometheus ${"\\"}
     && rabbitmq-plugins enable --offline prometheus_httpd ${"\\"}
     && rabbitmq-plugins enable --offline prometheus_rabbitmq_exporter ${"\\"}
     && rabbitmq-plugins enable --offline prometheus_process_collector
{% endblock %}

{% block skydive_install %}
RUN curl -o /usr/bin/skydive -L "https://github.com/skydive-project/skydive/releases/download/v${infrastructure_projects['skydive']}/skydive" ${"\\"}
    && chmod +x /usr/bin/skydive
{% endblock %}

{% block cloudkitty_processor_footer %}
# NOTE: https://github.com/ultrajson/ultrajson/issues/346
RUN pip install git+git://github.com/esnme/ultrajson.git
{% endblock %}

{% block ceilometer_notification_footer %}
# NOTE: https://github.com/ultrajson/ultrajson/issues/346
RUN pip install git+git://github.com/esnme/ultrajson.git
{% endblock %}

{% block gnocchi_api_footer %}
# NOTE: https://github.com/ultrajson/ultrajson/issues/346
RUN pip install git+git://github.com/esnme/ultrajson.git
{% endblock %}

{% block footer %}
RUN rm -rf /usr/share/doc/* ${"\\"}
    && rm -rf /usr/share/man/*

LABEL "de.osism.version"="${osism_version}" ${"\\"}
      "de.osism.release.openstack"="${openstack_version}" ${"\\"}
      "de.osism.commit.docker_images_kolla"="${hash_docker_images_kolla}" ${"\\"}
      "de.osism.commit.kolla"="${hash_kolla}" ${"\\"}
      "de.osism.commit.release"="${hash_release}" ${"\\"}
      "org.opencontainers.image.created"="${created}" ${"\\"}
      "org.opencontainers.image.documentation"="https://docs.osism.de" ${"\\"}
      "org.opencontainers.image.licenses"="ASL 2.0" ${"\\"}
      "org.opencontainers.image.source"="https://github.com/osism/docker-images-kolla" ${"\\"}
      "org.opencontainers.image.title"="{{ image_name }}" ${"\\"}
      "org.opencontainers.image.url"="https://www.osism.de" ${"\\"}
      "org.opencontainers.image.vendor"="Betacloud Solutions GmbH" ${"\\"}
      "org.opencontainers.image.version"="${osism_version}"
{% endblock %}
