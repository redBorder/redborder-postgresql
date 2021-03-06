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
cp resources/bin/* %{buildroot}/usr/lib/redborder/bin
chmod 0755 %{buildroot}/usr/lib/redborder/bin/*

%pre

%post
/usr/lib/redborder/bin/rb_rubywrapper.sh -c

%files
%defattr(0755,root,root)
/usr/lib/redborder/bin

%doc

%changelog
* Fri Feb 10 2017 Juan J. Prieto <jjprieto@redborder.com> - 0.0.1-1
- first spec version
