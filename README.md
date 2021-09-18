Template
========

[![Build](https://github.com/reznikmm/template/workflows/Build/badge.svg)](https://github.com/reznikmm/template/actions)
[![REUSE status](https://api.reuse.software/badge/github.com/reznikmm/template)](https://api.reuse.software/info/github.com/reznikmm/template)

> A template repo for Ada projects

This repository keeps common stuff that probably useful for Ada projects, including:

* `README.md` - this README template
* `gnat/` - gnat project files for a library and an executable
* `source/` - trivial Ada units
* `Makefile` - `make` instructions file to build and install projects
* `.copr/` - a Makefile and RPM spec template to build with [COPR](copr.fedorainfracloud.org)
* `.reuse/` - a template for license settings to be [REUSE](https://reuse.software) compliant
* `.github/workflows` - [GitHub Actions](https://docs.github.com/en/actions) script to check [REUSE](https://reuse.software) policies and compile

## Install

Run
```
make all install PREFIX=/path/to/install
```

### Dependencies
It depends on [Matreshka](https://forge.ada-ru.org/matreshka) library.

## Usage

Copy files from the repository to your project and adjust their content.
To make `REUSE` badge work register the repo [here](https://api.reuse.software/register).

To make `COPR` work create new build with
 * Clone URL: https://github.com/reznikmm/template.git
 * Path to .spec file: .copr/template.spec
 * Build SRPM with: `make_srpm`

To use this template library just add `with "template";` to your project file.

## Maintainer

[Max Reznik](https://github.com/reznikmm).

## Contribute

Feel free to dive in!
[Open an issue](https://github.com/reznikmm/template/issues/new)
or submit PRs.

## License

[MIT](LICENSE) © Maxim Reznik

