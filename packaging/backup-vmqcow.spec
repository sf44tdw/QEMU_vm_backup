%{!?pkg_version:%global pkg_version 0.1.0}

Name:           backup-vmqcow
Version:        %{pkg_version}
Release:        1%{?dist}
Summary:        Backup shut-off QEMU virtual machines
License:        GPL-3.0-or-later
BuildArch:      noarch

Source0:        backup_vmqcow.sh
Source1:        LICENSE

Requires:       bash
Requires:       coreutils
Requires:       findutils
Requires:       gawk
Requires:       grep
Requires:       libvirt-client
Requires:       pigz
Requires:       procps-ng
Requires:       sed
Requires:       tar

%description
Creates an archive of shut-off QEMU virtual machines and their qcow2 disk
images using libvirt.

%prep

%build

%install
install -Dpm0755 %{SOURCE0} %{buildroot}%{_bindir}/backup_vmqcow.sh
install -Dpm0644 %{SOURCE1} %{buildroot}%{_licensedir}/%{name}/LICENSE

%files
%license %{_licensedir}/%{name}/LICENSE
%{_bindir}/backup_vmqcow.sh
