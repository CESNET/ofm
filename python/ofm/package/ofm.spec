%global pkg_name ofm
%global pkg_sitename ofm
%global pkg_version 0.0.1
%global pkg_release 1

Name:           %{pkg_name}
Version:        %{pkg_version}
Release:        %{pkg_release}%{?dist}
Source0:        %{pkg_name}-%{pkg_version}.tar.gz
Summary:        Open FPGA Modules package
License:        Copyright (C) CESNET z.s.p.o.
URL:            https://github.com/CESNET/ofm
Vendor:         Martin Spinler, CESNET <spinler@cesnet.cz>
Group:          Development/Libraries
BuildArch:      noarch

BuildRequires:	python%{python3_pkgversion}-setuptools
BuildRequires:	python%{python3_pkgversion}-devel

%description
Python modules to control components from the OFM

%prep
%autosetup -n %{pkg_name}-%{pkg_version}
rm -rf %{pkg_name}.egg-info

%build
%py3_build

%install
%py3_install

%files -n %{pkg_name}
%{python3_sitelib}/%{pkg_sitename}/
%{python3_sitelib}/%{pkg_sitename}*.egg-info/

%changelog
