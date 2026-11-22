## Recovery Device Tree for the Samsung Galaxy A32 4G (MTK)

## How-to compile it:

```sh
export ALLOW_MISSING_DEPENDENCIES=true
. build/envsetup.sh
lunch twrp_a32-eng
make recoveryimage
```

Blobs version:
> Kernel base: A325FXXSCDYB2

> Ramdisk, DTB, DTBO base: A325FXXSCDYB2

Kernel source:
> https://github.com/LumiROM/android_kernel_samsung_mt6768
