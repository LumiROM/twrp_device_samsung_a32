# TWRP source patches for the Samsung Galaxy A32 (a32)

These patches apply to `bootable/recovery` and are kept here because that
project is managed by `repo sync`, which resets it. Apply them after every sync
and before building:

```bash
device/samsung/a32/patches/apply_patches.sh
# or, from another directory:
device/samsung/a32/patches/apply_patches.sh /path/to/twrp12
```

The script is idempotent: patches that are already applied are skipped.

## 0001 - partitionmanager: silence BLKROSET "Unable to unlock" errors

`TWPartitionManager::Unlock_Block_Partitions()` logs
`E:Unable to unlock /dev/block/...: (null)` for every block device that does not
support `BLKROSET` (for example `mmcblk0boot0` on MediaTek, which is read-only by
design). The failure is harmless and the message even had a missing `strerror`
argument, which is where the `(null)` came from. The error line is removed; the
loop keeps working exactly as before.

## 0002 - settings and custom themes persistence

Two problems are fixed:

* **Settings were only written when leaving recovery through TWRP's own
  Reboot/Poweroff menu** (`TWFunc::tw_reboot()` calls `DataManager::Flush()`).
  Any other exit (power button, `adb reboot`, `reboot` typed in the Terminal,
  a crash) silently discarded every change made in that session.
  `DataManager` now marks the settings as dirty when a persisted value changes
  and the GUI main loop saves them with a 5 second debounce
  (`DataManager::FlushIfNeeded()`), so they survive any exit path. The theme
  reload path also flushes before re-reading the settings file, so it no longer
  discards unsaved changes.

* **Custom themes were only searched in the new TWRP 12.1 location**
  (`/data/recovery/theme/ui.zip`). Themes installed the classic way in
  `/sdcard/TWRP/theme/ui.zip` were silently ignored. `TWFunc::Find_Custom_Theme()`
  now checks both locations and is used by the GUI start, the theme reload and
  the GUI resource reload.

Extras included:

* `DataManager::GetSettingsStoragePath()` falls back to `/data/recovery/` when
  `tw_settings_path` was never set, so the settings file can no longer end up
  written relative to the ramdisk root (and lost on reboot).
* `DataManager::SaveValues()` now logs an error when the settings file cannot be
  written instead of always claiming success.

## 0003 - theme: keep the status bar clock out of the camera notch

The Galaxy A32 (SM-A325F) has a centered camera cutout. From the stock
`framework-res` overlay of the device (`config_mainBuiltInDisplayCutout`):

```
M 0,0 H -27.42857142857143 V 30.47619047619048 H 27.42857142857143 V 0 H 0 Z @dp
```

So the notch is 54.9dp wide and 30.5dp tall, i.e. **144 x 80 px** at 420dpi
(x 468..612, y 0..80 on the 1080x2400 panel). The stock status bar is only
72 * 1.25 = 90px tall, so there is no room to put the text below the notch
without making the status bar much taller; instead the clock is moved to
`x = 320` (251..388), between the CPU temperature text and the notch. Only the
centered (default) clock placement is changed; the `TW_CUSTOM_CLOCK_POS`
variants are untouched.

## BoardConfig: panel brightness and real screen off

* `TW_MAX_BRIGHTNESS := 486`: the panel reports `max_brightness=486`; with the
  old `306` the settings slider only reached ~63% of the real range.
  `TW_DEFAULT_BRIGHTNESS := 316` keeps the same perceived default (65%).
* `TW_NO_SCREEN_BLANK` removed: with it defined, `blanktimer` skipped
  `gr_fb_blank()` and "screen off" was emulated by writing 0 to the brightness
  file, which this panel clamps to a minimum, so the image stayed visible when
  pressing the power button. Without the flag, `fbdev_blank()` performs
  `ioctl(FBIOBLANK, FB_BLANK_POWERDOWN/UNBLANK)` and the display really turns
  off (same path as `/sys/class/graphics/fb0/blank=4`, verified on the device).
  A touch or another press of the power button restores it.

## Note: TW_INCLUDE_LIBRESETPROP is intentionally NOT enabled`TW_INCLUDE_LIBRESETPROP` links Magisk's `libresetprop` into the `recovery`
binary. It must not be used on this device:

* As a shared library the `.so` is never installed into the recovery ramdisk, so
  `recovery` dies at boot with `CANNOT LINK EXECUTABLE ... libresetprop.so not
  found` (screen stays on the Samsung logo).
* Linking it statically (plus `libmagisksystemproperties`, `libmagiskutils`,
  `libnanopb`) makes the process crash later with
  `Fatal signal 11 (SIGSEGV), code 2 (SEGV_ACCERR)` right after an
  `Update_System_Details()`: Magisk's resetprop remaps/frees the system property
  area (`MapSerialPropertyArea`, `FreeAndUnmap`) while libc keeps its cached
  `__system_property_area__` pointer, so the next `property_get` faults.

The supported way to touch properties from TWRP is the separate process, i.e.
`TW_INCLUDE_RESETPROP` (the `resetprop` binary) instead of the library.
