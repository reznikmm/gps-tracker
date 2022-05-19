--  SPDX-FileCopyrightText: 2022 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
-------------------------------------------------------------

--  Generic module for Bluetooth Low Energy, Peripheral role.
--  Byte array type is provided as a formal parameters.
--  Enumeration if provided for supported characteristics.

generic
   type Byte is (<>);
   type Byte_Index is range <>;
   type Byte_Array is array (Byte_Index range <>) of Byte;

   type Characteristic_Index is (<>);
   --  An index for each supported characteristic.
package Bluetooth is

   type Advertising_Data is private;

   function Raw_Data (Value : Byte_Array) return Advertising_Data
     with Pre => Value'Length <= 31;

   type Characteristic_Property is (Read, Write, Notify, Indicate);

   type Characteristic_Property_Set is
     array (Characteristic_Property) of Boolean
       with Pack;

--   subtype UID_16 is Interfaces.Unsigned_16;
   type UID_16 is mod 2 ** 16;

   type Characteristic_Information is record
      UID          : UID_16;
      Property_Set : Characteristic_Property_Set;
      Max_Length   : Byte_Index;
   end record;

   type Characteristic_Information_Array is
     array (Characteristic_Index) of Characteristic_Information;

   type Service_Information is record
      UID                  : UID_16;
      First_Characteristic : Characteristic_Index;
      Last_Characteristic  : Characteristic_Index;
   end record;

   type Service_Information_Array is
     array(Positive range <>) of Service_Information;

   --  Peripheral device instance is configured with advertising data and
   --  characteristic list grouped by service. Max buffer size for all
   --  characteristic is also provided to be static allocated.
   generic
      Advertising          : Advertising_Data;
      Characteristic_Array : Characteristic_Information_Array;
      Service_Array        : Service_Information_Array;
      Buffer_Size          : Byte_Index;
   package Peripheral_Device is

      procedure Run;
      --  Bluetooth stack requires a dedicated task to drive IO.

      procedure Write
        (Index : Characteristic_Index;
         Data  : Byte_Array);
      --  Change value of given characteristic. If characteristic has Notify
      --  property then a connection will be notified.

      procedure Read
        (Index : Characteristic_Index;
         Data  : out Byte_Array;
         Last  : out Byte_Index);
      --  Read value of given characteristic.

   end Peripheral_Device;

private

   subtype Bounded_Offset is Byte_Index'Base range 0 .. 31;

   type Bounded_Array (Length : Bounded_Offset := 0) is record
      Data : Byte_Array (1 .. Length);
   end record;

   type Advertising_Data is record
      Raw : Bounded_Array;
   end record;
end Bluetooth;