--  SPDX-FileCopyrightText: 2022 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
-------------------------------------------------------------

with Bluetooth;

with Ada.Streams;
with Ada.Unchecked_Conversion;

package Locations is

   --  Location and navigation profile allows these characteristics:
   type Characteristic_Index is
     (LN_Feature,
      Location_and_Speed,
      Battery_Level);

   package Bluetooth is new Standard.Bluetooth
     (Characteristic_Index => Characteristic_Index,
      Byte                 => Ada.Streams.Stream_Element,
      Byte_Index           => Ada.Streams.Stream_Element_Offset,
      Byte_Array           => Ada.Streams.Stream_Element_Array);

   Advertising : constant Bluetooth.Advertising_Data :=
     Bluetooth.Raw_Data
       ((16#02#, 16#01#, 16#06#,
         16#05#, 16#03#, 16#19#, 16#18#, 16#0F#, 16#18#,
         16#07#, 16#09#, 16#4D#, 16#79#, 16#54#, 16#65#, 16#73#, 16#74#));

   Read : constant Bluetooth.Characteristic_Property_Set :=
     (Bluetooth.Read => True, others => False);

   Notify : constant Bluetooth.Characteristic_Property_Set :=
     (Bluetooth.Notify => True, others => False);

   Location_Supported     : constant := 2 ** 2;
   Rolling_Time_Supported : constant := 2 ** 5;
   UTC_Time_Supported     : constant := 2 ** 6;

   Location_Present     : constant := 2 ** 2;
   Rolling_Time_Present : constant := 2 ** 5;
   UTC_Time_Present     : constant := 2 ** 6;

   use type Ada.Streams.Stream_Element_Offset;

   --  Latitude sint32:4 Longitude sint32:4 /10**7
   --  UTC: yyyy:2 mm:1 dd:1 hh:1 mm:1 ss:1 = 7 bytes

   package Peripheral_Device is new Bluetooth.Peripheral_Device
     (Advertising           => Advertising,
      Characteristic_Array  =>
        (LN_Feature         => (16#2A6A#, Read, 4),
         Location_and_Speed => (16#2A67#, Notify, 2 + 2 * 4 + 7),
         Battery_Level      => (16#2A19#, Read, 1)),
      Service_Array         =>
        ((16#1819#, LN_Feature,    Location_and_Speed),
         (16#180F#, Battery_Level, Battery_Level)),
      Buffer_Size           => 4 + 2 + 2 * 4 + 7 + 1);

   subtype Byte_Array_4 is Ada.Streams.Stream_Element_Array (1 .. 4);

   function Cast is new Ada.Unchecked_Conversion (Integer, Byte_Array_4);

   task Bluetooth_Runner
     with Storage_Size => 4096;

end Locations;