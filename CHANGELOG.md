# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file was started on December 08, 2025. Changes prior to this date are not included in the CHANGELOG.

## [v0.20261008.0] - 2026-10-08

### Fixed
- Install the Ceph client from download.ceph.com to fix client/cluster connection failures with aes256k cephx keys (osism/container-images-kolla#808)

### Dependencies
- mako 1.4.1 → 1.4.2 (osism/container-images-kolla#809)

## [v0.20261001.0] - 2026-10-01

### Added
- Add builds for 2026.1 (osism/container-images-kolla#774)
- Add ACME dns-01 challenge support to the letsencrypt-lego image, selectable via a new `--challenge` option alongside the existing http-01 default and the --dns-provider, --dns-additional-opts, and --env-file options (osism/container-images-kolla#780, osism/container-images-kolla#797)
- Record per-image push attempt logs (duration, exit status, size, layer count) to diagnose failing nightly push jobs (osism/container-images-kolla#798)
- Backport image size handling fix for glance image import to prevent dynamic backing image volume resizing during copy (2025.1, 2025.2) (osism/container-images-kolla#802)
- Install pykmip for the Barbican kmip_plugin and pin PyKMIP 0.11.0 for Python 3.12 based images to fix KMIP server connections (2024.1, 2024.2, 2025.1, 2025.2, 2026.1) (osism/container-images-kolla#807)

### Changed
- Use registry.osism.tech instead of registry.osism.cloud in compare-sbom.py (osism/container-images-kolla#777)
- Keystone: drop 2024.1 CVE patches for user impersonation, trust operations, federated token rescoping, and RBAC policy bypass now included upstream in the unmaintained/2024.1 tarball (osism/container-images-kolla#779)
- Templates: fail the build when `pip check` detects broken or conflicting requirements in the venv (osism/container-images-kolla#784)
- Refresh glance patches that needed a rebase and drop patches already merged upstream (osism/container-images-kolla#792)
- Drop glance patches for web-download size limiting, SSRF host restriction, and HTTP location SSRF protection, now merged upstream (osism/container-images-kolla#793)
- Drop keystone patch for system-scoped token rescope guard, now merged upstream (osism/container-images-kolla#793)

### Fixed
- keystone: add patches for CVEs and backports, drop a 2024.1 patch merged upstream (osism/container-images-kolla#776)
- Keystone: add 2024.1 patches closing CVE-2026-42998, CVE-2026-43000, CVE-2026-44394, and CVE-2026-42999, plus fixes for delegated-token trust, application-credential, and OAuth1 escalation bugs (osism/container-images-kolla#778)
- Keystone: constrain keycloak-backend pip install to upper-constraints to prevent unconstrained cryptography/jwcrypto upgrades from breaking keystone startup (osism/container-images-kolla#781)
- Add keystone patches for 2024.2 fixing CVEs where delegated tokens (application credentials, OAuth1, EC2) could bypass trust, application credential, and token-rescoping restrictions (osism/container-images-kolla#782)
- Keystone: reject EC2 credential tokens from all Keystone API operations except token validation and reauthentication (osism/container-images-kolla#783)
- Prepare script now fails the build on git clone or checkout failure instead of silently continuing, which previously surfaced as misleading "no file to patch" errors, and falls back to HTTP/1.1 on intermittent GitHub clone rejections (osism/container-images-kolla#787)
- Add glance patches fixing SSRF via restricted-address import URIs, DNS rebinding on import downloads, and unbounded web-download fetch size (osism/container-images-kolla#789)
- Scope the pip check build gate to conflicts owned by the venv, so apt-side package conflicts no longer fail the build (osism/container-images-kolla#786)
- Limit glance web-download image fetch size to the configured image_size_cap, preventing disk exhaustion when a remote source omits Content-Length (osism/container-images-kolla#790)
- Block glance web-download import URIs targeting loopback, link-local, or other restricted addresses to prevent SSRF against local services and cloud metadata endpoints (osism/container-images-kolla#790)
- Pin glance import downloads to the validated destination address and re-validate at fetch time to close a DNS rebinding window between URI validation and image download (osism/container-images-kolla#790)
- Glance 2024.1: add CVE patches fixing SSRF vulnerabilities in image import (web-download redirect bypass, IP address encoding bypass, glance-download redirect bypass, OVF processing, unbounded web-download fetch size) (osism/container-images-kolla#790)
- Fix re-push of mismatched images publishing the previously pulled image instead of the newly built one (osism/container-images-kolla#798)
- Restore push error output to the job log after it stopped appearing due to the push logging changes (osism/container-images-kolla#799)
- Fix mariadb backup scripts leaving partial archives that looked complete after a failed or killed backup run (osism/container-images-kolla#801)
- Fix Octavia HAProxy configuration injection via tls_ciphers and L7 policy redirect fields (OSSA-2026-039) (osism/container-images-kolla#803)

### Removed
- Keystone patches that were merged upstream (osism/container-images-kolla#785)
- Drop keystone ec2credential token-ban patch now merged upstream (osism/container-images-kolla#789)
- Drop glance patch pinning image import downloads to validated destination addresses, now merged upstream (osism/container-images-kolla#794)
- Drop glance patch blocking restricted hosts when adding HTTP image locations, now merged upstream (osism/container-images-kolla#795)
- Drop kolla-operations unpacking from the grafana image footer (2024.2, 2025.1, 2025.2, 2026.1) (osism/container-images-kolla#800)
- Drop 2025.2 glance backport patch that no longer applies since it was merged upstream (osism/container-images-kolla#805)

### Dependencies
- setuptools 83.0.0 → 84.0.0 (osism/container-images-kolla#773)
- ansible 14.2.0 → 14.3.1 (osism/container-images-kolla#772, osism/container-images-kolla#775)
- ansible 14.3.1 → 14.4.0 (osism/container-images-kolla#796)

## [v0.20260814.0] - 2026-08-14

### Added
- Fail the build when a patch file exists but was never applied, via a new patch manifest and end-of-build verification step (osism/container-images-kolla@823ec2f)

### Changed
- Re-enable building neutron images for 2024.1, needed again after the CVE-2026-55707 fix (osism/container-images-kolla#761)
- Enable building designate images for 2024.1, required for the backported CVE fixes (osism/container-images-kolla#769)

### Fixed
- Add nova patches for CVE-2026-46448 to strip internal `_nova`-prefixed scheduler hints on instance create (osism/container-images-kolla#741)
- Fix project-board automation for fork PRs so they are added to the project board (osism/container-images-kolla#744)
- Pin valkey to the deployable valkey-server image via SBOM_IMAGE_TO_VERSION so the version pin no longer silently falls back to the OpenStack release version (osism/container-images-kolla#745)
- Add nova patches for OSSN-0101 to stop the websocket proxy from mutating the global allowed-origins config with request Host headers (osism/container-images-kolla#746)
- Add neutron patches for OSSN-0102 to fix cross-project access to router conntrack helpers and floating IP port forwarding (osism/container-images-kolla#746)
- Backport a NetApp NVMe/TCP multipath fix (bug #2121791) to cinder for 2025.1 and 2025.2 so initialize_connection returns all available target portals, and refresh existing 2025.1 NetApp NVMe backport patches (osism/container-images-kolla#756)
- Fix CVE-2026-55707 in neutron preventing non-admin users from onboarding subnets of networks they don't own, for 2024.1, 2024.2, 2025.1 and 2025.2 (osism/container-images-kolla#758)
- Fix 2024.1 images silently building from frozen stable-2024.1 sources by selecting the unmaintained/2024.1 requirements tarball, which opendev keeps refreshing (osism/container-images-kolla#762)
- Append files added by patches and overlays to SOURCES.txt so pbr includes them (e.g. alembic migrations) in the built venv instead of silently dropping them (osism/container-images-kolla#763)
- Match patch and overlay directories across hyphen/underscore spelling variants so PEP 625-normalized sdists (e.g. neutron-dynamic-routing) resolve correctly (osism/container-images-kolla@7055983)
- Designate: fix mDNS record query pool scoping so split-horizon DNS deployments with the same zone name in multiple pools no longer get erroneous REFUSED responses (2024.1, 2024.2) (osism/container-images-kolla#769)
- Designate: require TSIG keys for zones scheduled to non-default pools, preventing zones from silently failing AXFR sync and getting stuck in ERROR status (2024.1, 2024.2) (osism/container-images-kolla#769)
- Designate: fix a cross-tenant/cross-pool zone ownership bypass allowing duplicate-name, subzone and superzone checks to be evaded by scheduling a zone to a different pool, and fix the related ambiguous mDNS/NOTIFY zone lookups it exploited (2024.1) (osism/container-images-kolla#769)

### Removed
- Drop nova 2025.1 and 2025.2 CVE-2026-46448 patches, merged upstream (osism/container-images-kolla#742)
- Drop nova OSSN-0101 websocket proxy config-mutation patch for 2025.1 and 2025.2, merged upstream (osism/container-images-kolla#748, osism/container-images-kolla#752)
- Drop neutron CVE-2026-55707 patches for 2025.1 and 2025.2, merged upstream (osism/container-images-kolla#759)
- Drop neutron CVE-2026-55707 patch for 2024.1, merged upstream (osism/container-images-kolla#760)
- Drop 2024.1 neutron, keystone and nova patches merged upstream into unmaintained/2024.1: neutron router conntrack helper cross-project access fix (CVE-2026-55707), keystone EC2/S3 token auth hardening patches, and nova websocket proxy origin-poisoning and scheduler-hint stripping fixes (CVE-2026-46448) (osism/container-images-kolla#762)
- Drop 2025.1 keystone patch blocking application credential token rescoping to system scope, merged upstream (osism/container-images-kolla#764)
- Drop 2024.2 skyline patch adding TLSv1.2/TLSv1.3 support for HTTPS upstream endpoints, merged upstream (osism/container-images-kolla#765)

### Dependencies
- ansible 11.12.0 → 14.2.0 (osism/container-images-kolla#671, osism/container-images-kolla#754, osism/container-images-kolla#755)
- docker 7.1.0 → 7.2.0 (osism/container-images-kolla#749)
- mako 1.3.10 → 1.4.1 (osism/container-images-kolla#717, osism/container-images-kolla#768)
- packaging 26.0 → 26.3 (osism/container-images-kolla#716, osism/container-images-kolla#767)
- requests 2.32.5 → 2.34.2 (osism/container-images-kolla#706, osism/container-images-kolla#743)
- setuptools 80.10.2 → 83.0.0 (osism/container-images-kolla#751)
- tabulate 0.9.0 → 0.10.0 (osism/container-images-kolla#701)

## [v0.20260615.0] - 2026-06-15

### Added
- Add workflow to automatically add opened issues and PRs to the project board (osism/container-images-kolla#723)

### Changed
- Re-enable glance and keystone image builds for 2024.1 (osism/container-images-kolla#710)
- Reformat code to comply with black 26.3.1 style (osism/container-images-kolla#718)
- Add retries and a DNS pre-check to tarball downloads to reduce transient failures (osism/container-images-kolla#721)
- Revert MariaDB version pin now that the MDEV-39685 fix is available upstream (osism/container-images-kolla#733)

### Fixed
- Fix unauthorized EC2 credential creation and deletion in keystone (CVE-2026-33551, OSSA-2026-005) for 2024.1, 2024.2, 2025.1 and 2025.2 (osism/container-images-kolla#712)
- Fix backport-951347.patch for 2025.1 to match upstream proxysql requirements change (osism/container-images-kolla#713)
- Fix keystonemiddleware.patch context for 2024.2 and 2025.1 after upstream requirements tarball updates (osism/container-images-kolla#719, osism/container-images-kolla#722)
- Fix NVMeOF device path retrieval in extend_volume by patching os-brick for 2025.1 and 2025.2 (osism/container-images-kolla#724)
- Fix 2024.2 build by checking out the 2024.2-eol tag on the now-EOL branch (osism/container-images-kolla#728)
- Pin MariaDB to pre-MDEV-39685 versions to prevent Galera multi-table UPDATE crashes during Octavia deployment for 2024.2, 2025.1 and 2025.2 (osism/container-images-kolla#725)
- Keystone: Add patches for multiple CVEs (osism/container-images-kolla#731)
- Add missing semaphore for 2025.2 push job (osism/container-images-kolla#732)
- Pin proxysql to 3.0.8 to prevent the keepalived health check from failing and dropping the api-int VIP after proxysql 3.0.9 changed its handling of malformed first packets (GHSA-58ww-865x-grpr) (osism/container-images-kolla#735)
- Log the discarded pull error in check-and-repush so digest-mismatch failures during registry pulls can be diagnosed (osism/container-images-kolla#740)

### Removed
- Drop keystone CVE-2026-33551 patches for 2024.2, 2025.1 and 2025.2, merged upstream (osism/container-images-kolla#714)
- Remove unused 2024.2 aarch64 build and push jobs (osism/container-images-kolla#730)
- Drop keystone 2025.2 local patches for CVE-2026-42998 and CVE-2026-44394 fixes now merged upstream (osism/container-images-kolla#736, osism/container-images-kolla#737)
- Drop keystone bug-2148398 patch (CVE-2026-42999 RBAC policy bypass backport), merged upstream for 2025.2 (osism/container-images-kolla#738)
- Drop keystone 2025.1 CVE patches now merged upstream (osism/container-images-kolla#739)

## [v0.20260328.0] - 2026-03-28

### Added
- Add nova scheduler filter patch for aggregate multi-tenancy isolation by domain (2025.2) (osism/container-images-kolla#704)
- Add blazar, heat, and watcher to version tagging and SBOM (osism/container-images-kolla#709)

### Changed
- Enable all 2025.2 container images (osism/container-images-kolla#703, osism/container-images-kolla#704)

### Fixed
- Fix package names for heat and watcher version detection (osism/container-images-kolla#711)

## [v0.20260322.0] - 2026-03-22

### Added
- Add support for building 2025.2 ironic images (osism/container-images-kolla#696)
- Add ironic/backport-968348.patch (osism/container-images-kolla#694)

### Changed
- Re-enable 2024.1 image builds, limited to nova images (osism/container-images-kolla#687)
- Extend 2025.2 image list with redis, rabbitmq, mariadb, keystone, memcached, cron, kolla-toolbox and fluentd required by metalbox (osism/container-images-kolla#699, osism/container-images-kolla#700)

### Fixed
- Nova: Enforce qemu-img format on disk resize to fix CVE-2026-24708 for 2024.1, 2024.2 and 2025.1 (osism/container-images-kolla#688)
- 2024.2: Fix python-magnumclient version constraint in magnumclient patch (osism/container-images-kolla#684)
- Ironic 2024.2: Allow project scope for the node:disable_cleaning policy (osism/container-images-kolla#689)
- Ironic 2024.2: Log secure boot access failures at info level instead of raising (osism/container-images-kolla#693)
- Skip SBOM comparison gracefully instead of failing when no remote SBOM image exists yet, including when a registry returns HTTP 500 with "not found" instead of a proper 404 (osism/container-images-kolla#697, osism/container-images-kolla#698)
- Allow node lookup during in-band servicing by adding the service-wait state to lookup allowed states for 2024.2, 2025.1 and 2025.2 (osism/container-images-kolla#702)

### Removed
- Revert proxysql version pin workaround now that proxysql 3.0.5 fixes the keystone db bootstrap error upstream (osism/container-images-kolla#682)
- Drop nova cve-2026-24708 patches for 2024.1, 2024.2 and 2025.1 now merged upstream (osism/container-images-kolla#690, osism/container-images-kolla#691)
- Drop octavia bug-2129562 patch now merged upstream (osism/container-images-kolla#692)
- Revert "Add ironic/backport-968348.patch (#694)" (osism/container-images-kolla#695)

### Dependencies
- setuptools 80.10.1 → 80.10.2 (osism/container-images-kolla#681)

## [v0.20260128.0] - 2026-01-28

### Fixed
- Fix keystone DB bootstrap error caused by proxysql 3.0.4 no longer proxying `select version()` to the backend by pinning proxysql to 3.0.3 (osism/container-images-kolla#675)
- Fix CVE-2026-22797 in keystonemiddleware (OSSA-2026-001) by updating keystonemiddleware to 10.12.1 for 2024.1, 2024.2 and 2025.1 (osism/container-images-kolla#677)
- Fix infinite database connection retry loop in the Octavia Health Worker for 2024.2 and 2025.1 (osism/container-images-kolla#680)

### Removed
- Remove Shibboleth module from keystone images, keeping only OpenID Connect authentication (osism/container-images-kolla#676)

### Dependencies
- setuptools 80.9.0 → 80.10.1 (osism/container-images-kolla#678)
- packaging 25.0 → 26.0 (osism/container-images-kolla#679)

## [v0.20251208.0] - 2025-12-08

### Added
- Add mdevctl package to nova-libvirt images for 2024.2 (osism/container-images-kolla#668)

### Changed
- Add OpenStack version to release image namespace for release builds (osism/container-images-kolla#672)

### Fixed
- Fix backport-951347.patch for 2025.1 after proxysql repo baseurl change (osism/container-images-kolla#670)
- Fix duplicate release namespace in SBOM image paths (osism/container-images-kolla#673)

### Removed
- Remove neutron backport-968646 patch for allowed_address_pairs CIDR fix, merged upstream (osism/container-images-kolla#669)

