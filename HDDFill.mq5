/**=             HDDFill.mq5  (TyphooN's HDD Filler)
 *               Copyright 2023, TyphooN (https://www.marketwizardry.org/)
 *
 * Disclaimer and Licence
 *
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * All trading involves risk. You should have received the risk warnings
 * and terms of use in the README.MD file distributed with this software.
 * See the README.MD file for more information and before using this software.
 *
 **/
 #property copyright "Copyright 2024 TyphooN (MarketWizardry.org)"
#property link      "http://marketwizardry.info/"
#property version   "1.000"
#property description "TyphooN's HDD Filler"
#import "GetFreeDiskSpace.dll"
long GetFreeDiskSpace(const char &drive);
#import

input string drive_letter = "C:\\";
input double fill_percentage = 90.0; // Percentage of free space to fill

void OnStart()
{
    long free_space = GetFreeDiskSpace(drive_letter[0]);
    if (free_space == -1)
    {
        Print("Error getting free disk space");
        return;
    }

    Print("Free space (bytes): ", free_space);

    // Calculate the amount of space to fill
    long space_to_fill = (long)(free_space * (fill_percentage / 100.0));

    Print("Space to fill (bytes): ", space_to_fill);

    int file_size_mb = 100; // Size of each file in MB
    int file_size_bytes = file_size_mb * 1024 * 1024;
    int num_files = (int)(space_to_fill / file_size_bytes);

    string file_prefix = "dummy_file_";
    char buffer[];

    // Allocate buffer of specified size
    ArrayResize(buffer, file_size_bytes);
    ArrayFill(buffer, 0, ArraySize(buffer), '0');

    for (int i = 0; i < num_files; i++)
    {
        string file_name = file_prefix + IntegerToString(i) + ".txt";
        int file_handle = FileOpen(file_name, FILE_WRITE | FILE_BIN);

        if (file_handle != INVALID_HANDLE)
        {
            FileWriteArray(file_handle, buffer, 0, ArraySize(buffer));
            FileClose(file_handle);
        }
        else
        {
            Print("Failed to create file: ", file_name);
        }
    }

    Print("Disk filling completed.");
}
