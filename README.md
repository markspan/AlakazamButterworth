# Butterworth filter for Alakazam

A plugin for [Alakazam](https://github.com/markspan/Alakazam) that filters EEG
with a Butterworth IIR filter exactly as ERPLAB's `basicfilter` does, and
offers the filter settings Zhang, Garrett and Luck (2024) recommend for seven
ERP components as presets.

## Manual

The manual is on this repository's pages:
<https://markspan.github.io/AlakazamButterworth/>.

## Why

Zhang, Garrett and Luck (2024) worked out which high-pass and low-pass
settings give the best signal-to-noise ratio without distorting the waveform,
for the N170, MMN, N2pc, P3, N400, LRP and ERN, scored as mean amplitude, peak
amplitude, peak latency or 50% area latency. They found these settings with
ERPLAB's Butterworth filter at 12 dB per octave. Alakazam's own **Filter** is
EEGLAB's windowed-sinc FIR, whose roll-off is far steeper; the distortion a
filter causes depends on its slope as well as its cutoff, so the
recommendations are only known to hold for the filter they were found with.
This plugin is that filter.

## What it does

- **ERPLAB's filter.** `butter(order/2, cutoff)`, run forward and backward
  with `filtfilt`: the cutoff is where the amplitude is halved (-6 dB), the
  roll-off is 6 dB per octave per order (order 2 is 12 dB per octave), and
  nothing shifts in time. With both cutoffs it is a band-pass, the low-pass
  applied first and then the high-pass, as ERPLAB applies them.
- **ERPLAB's segments.** A continuous recording is filtered between its
  boundary events, cut where ERPLAB cuts it (the event's latency less half a
  sample, rounded). Epoched data and averages are filtered one trial, or one
  bin, at a time. A segment of no more than 3 x order samples is left as it
  is, as ERPLAB leaves it.
- **ERPLAB's DC option.** *Remove the DC offset first* subtracts each
  segment's mean over its first half second before a high-pass, as ERPLAB's
  option does. It is kept for parity: with MATLAB's `filtfilt`, which starts
  from steady state, it makes no measurable difference to the result.
- **Alakazam's rejected samples.** Alakazam marks a rejected sample as `NaN`,
  which ERPLAB's data never hold. Each channel's runs between rejected
  samples are filtered separately, so one rejection does not spread through
  the filter; on data without rejections this changes nothing.
- **A record.** `EEG.etc.alz.butterworth` holds the cutoffs, the order and
  roll-off, the preset, the channels, how many segments were too short to
  filter, and the plugin's version.

On data without rejected samples the result equals ERPLAB's `basicfilter`
to within 1e-9 µV (`tests/ButterworthFilterTest.m` runs both).

## The presets

The dialog's **Recommended for** list holds Zhang, Garrett and Luck's table
for neurotypical young adults. Choosing one sets both cutoffs and 12 dB per
octave, and greys them out; **Custom** sets them yourself. A recommendation
that is a range becomes one number:

| The table says | The preset uses |
|---|---|
| a low-pass of *X* or more, or none | *X* |
| a low-pass from *X* to *Y* | the middle of the range |
| a high-pass of *X* or less | *X* |
| a high-pass of 0.01 or none | 0.01 |

A setting the table gives for particular data (moderate high-frequency noise;
moderate broadband noise where distorted onset and offset times can be
tolerated; to avoid distorting onset and offset times) is a preset of its
own where it differs. The chosen cutoffs are stored with the step, so a
replay does not depend on the table.

## Installing

In Alakazam, **Install** on the Alakazam tab, and give it the link to this
repository:

```
https://github.com/markspan/AlakazamButterworth
```

It installs the latest release. A zip from the
[releases](https://github.com/markspan/AlakazamButterworth/releases), or one
built with `build`, installs the same way. The filter appears as
**Butterworth** under *1. Preprocessing* on the Tools tab.

It needs Alakazam V0.4.5.2 or later, whose dialogs draw a filter's frequency
response (`DialogFields.FrequencyResponse`, the plot Alakazam's own Filter
shows), and MATLAB's Signal Processing Toolbox (`butter`, `filtfilt`,
`freqz`). Version 0.1.0 runs on V0.4.5.1.

## Building and testing

```matlab
build()                                          % dist/ButterworthFilter-<version>.zip
runtests('tests/ButterworthFilterTest.m')        % the filter, against ERPLAB
runtests('tests/PluginInstallTest.m')            % the zip, through Alakazam's installer
```

The tests need Alakazam's source, in `ALAKAZAM_ROOT` or beside this
repository; the comparisons with ERPLAB also need ERPLAB, under EEGLAB's
plugins folder, and are skipped without it.

## References

Zhang, G., Garrett, D. R., & Luck, S. J. (2024). Optimal filters for ERP
research II: Recommended settings for seven common ERP components.
*Psychophysiology*, *61*, e14530. https://doi.org/10.1111/psyp.14530

Lopez-Calderon, J., & Luck, S. J. (2014). ERPLAB: An open-source toolbox for
the analysis of event-related potentials. *Frontiers in Human Neuroscience*,
*8*, 213. https://doi.org/10.3389/fnhum.2014.00213

## Licence

GNU General Public License v3.0, as Alakazam.
