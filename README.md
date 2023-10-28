# ESP32-S3 Linux Build scripts and Web Installer

This is a set of build scripts and web installer for [Linux on ESP32-S3](http://wiki.osll.ru/doku.php/etc:users:jcmvbkbc:linux-xtensa:esp32s3).

[Visit web-installer page](https://anabolyc.github.io/esp32-linux-build/)

## Disclaimer

I'm not the author of this code. [Max Filippov](https://github.com/jcmvbkbc) is. But I admired his work so much, so I decided to add by 5 cents to it. Specifically

- Added submodules for better dependencies tracking and better build stability
- Added build pipeline, so anyone would have a reference build
- Added release pipeline, so if you don't fancy building it yourself, can just pick up binaries
- Finally, added web-installer, so you can flash to your ESP32-S3 board it with no tools but modern browser

Hope that will help others to follow authors steps.

## Links

- [Docs](http://wiki.osll.ru/doku.php/etc:users:jcmvbkbc:linux-xtensa:esp32s3)
- [Write-up](https://habr.com/en/articles/736408/) (Russian)
- [Write-up](https://gojimmypi.github.io/ESP32-S3-Linux/) (English)

## Code references

- [xtensa-dynconfig](https://github.com/jcmvbkbc/xtensa-dynconfig/tree/original)
- [config-esp32s3](https://github.com/jcmvbkbc/config-esp32s3)
- [esp-idf](https://github.com/jcmvbkbc/esp-idf/tree/linux-5.0.1)
- [linux-xtensa](https://github.com/jcmvbkbc/linux-xtensa/tree/xtensa-6.4-esp32)
- [binutils-gdb-xtensa](https://github.com/jcmvbkbc/binutils-gdb-xtensa/tree/xtensa-2.40-fdpic)
- [gcc-xtensa](https://github.com/jcmvbkbc/gcc-xtensa/tree/xtensa-14-fdpic)
- [uclibc-ng-xtensa](https://github.com/jcmvbkbc/uclibc-ng-xtensa/tree/xtensa-fdpic)
- [buildroot](https://github.com/jcmvbkbc/buildroot/tree/xtensa-2023.08-fdpic)
- [crosstool-NG](https://github.com/jcmvbkbc/crosstool-NG/tree/xtensa-fdpic)

## Demo

![Screencast](/docs/img/Screencast%20from%2028.10.2023%2021:54:48.gif)