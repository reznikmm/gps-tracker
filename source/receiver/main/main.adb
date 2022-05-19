--  SPDX-FileCopyrightText: 2021-2022 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
---------------------------------------------------------------------

with Ada.Real_Time;
with Ada.Streams;
with Ada.Unchecked_Conversion;
with Interfaces;
with System;

with ESP32.GPIO;
with ESP32.DPort;
with ESP32.SPI;

with Lora;
with Ints;
with Locations;

procedure Main
  with No_Return
is
   use type Ada.Real_Time.Time;

   Environment_Task_Storage_Size : constant Natural := 4096
    with
      Export,
      Convention => Ada,
      External_Name => "_environment_task_storage_size";
   --  Increase stack size for environment task

   procedure puts
     (data : String)
      with Import, Convention => C, External_Name => "puts";

   procedure Read
     (Address : Interfaces.Unsigned_8;
      Value   : out Interfaces.Unsigned_8);
   --  Read a byte from LoRa module
   procedure Write
     (Address : Interfaces.Unsigned_8;
      Value   : Interfaces.Unsigned_8);
   --  Write a byte to LoRa module

   ----------
   -- Read --
   ----------

   procedure Read
     (Address : Interfaces.Unsigned_8;
      Value   : out Interfaces.Unsigned_8)
   is
      Buffer : ESP32.SPI.Data_Array (1 .. 1);
   begin
      ESP32.SPI.Half_Duplex_Transfer
        (Host    => ESP32.SPI.SPI_2,
         Address => (8, Interfaces.Unsigned_16 (Address)),
         MISO    => Buffer);

      Value := Interfaces.Unsigned_8 (Buffer (1));
   end Read;

   -----------
   -- Write --
   -----------

   procedure Write
     (Address : Interfaces.Unsigned_8;
      Value   : Interfaces.Unsigned_8)
   is
      Buffer : constant ESP32.SPI.Data_Array (1 .. 1) :=
        (1 => Ada.Streams.Stream_Element (Value));
   begin
      ESP32.SPI.Half_Duplex_Transfer
        (Host    => ESP32.SPI.SPI_2,
         Address => (8, Interfaces.Unsigned_16 (Address)),
         MOSI    => Buffer);
   end Write;

   package Lora_SPI is new Lora (Read, Write);

   Button : constant := 0;   --  Button pad
   LED    : constant := 25;  --  LED pad
   LoRa_Reset : constant := 14;
begin
   ESP32.DPort.Set_Active (ESP32.DPort.SPI2, True);

   ESP32.GPIO.Configure_All
     (((Pad       => LED,
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Output,
        Output    => ESP32.GPIO.GPIO_OUT),
       (Pad       => 5,  --  SPI CLK
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Output,
        Output    => ESP32.GPIO.HSPICLK),
       (Pad       => 18,  --  SPI CS0 -> LoRa NSS
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Output,
        Output    => ESP32.GPIO.HSPICS0),
       (Pad       => 27,  --  SPI MOSI
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Output,
        Output    => ESP32.GPIO.HSPID),
       (Pad       => 19,  --  SPI MISO
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Input,
        Interrupt => ESP32.GPIO.Disabled,
        Input     => ESP32.GPIO.HSPIQ),
       (Pad       => 26,  --  <-- LoRa DIO0
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Input,
        Interrupt => ESP32.GPIO.Rising_Edge,
        Input     => ESP32.GPIO.None),
       (Pad       => 35,  --  <-- LoRa DIO1
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Input,
        Interrupt => ESP32.GPIO.Rising_Edge,
        Input     => ESP32.GPIO.None),
       (Pad       => 34,  --  <-- LoRa DIO2
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Input,
        Interrupt => ESP32.GPIO.Disabled,
        Input     => ESP32.GPIO.None),
       (Pad       => LoRa_Reset,  --  --> LoRa_Reset
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Output,
        Output    => ESP32.GPIO.GPIO_OUT),
       (Pad       => Button,
        IO_MUX    => ESP32.GPIO.GPIO_Matrix,
        Direction => ESP32.GPIO.Input,
        Interrupt => ESP32.GPIO.Disabled,
        Input     => ESP32.GPIO.None)));

   ESP32.GPIO.Set_Level (LoRa_Reset, False);
   delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (20);
   ESP32.GPIO.Set_Level (LoRa_Reset, True);
   delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (50);
   ESP32.GPIO.Set_Level (18, True);  --  SS

   ESP32.SPI.Configure
     (Host       => ESP32.SPI.SPI_2,
      Bit_Order  => System.High_Order_First,
      Byte_Order => System.Low_Order_First,
      Frequency  => 8_000_000,
      CP_Mode    => ESP32.SPI.Mode0);

   ESP32.GPIO.Set_Level (LED, True);

   LoRa_SPI.Initialize (433_375_000);
   LoRa_SPI.Receive;

   loop
      declare
         use type Ada.Streams.Stream_Element;
         use type Ada.Streams.Stream_Element_Count;
         use type Interfaces.Unsigned_16;
         use type Interfaces.Integer_32;

         Image  : Ada.Streams.Stream_Element_Array (1 .. 2 + 2 * 4 + 7);
         Index  : Ada.Streams.Stream_Element_Count;
         --  Next free byte in Image

         subtype Word is Ada.Streams.Stream_Element_Array (1 .. 4);

         function Cast is new Ada.Unchecked_Conversion
           (Interfaces.Integer_32, Word);

         procedure Append (Data : Ada.Streams.Stream_Element_Array);
         --  Append Data to Image

         ------------
         -- Append --
         ------------

         procedure Append (Data : Ada.Streams.Stream_Element_Array) is
         begin
            Image (Index .. Index + Data'Length - 1) := Data;
            Index := Index + Data'Length;
         end Append;

         type Packet is record
            Lat    : Interfaces.Integer_32;
            Lng    : Interfaces.Integer_32;
            Tm_Sat : Interfaces.Unsigned_16;
            Power  : Interfaces.Unsigned_8;
         end record;

         RX_Done    : Boolean;
         RX_Timeout : Boolean;

         Data   : Packet;
         Last   : Ada.Streams.Stream_Element_Count;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 12)
           with Import, Address => Data'Address;

         Present : constant :=
           Locations.Location_Present + Locations.UTC_Time_Present;
         Year_1  : constant := 2022 rem 256;
         Year_2  : constant := 2022 / 256;
         Month   : constant := 6;
         Day     : constant := 1;
      begin
         Ints.Signal.Wait (RX_Done, RX_Timeout);

         if RX_Done then
            Lora_SPI.On_DIO_0_Raise (Buffer, Last);

            if Last = Buffer'Last then
               Index := 1;
               Append ((Present, 0));
               Append (Cast (Data.Lat / 5 * 9));
               Append (Cast (Data.Lng / 5 * 9));
               Append ((Year_1, Year_2, Month, Day));  --  year, month, day
               Append
                ((0,  --  hh
                  Ada.Streams.Stream_Element (Data.Tm_Sat / 16 / 60),  --  mi
                  Ada.Streams.Stream_Element (Data.Tm_Sat / 16 mod 60)));  -- s

               Locations.Peripheral_Device.Write
                (Locations.Location_and_Speed, Image);

               Locations.Peripheral_Device.Write
                (Locations.Battery_Level,
                 (1 => Ada.Streams.Stream_Element (Data.Power)));
            end if;
         end if;
      end;
   end loop;
end Main;
