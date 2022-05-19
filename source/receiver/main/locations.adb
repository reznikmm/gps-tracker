--  SPDX-FileCopyrightText: 2022 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
-------------------------------------------------------------

package body Locations is

   task body Bluetooth_Runner is
      Supported : constant := Location_Supported + UTC_Time_Supported;
   begin
      Peripheral_Device.Write (Battery_Level, (1 => 100));
      Peripheral_Device.Write (LN_Feature, (Supported, 0));

      Peripheral_Device.Run;

      -- Locations.Peripheral_Device.Write
      --   (Location_and_Speed,
      --    Locations.Location_Present
      --      & Locations.Cast (Latitude)
      --      & Locations.Cast (351859000));
   end Bluetooth_Runner;

end Locations;