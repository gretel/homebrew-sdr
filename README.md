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

Each entry below lists the exact upstream pin (tag or commit). For
fork-tracked formulae the gretel fork is the canonical install
source and the original upstream is noted for reference.

### [`libiio`](https://github.com/analogdevicesinc/libiio) — 0.26

**Pinned:** [`analogdevicesinc/libiio` v0.26](https://github.com/analogdevicesinc/libiio/releases/tag/v0.26)

Analog Devices' C library for reading and writing Linux IIO
(Industrial I/O) devices: ADCs, DACs, sensors, and RF transceivers
that expose themselves through the kernel IIO subsystem. The
foundation for talking to any ADI hardware from userspace — over
USB, over the network, or against a local sysfs tree.

### [`libad9361-iio`](https://github.com/analogdevicesinc/libad9361-iio) — 0.4.0

**Pinned:** [`analogdevicesinc/libad9361-iio` v0.4.0](https://github.com/analogdevicesinc/libad9361-iio/releases/tag/v0.4.0)

*Depends on: `libiio`*

Helper library on top of `libiio` for the AD9361 — the wideband RF
transceiver chip inside the ADALM-PLUTO SDR and many AD9361
development boards. Handles baseband rate setup, filter
programming, and other AD9361-specific configuration that plain
`libiio` can't do.

### [`uhd-oc`](https://github.com/EttusResearch/uhd) — 4.10.0.0-oc

**Pinned:**
[`EttusResearch/uhd` v4.10.0.0](https://github.com/EttusResearch/uhd/releases/tag/v4.10.0.0)
+ overclock patch from
[`MothMaux/uhd-oc` @ 4c3086d](https://github.com/MothMaux/uhd-oc/commit/4c3086d)

Ettus UHD — the driver suite for USRP radios — patched to raise
the internal AD9361 clock ceiling from 61.44 MS/s to 122.88 MS/s.
Used with B200, B210, and B220 devices to push beyond the
officially supported sample rates. The overclock patch is applied
at build time; no FPGA or firmware changes.

**Conflicts with the stock `uhd` formula** — you must
`brew uninstall uhd` first.

### [`soapyplutopapr`](https://github.com/gretel/SoapyPlutoPAPR) — 0.2.2+git.20260610

**Pinned:**
[`gretel/SoapyPlutoPAPR` @ d48d4b9](https://github.com/gretel/SoapyPlutoPAPR/commit/d48d4b91ec49e5a4cebfe682df3dc85de84c03c3)
on branch [`feat-setts`](https://github.com/gretel/SoapyPlutoPAPR/tree/feat-setts)
(fork of [`F5OEO/SoapyPlutoPAPR`](https://github.com/F5OEO/SoapyPlutoPAPR), synced with
[`pothosware/SoapyPlutoSDR`](https://github.com/pothosware/SoapyPlutoSDR) master @ fa4b7b0 + feat-setts @ e80d3c6)

*Depends on: `libiio`, `libad9361-iio`*

The `feat-setts` branch carries the full set of fixes: pothosware
master (#76, #77), feat-setts (settings API, CS12, MTU adaptation,
streaming improvements), F5OEO upstream (BB-rate ordering fix),
and `tezuka` driver key. No inreplace patches needed.

### [`soapyuhd`](https://github.com/pothosware/SoapyUHD) — 0.4.2

**Pinned:**
[`pothosware/SoapyUHD` @ 2a5d381](https://github.com/pothosware/SoapyUHD/commit/2a5d381f68fd05d5b3c0e7db56c36892ea99b4ae)
(default), [`gretel/SoapyUHD` master](https://github.com/gretel/SoapyUHD/tree/master)
(`--HEAD`)

*Depends on: `uhd-oc` (or stock `uhd`); `boost` (default only)*

SoapySDR plugin that exposes UHD/USRP devices to any SoapySDR
consumer (GNU Radio, CubicSDR, SDRangel). Works with either stock
`uhd` or `gretel/sdr/uhd-oc` — install whichever first.

Default install is the pothosware upstream pinned by SHA — the
pre-fork baseline. `--HEAD` is the gretel fork (UHD 4.10, C++20,
Boost-free, `BUILD_SOAPY_SUPPORT` toggle); use it to A/B against
upstream, e.g. with or without
[gretel `76f6923`](https://github.com/gretel/SoapyUHD/commit/76f6923f4a2f3d1c92171d03b2b2b81022b35185).
