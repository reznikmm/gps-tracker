GPS Tracker
===========

[![Build](https://github.com/reznikmm/gps-tracker/workflows/Build/badge.svg)](https://github.com/reznikmm/gps-tracker/actions)
[![REUSE status](https://api.reuse.software/badge/github.com/reznikmm/gps-tracker)](https://api.reuse.software/info/github.com/reznikmm/gps-tracker)

> A gps-tracker in Ada using LoRa devices

I want to track my dog position. So I've bought two Heltec devices:
* [CubeCell GPS-6502](https://heltec.org/project/htcc-ab02s/)
* [Wireless Stick (Gecko Board)](https://heltec.org/project/wireless-stick/)

I've made a prototype in Arduino, but I want to rewrite it in Ada just for fun.

The project includes 3 parts:
* transmiter, CubeCell board gets a position from GPS and transmit it over 
  LoRa module
* receiver, Wireless Stick board receives data from LoRa module an pass it
  to a mobile phone
* GUI, a web application to display the received and the phone position on
  a map.

The prototype is very simple. It uses USB-OTG wire to connect "Wireless Stick"
with phone. GUI is written in JavaScript and includes a USB-to-UART "driver"
for CP2102 chip.

## Install

TBD

### Dependencies

TBD

## Usage

 * Flash CubeCell with `source/transmiter/gps.ino`
 * Flash Wireless Stick with `source/receiver/recGPS.ino`
 * Put `source/gui/gps.html` on a web server and open it in a web browser.
   Connect the Wireless Stick with USB-OTG cable. Click "LoRa" button and
   choose the connected device in the list. You should see received GPS
   position, time (mm:ss), power and phone position. Two cirlce marker
   should be on the map.

## Maintainer

[Max Reznik](https://github.com/reznikmm).

## Contribute

Feel free to dive in!
[Open an issue](https://github.com/reznikmm/gps-tracker/issues/new)
or submit PRs.

## License

[MIT](LICENSE) © Maxim Reznik

