--  SPDX-FileCopyrightText: 2022 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
-------------------------------------------------------------

with Interfaces.C;
with System;

package body Bluetooth is

   function Raw_Data (Value : Byte_Array) return Advertising_Data is
   begin
      return Result : Advertising_Data do
         Result.Raw := (Value'Length, Value);
      end return;
   end Raw_Data;

   package body Peripheral_Device is
      type Byte_Index_Array is array (Characteristic_Index) of Byte_Index'Base;

      function Get_Offset_Array return Byte_Index_Array;

      function Get_Offset_Array return Byte_Index_Array is
         Last : Byte_Index := 1;
      begin
         return Result : Byte_Index_Array do
            for Index in Characteristic_Array'Range loop
               Result (Index) := Last;
               Last := Last + Characteristic_Array (Index).Max_Length;
            end loop;
         end return;
      end Get_Offset_Array;

      Initialized : Boolean := False;

      Characteristic_Offset : constant Byte_Index_Array := Get_Offset_Array;

      Total_Size : constant Byte_Index :=
        Characteristic_Offset (Characteristic_Index'Last) +
        Characteristic_Array (Characteristic_Index'Last).Max_Length - 1;

      pragma Compile_Time_Error
        (Total_Size > Buffer_Size, "Buffer_Size too small");

      protected Protected_Buffer is
         procedure Write
           (Index : Characteristic_Index;
            Data  : Byte_Array);

         procedure Read
           (Index : Characteristic_Index;
            Data  : out Byte_Array;
            Last  : out Byte_Index);
      private
         Buffer : Byte_Array (1 .. Buffer_Size);
         Bound  : Byte_Index_Array := (Characteristic_Index'Range => 0);
      end Protected_Buffer;

      protected body Protected_Buffer is

         procedure Write
           (Index : Characteristic_Index;
            Data  : Byte_Array) is
         begin
            Bound (Index) := Characteristic_Offset (Index) + Data'Length - 1;

            Buffer (Characteristic_Offset (Index) .. Bound (Index)) := Data;
         end Write;

         procedure Read
           (Index : Characteristic_Index;
            Data  : out Byte_Array;
            Last  : out Byte_Index) is
         begin
            Last := Bound (Index) - Characteristic_Offset (Index) + Data'First;

            Data (Data'First .. Last) :=
              Buffer (Characteristic_Offset (Index) .. Bound (Index));
         end Read;
      end Protected_Buffer;

      package Nimble is
         procedure Run;
      end Nimble;

      package body Nimble is
         procedure Set_Services;

         procedure On_Sync_Callback
           with Convention => C;

         procedure Start_Advertising;

         procedure GAP_Event (Code : Interfaces.C.int)
           with Convention => C;

         procedure Char_Callback
           (Code   : Interfaces.C.int;
            Index  : Interfaces.C.int;
            Buffer : System.Address;
            Size   : in out Interfaces.C.int)
              with Convention => C;

         procedure GAP_Event (Code : Interfaces.C.int) is
         begin
            case Code is
               when 0 =>
                  Start_Advertising;
               when others =>
                  null;
            end case;
         end GAP_Event;

         procedure Char_Callback
           (Code   : Interfaces.C.int;
            Index  : Interfaces.C.int;
            Buffer : System.Address;
            Size   : in out Interfaces.C.int)
         is
            use type Interfaces.C.int;

            procedure puts
              (data : System.Address)
               with Import, Convention => C, External_Name => "puts";

            Last : Byte_Index;
            Char : constant Characteristic_Index :=
              Characteristic_Index'Val (Index);

            Target : Byte_Array (1 .. 32)
              with Address => Buffer;
         begin
            Protected_Buffer.Read (Char, Target, Last);
            Size := Interfaces.C.int (Last);
         end Char_Callback;

         procedure Run is
            procedure internal_bt_init (Callback : System.Address)
              with Import,
                Convention => C,
                External_Name => "internal_bt_init";

            procedure internal_bt_start
              with Import,
                Convention => C,
                External_Name => "internal_bt_start";
         begin
            internal_bt_init (On_Sync_Callback'Address);
            Set_Services;
            internal_bt_start;
         end Run;

         procedure On_Sync_Callback is
            procedure ble_app_set_addr
              with Import,
                Convention => C,
                External_Name => "ble_app_set_addr";
         begin
            ble_app_set_addr;
            Start_Advertising;
         end On_Sync_Callback;

         procedure Set_Services is
            procedure add_chr_def
              (p_index  : Interfaces.C.int;
               p_uid    : Interfaces.C.int;
               flags    : Interfaces.C.unsigned;
               callback : System.Address)
                 with Import, Convention => C, External_Name => "add_chr_def";

            procedure add_svc_def (p_uid : Interfaces.C.int)
              with Import, Convention => C, External_Name => "add_svc_def";

            procedure complete_svc_def
              with Import, Convention => C, External_Name => "complete_svc_def";

            function To_Flags (Set : Characteristic_Property_Set)
              return Interfaces.C.unsigned
            is
               use type Interfaces.C.unsigned;

               Map : constant
                 array (Characteristic_Property) of Interfaces.C.unsigned :=
                  (Read => 1, Write => 2, Notify => 4, Indicate => 0);

               Result : Interfaces.C.unsigned := 0;
            begin
               for J in Set'Range loop
                  if Set (J) then
                     Result := Result + Map (J);
                  end if;
               end loop;

               return Result;
            end To_Flags;
         begin
            for Service of Service_Array loop
               add_svc_def (Interfaces.C.int (Service.UID));

               for Index in
                 Service.First_Characteristic .. Service.Last_Characteristic
               loop
                  declare
                     Char : Characteristic_Information renames
                       Characteristic_Array (Index);
                  begin
                     add_chr_def
                       (Characteristic_Index'Pos (Index),
                        Interfaces.C.int (Char.UID),
                        To_Flags (Char.Property_Set),
                        Char_Callback'Address);
                  end;
               end loop;
            end loop;

            complete_svc_def;
         end Set_Services;

         procedure Start_Advertising
         is
            procedure ble_app_advertise
              (data     : System.Address;
               data_len : Interfaces.C.int;
               callback : System.Address)
                 with Import,
                   Convention => C,
                   External_Name => "ble_app_advertise";
         begin
            ble_app_advertise
              (Advertising.Raw.Data'Address,
               Interfaces.C.int (Advertising.Raw.Length),
               GAP_Event'Address);
         end Start_Advertising;

      end Nimble;

      procedure Run is
      begin
         if not Initialized then
            Initialized := True;
            Nimble.Run;
         end if;
      end Run;

      procedure Write
        (Index : Characteristic_Index;
         Data  : Byte_Array)
      is
         procedure ble_notify_chr_change
           (p_index  : Interfaces.C.int;
            data     : System.Address;
            data_len : Interfaces.C.int)
              with Import,
                Convention => C,
                External_Name => "ble_notify_chr_change";

      begin
         Protected_Buffer.Write (Index, Data);

         if Initialized
           and Characteristic_Array (Index).Property_Set (Notify)
         then
            ble_notify_chr_change
              (Characteristic_Index'Pos (Index),
               Data'Address,
               Data'Length);
         end if;
      end Write;

      procedure Read
        (Index : Characteristic_Index;
         Data  : out Byte_Array;
         Last  : out Byte_Index) is
      begin
         Protected_Buffer.Read (Index, Data, Last);
      end Read;
   end Peripheral_Device;

end Bluetooth;