# SPDX-FileCopyrightText: 2021 Max Reznik <reznikmm@gmail.com>
#
# SPDX-License-Identifier: MIT
#

%undefine _hardened_build
%define _gprdir %_GNAT_project_dir
%define rtl_version 0.1

Name:       template
Version:    0.1.0
Release:    git%{?dist}
Summary:    Grammar handling and parser generation Ada library
Group:      Development/Libraries
License:    MIT
URL:        https://github.com/reznikmm/template
### Direct download is not availeble
Source0:    template.tar.gz
BuildRequires:   gcc-gnat
BuildRequires:   fedora-gnat-project-common  >= 3 
BuildRequires:   matreshka-devel
BuildRequires:   gprbuild

# gprbuild only available on these:
ExclusiveArch: %GPRbuild_arches

%description
The template is a library for ...

%package devel

Group:      Development/Libraries
License:    MIT
Summary:    Devel package for the template
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:   fedora-gnat-project-common  >= 2

%description devel
Devel package for template

%package run
Summary:    Run executable for template
License:    MIT
Group:      System Environment/Libraries
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description run
This an executable for the template

%prep 
%setup -q -n %{name}

%build
make  %{?_smp_mflags} GPRBUILD_FLAGS="%Gnatmake_optflags"

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot} LIBDIR=%{_libdir} PREFIX=%{_prefix} GPRDIR=%{_gprdir} BINDIR=%{_bindir}

%check
make  %{?_smp_mflags} GPRBUILD_FLAGS="%Gnatmake_optflags" check

%post     -p /sbin/ldconfig
%postun   -p /sbin/ldconfig

%files
%doc LICENSES/*
%dir %{_libdir}/%{name}
%{_libdir}/%{name}/libtemplate.so.%{rtl_version}
%{_libdir}/libtemplate.so.%{rtl_version}
%{_libdir}/%{name}/libtemplate.so.0
%{_libdir}/libtemplate.so.0
%files devel
%doc README.md
%{_libdir}/%{name}/libtemplate.so
%{_libdir}/libtemplate.so
%{_libdir}/%{name}/*.ali
%{_includedir}/%{name}
%{_gprdir}/template.gpr
%{_gprdir}/manifests/template

%files run
%{_bindir}/template-run
%{_gprdir}/manifests/template_run

%changelog
* Sun Feb 28 2021 Maxim Reznik <reznikmm@gmail.com> - 0.1.0-git
- Initial package
