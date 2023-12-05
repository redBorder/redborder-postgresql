%undefine __brp_mangle_shebangs

Name: redborder-postgresql
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Package for redborder containing scripts and libs to control postgresql on Master MultiSlave mode.

License: AGPL 3.0
URL: https://github.com/redBorder/redborder-postgresql
Source0: %{name}-%{version}.tar.gz

Requires: bash redborder-rubyrvm redborder-common

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/usr/lib/redborder/bin
mkdir -p %{buildroot}/usr/lib/redborder/scripts
mkdir -p %{buildroot}/usr/lib/redborder/lib

cp resources/bin/* %{buildroot}/usr/lib/redborder/bin
cp resources/scripts/* %{buildroot}/usr/lib/redborder/scripts

chmod 0755 %{buildroot}/usr/lib/redborder/bin/*
chmod 0755 %{buildroot}/usr/lib/redborder/scripts/*

install -D -m 0644 resources/lib/poll_lib.rb %{buildroot}/usr/lib/redborder/lib
install -D -m 0644 resources/lib/agent_pg_lib.rb %{buildroot}/usr/lib/redborder/lib
install -D -m 644 resources/systemd/redborder-postgresql.service %{buildroot}/usr/lib/systemd/system/redborder-postgresql.service


%pre

%post
/usr/lib/redborder/bin/rb_rubywrapper.sh -c
systemctl daemon-reload

%files
%defattr(0755,root,root)
/usr/lib/redborder/bin
/usr/lib/redborder/scripts
%defattr(0644,root,root)
/usr/lib/redborder/lib/agent_pg_lib.rb
/usr/lib/redborder/lib/poll_lib.rb
/usr/lib/systemd/system/redborder-postgresql.service

%doc

%changelog
* Tue Dec 05 2023 David Vanhoucke <dvanhoucke@redborder.com> - 0.0.3-1
- Add grant access script
* Fri Feb 10 2017 Juan J. Prieto <jjprieto@redborder.com> - 0.0.1-1
- first spec version
