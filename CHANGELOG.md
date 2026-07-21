# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file was started on December 08, 2025. Changes prior to this date are not included in the CHANGELOG.

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

