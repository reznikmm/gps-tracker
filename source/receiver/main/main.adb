--  SPDX-FileCopyrightText: 2021 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
-------------------------------------------------------------

with Ada.Real_Time;
with Ada.Streams;
with Interfaces;
with System;
pragma Warnings (Off, "is an internal GNAT unit");
with System.Img_Real;

with ESP32.GPIO;
with ESP32.DPort;
with ESP32.SPI;

with Lora;
with Ints;

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

   procedure Write
     (Address : Interfaces.Unsigned_8;
      Value   : Interfaces.Unsigned_8);

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
         use type Ada.Streams.Stream_Element_Count;
         use type Interfaces.Unsigned_16;

         Image  : String (1 .. 90);
         Index  : Positive := Image'First;  --  Next free char in Image
         Stop   : Positive;  --  Last used char in Image

         procedure Append (Text : String);
         --  Append Text to Image skipping leading space characters

         ------------
         -- Append --
         ------------

         procedure Append (Text : String) is
         begin
            for J in Text'Range loop
               if Text (J) /= ' ' then
                  Image (Index .. Index + Text'Last - J) :=
                    Text (J .. Text'Last);

                  Index := Index + Text'Last - J + 1;
                  return;
               end if;
            end loop;

            raise Constraint_Error;
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
      begin
         Ints.Signal.Wait (RX_Done, RX_Timeout);

         if RX_Done then
            Lora_SPI.On_DIO_0_Raise (Buffer, Last);

            if Last = Buffer'Last then
               Append ("{""lat"":");
               Stop := Index - 1;
               System.Img_Real.Set_Image_Real
                 (Long_Long_Float (Data.Lat) / 2.0E9 * 360.0,
                  Image,
                  Stop,
                  Fore => 4,
                  Aft  => 7,
                  Exp  => 0);
               Append (Image (Index .. Stop));

               Append (",""lng"":");
               Stop := Index - 1;
               System.Img_Real.Set_Image_Real
                 (Long_Long_Float (Data.Lng) / 2.0E9 * 360.0,
                  Image,
                  Stop,
                  Fore => 4,
                  Aft  => 7,
                  Exp  => 0);
               Append (Image (Index .. Stop));

               Append (",""tm"":""");
               Append (Interfaces.Unsigned_16'Image (Data.Tm_Sat / 16 / 60));
               Append (":");
               Append (Interfaces.Unsigned_16'Image (Data.Tm_Sat / 16 mod 60));
               Append (""",""sat"":");
               Append (Interfaces.Unsigned_16'Image (Data.Tm_Sat mod 16));

               Append (",""pwr"":");
               Stop := Index - 1;
               System.Img_Real.Set_Image_Real
                 (Long_Long_Float (Data.Power) / 128.0 + 3.0,
                  Image,
                  Stop,
                  Fore => 2,
                  Aft  => 2,
                  Exp  => 0);
               Append (Image (Index .. Stop));

               Append (",""rssi"":");
               Append ("0");  --  FIXME: Add RSSI reading
               Append ("}" & Character'Val (0));
               puts (Image (1 .. Index));

            end if;
         end if;
      end;
   end loop;
end Main;
