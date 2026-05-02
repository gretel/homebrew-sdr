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

## Stable = upstream, `--HEAD` = gretel fork

For fork-tracked formulae **where the gretel fork is a strict
superset of upstream** (no driver-name rebrand, no rename in CMake
target / install layout, no test-contract divergence), this tap
uses the following dual-source convention:

- Default `brew install gretel/sdr/<formula>` builds the original
  upstream pinned by SHA — reproducible, useful as a known baseline
  for A/B comparisons against the fork.
- `brew install --HEAD gretel/sdr/<formula>` builds the gretel fork
  from its tracked branch tip, with whatever fork-only patches the
  fork carries.

Implemented with the `stable do` / `head do` block split:

```ruby
stable do
  url "https://github.com/<upstream>/<repo>/archive/<sha>.tar.gz"
  sha256 "..."
  # upstream-only deps and patches go here
end

head do
  url "https://github.com/gretel/<repo>.git", branch: "<fork-branch>"
end
```

Currently used by: [`soapyuhd`](#soapyuhd) (default = pothosware
master pin, `--HEAD` = `gretel/SoapyUHD master`).

**Where the pattern does NOT apply:**

- The formula's identity *is* the fork (e.g. [`uhd-oc`](#uhd-oc) —
  the overclock patch defines the formula; without it, the formula
  collapses into stock `uhd`).
- The fork rebrands the driver name, CMake target, or install path
  (e.g. [`soapyplutopapr`](#soapyplutopapr) — the
  `tezuka` → `plutoPAPR` rename means the F5OEO upstream registers
  a different SoapySDR driver and breaks the formula's test
  contract).
- No upstream fork relationship exists ([`libiio`](#libiio),
  [`libad9361-iio`](#libad9361-iio) — pinned to upstream tags
  directly).

When adding a new fork-tracked formula, document the choice
explicitly: either follow the dual-source pattern above (and
mention it in the formula entry below), or call out why it doesn't
apply.

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

### [`libad9361-iio`](https://github.com/analogdevicesinc/libad9361-iio) — 0.3

**Pinned:** [`analogdevicesinc/libad9361-iio` v0.3](https://github.com/analogdevicesinc/libad9361-iio/releases/tag/v0.3)

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

### [`soapyplutopapr`](https://github.com/gretel/SoapyPlutoPAPR) — 0.2.2+git.20260420

**Pinned:**
[`gretel/SoapyPlutoPAPR` @ 238fba5](https://github.com/gretel/SoapyPlutoPAPR/commit/238fba5b6b49155188c2733ac3a3fe78703ebf47)
on branch [`feature/plutoPAPR`](https://github.com/gretel/SoapyPlutoPAPR/tree/feature/plutoPAPR)
(fork of [`F5OEO/SoapyPlutoPAPR`](https://github.com/F5OEO/SoapyPlutoPAPR))

*Depends on: `libiio`, `libad9361-iio`*

A SoapySDR module for the PlutoSDR. SoapySDR is the vendor-neutral
SDR abstraction layer used by GNU Radio, CubicSDR, SDRangel, and
similar tools. This fork of the upstream Pluto plugin adds CS8 and
CS12 streaming sample formats on top of the usual float32 — useful
when USB bandwidth becomes the bottleneck at high sample rates, or
when passing samples through a gateway that prefers fixed-point.
The gretel fork carries the `tezuka` -> `plutoPAPR` rename and the
`ad9361_set_bb_rate`-before-FPGA-rate ordering fix.

### [`soapyuhd`](https://github.com/pothosware/SoapyUHD) — 0.4.2

**Stable (default):**
[`pothosware/SoapyUHD` @ 2a5d381](https://github.com/pothosware/SoapyUHD/commit/2a5d381f68fd05d5b3c0e7db56c36892ea99b4ae)
on branch [`master`](https://github.com/pothosware/SoapyUHD/tree/master)

**`--HEAD`:**
[`gretel/SoapyUHD` master tip](https://github.com/gretel/SoapyUHD/tree/master)
(fork of [`pothosware/SoapyUHD`](https://github.com/pothosware/SoapyUHD))

*Depends on: `uhd-oc` (or stock `uhd`); `boost` (stable only)*

SoapySDR plugin that exposes UHD/USRP devices through the SoapySDR
abstraction layer, making them available to any tool that uses
SoapySDR (GNU Radio, CubicSDR, SDRangel, etc.). Works with either
stock `uhd` or `gretel/sdr/uhd-oc` — install whichever is present
before installing this formula.

Follows the [stable=upstream / `--HEAD`=fork](#stable--upstream---head--gretel-fork)
convention. The default install builds pothosware upstream pinned
by SHA (pre-fork baseline, useful for reproducible A/B comparisons
against the gretel patches — e.g. testing the state before
[gretel `76f6923`](https://github.com/gretel/SoapyUHD/commit/76f6923f4a2f3d1c92171d03b2b2b81022b35185)
"cache stream channel count in hot read/write path"). The
`--HEAD` install builds the gretel fork master tip with UHD 4.10
compatibility, C++20, Boost-free linkage, target-scoped CMake, and
a `BUILD_SOAPY_SUPPORT` toggle that upstream pothosware has not
yet merged.

```bash
brew install gretel/sdr/soapyuhd            # pothosware baseline
brew install --HEAD gretel/sdr/soapyuhd     # gretel fork
```
