# OFM repository

This repository contains open-source FPGA modules and build system implemented within the development and research activities of CESNET z.s.p.o. in the field of monitoring, security and network infrastructure configuration.

This repository is primarily used within the Network Development Kit (NDK). But it can also be used in other projects.

## Documentation

We use a documentation system based on the [Sphinx tool](https://www.sphinx-doc.org), which compiles complete documentation from source files in the [reStructuredText](https://docutils.sourceforge.io/rst.html) format. The documentation automatically build with each contribution to the devel branch and is available online here:
- [**OFM documentation (public GitHub Pages - built from main branch)**](https://cesnet.github.io/ofm/).
- [**OFM documentation (private GitLab Pages - built from devel branch)**](https://ndk.gitlab.liberouter.org:5051/ofm/).

### How to manually build documentation

First you need to install the sphinx package and theme in python:
```
$ pip3 install --user sphinx
$ pip3 install --user sphinx-vhdl
$ pip3 install --user sphinx_rtd_theme
```

Then the documentation should be able to be generated simply as follows:
```
$ cd doc
$ make html
```

The output is in `doc/build/index.html`

## License

Unless otherwise noted, the content of this repository is available under the BSD 3-Clause License. Please read [LICENSE file](LICENSE).

### Modules/files taken from other sources

- [I2C Master controller](comp/ctrls/i2c_hw/) by Richard Herveille from [opencores.org](https://opencores.org/projects/i2c) in `comp/ctrls/i2c_hw` under something like a BSD license.
- [SPI Master controller](comp/ctrls/spi/) by Jonny Doin from [opencores.org](https://opencores.org/projects/spi_master_slave) in `comp/ctrls/spi` under LGPL license.
- The .ip files located in the `/comp/base/misc/adc_sensors/` folder were generated in Intel Quartus Prime Pro, and their use may be subject to additional license agreements.
- The .ip file `comp/ctrls/sdm_client/mailbox_client.ip` was generated in Intel Quartus Prime Pro, and their use may be subject to additional license agreements.

## Repository Maintainer

- Jakub Cabal, cabal@cesnet.cz
