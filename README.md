# homebrew-sdr

Homebrew tap to keg off additional formulae related to [SDR](https://en.wikipedia.org/wiki/Software-defined_radio).

## Tap

```bash
brew tap gretel/sdr
```

Formulae are then available as `gretel/sdr/<formula>`.

## Drop-in replacement policy

Every formula in this tap is intended as a drop-in replacement for
its homebrew-core or `pothosware/pothos` counterpart. Same formula
names, same install layout (headers, libs, `.pc`, `.cmake`), same
plugin paths — so existing consumers (GNU Radio, SoapySDR utils,
SDRangel) keep working without reconfiguration.

Where two kegs would collide, the replacement is declared with
`conflicts_with` so `brew` refuses cleanly instead of failing at
link time. Switching between stock and this tap therefore looks
like:

```bash
brew uninstall <stock>; brew install gretel/sdr/<replacement>
```

**RPATH caveat:** consumers of `libuhd` (e.g. `soapyuhd`,
`gnuradio`) bake the absolute Cellar path of the keg they were
built against into their RPATH. Two formulae cannot share a Cellar
directory (`Cellar/uhd/...` vs `Cellar/uhd-oc/...`), so switching
between `uhd` and `uhd-oc` requires reinstalling every consumer:

```bash
brew reinstall gretel/sdr/soapyuhd gnuradio
```

## Formulae

### [`libiio`](https://github.com/analogdevicesinc/libiio) — 0.26

Analog Devices' C library for reading and writing Linux IIO
(Industrial I/O) devices: ADCs, DACs, sensors, and RF transceivers
that expose themselves through the kernel IIO subsystem. The
foundation for talking to any ADI hardware from userspace — over
USB, over the network, or against a local sysfs tree.

### [`libad9361-iio`](https://github.com/analogdevicesinc/libad9361-iio) — 0.3

*Depends on: `libiio`*

Helper library on top of `libiio` for the AD9361 — the wideband RF
transceiver chip inside the ADALM-PLUTO SDR and many AD9361
development boards. Handles baseband rate setup, filter
programming, and other AD9361-specific configuration that plain
`libiio` can't do.

### [`uhd-oc`](https://github.com/EttusResearch/uhd) — 4.10.0.0-oc

Ettus UHD — the driver suite for USRP radios — patched to raise
the internal AD9361 clock ceiling from 61.44 MS/s to 122.88 MS/s.
Used with B200, B210, and B220 devices to push beyond the
officially supported sample rates. The overclock patch is from
[MothMaux/uhd-oc](https://github.com/MothMaux/uhd-oc) and is
applied at build time; no FPGA or firmware changes.

**Conflicts with the stock `uhd` formula** — you must
`brew uninstall uhd` first.

### [`soapyplutopapr`](https://github.com/F5OEO/SoapyPlutoPAPR) — 0.2.2+git.20260420

*Depends on: `libiio`, `libad9361-iio`*

A SoapySDR module for the PlutoSDR. SoapySDR is the vendor-neutral
SDR abstraction layer used by GNU Radio, CubicSDR, SDRangel, and
similar tools. This fork of the upstream Pluto plugin adds CS8 and
CS12 streaming sample formats on top of the usual float32 — useful
when USB bandwidth becomes the bottleneck at high sample rates, or
when passing samples through a gateway that prefers fixed-point.

### [`soapyuhd`](https://github.com/pothosware/SoapyUHD) — 0.4.2

*Depends on: `uhd-oc` (or stock `uhd`)*

SoapySDR plugin that exposes UHD/USRP devices through the
SoapySDR abstraction layer, making them available to any tool
that uses SoapySDR (GNU Radio, CubicSDR, SDRangel, etc.).
Works with either stock `uhd` or `gretel/sdr/uhd-oc` — install
whichever is present before installing this formula.
