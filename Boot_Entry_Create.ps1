### The script is for retrieving the boot entry GUID and establishing multiple boot entry ###

## Pre-define variables
# The top directory of Powershell script and VHD file
$Directory_BootScript = "D:\boot_script"
$Directory_BootEntry = "D:\boot_entry"

# The empty VHDX file for cloning to any other boot entries
$File_VHDTemplate = "0_empty.vhdx"

# The player list file, the format should be CSV.
$File_PlayerListCSV = "player_list.csv"

# The output json file for player list.
$File_PlayerListJSON = "player_list.json"

# The drive letter of where VHDX files exist
$Drive_VHD = $Directory_BootEntry.Split(':')[0]
# The directory of where VHDX files exist. (Not includ drive letter, only directory structure.)
$SubPath_VHD = $Directory_BootEntry.Split('\')[1..10] -join '\'

# The full path of the empty VHD file.
$FullPath_VHDTemplate = "$Directory_BootEntry\$File_VHDTemplate"

# The full path of the player list file.
$FullPath_PlayerListCSV = "$Directory_BootScript\$File_PlayerListCSV"

# The full path of the output json file.
$FullPath_PlayerListJSON = "$Directory_BootScript\$File_PlayerListJSON"

$CurrentTime = Get-Date -UFormat "%Y%m%d-%H%M%S"

# The sequential number is for counting the boot entries number
$SequentialNumber = 1


## Main code
# Check whether the input CSV file exist
if ( -not (Test-Path -Path $FullPath_PlayerListCSV)) {
    Write-Host "Please confirm that you have the player list CSV file."
    break
}

# Check whether the output JSON file exist and rename it.
if ([System.IO.File]::Exists($FullPath_PlayerListJSON)) {
    $FileBasename_PlayerListJSON = [System.IO.Path]::GetFileNameWithoutExtension($File_PlayerListJSON)
    $FullPath_PlayerListJSON_Old = "$Directory_BootScript\${FileBasename_PlayerListJSON}_${CurrentTime}.json"
    Rename-Item -Path $FullPath_PlayerListJSON -NewName $FullPath_PlayerListJSON_Old
    Write-Host "Copy $FullPath_PlayerListJSON to $FullPath_PlayerListJSON_Old"
}

# Convert the input CSV file to JSON file.
Get-Content -Path $FullPath_PlayerListCSV | ConvertFrom-Csv -Delimiter ',' | ConvertTo-Json | Out-File $FullPath_PlayerListJSON


# Add new boot entry
Write-Host "Create a temporary boot entry"
$New_Boot_Entry = cmd /c "bcdedit /copy {current} /d TemporaryBootEntry"

# Parsing the last boot entry GUID
$GUID = $New_Boot_Entry.Split(' ')[6].split('.')[0]
Write-Host "`nThe last used GUID is $GUID"

# Delete the temporary boot entry
Write-Host "`nDelete the temporary boot entry"
cmd /c "bcdedit /delete $GUID"
Write-Host "`nDelete GUID $GUID"

# Parse the last GUID
$GUID = ($GUID.Split('{')[1]).split('}')[0]
$GUID_1st = $GUID.Split('-')[0]
$GUID_2st = $GUID.Split('-')[1..4] -join '-'
# Convert the GUID string to hex code
$GUID_Current = [System.Convert]::ToString("0x$GUID_1st", 10)

# Save the boot menu to $BCD variable
$BCD = bcdedit

# Read the JSON file and convert to object format
$JSONContent = Get-Content -Path $FullPath_PlayerListJSON | ConvertFrom-Json

# Iterate each object
$JSONContent | ForEach-Object {
    $Team = $_."Team"
    $BlizzardID = $_."BlizzardID"
    $NewBootEntry = "${Team}_${BlizzardID}"
    $File_NewVHD = "$NewBootEntry.vhdx"
    $FullPath_NewVHD = "$Directory_BootEntry\$File_NewVHD"
    
    # Generate player's VHD file from template file if it doesn't exist.
    Write-Host "`n$SequentialNumber $Team $BlizzardID"
    if ([System.IO.File]::Exists($FullPath_NewVHD)) {
        Write-Host "The VHD file $File_NewVHD exists!"
    }
    else {
        Copy-Item -Path $FullPath_VHDTemplate -Destination $FullPath_NewVHD
        Write-Host "Copy $File_VHDTemplate to $File_NewVHD"
    }    
    
    # Generate boot entry if it doesn't exist.
    if ($BCD | findstr "description" | findstr "$NewBootEntry") {
        Write-Host "The boot entry ${Team}_${BlizzardID} exists!"
    }
    else {
        [INT]$GUID_Current = [INT]$GUID_Current + 1
        $GUID_Result = '{0:X8}' -f $GUID_Current
        [string]$GUID_New = "$GUID_Result-$GUID_2st"

        Write-Host "`nCreate new boot entry..."
        Write-Host "Copy current boot entry to $NewBootEntry"
        cmd /c "bcdedit /copy {current} /d $NewBootEntry"# | Out-File $Target_File -Append
        
        Write-Host "`nSet the boot device $NewBootEntry to $Directory_BootEntry\$File_NewVHD"
        cmd /c "bcdedit /set {$GUID_New} device vhd=[${Drive_VHD}:]\$SubPath_VHD\$NewBootEntry.vhdx"
        
        Write-Host "`nSet the boot osdevice $NewBootEntry to $Directory_BootEntry\$File_NewVHD"        
        cmd /c "bcdedit /set {$GUID_New} osdevice vhd=[${Drive_VHD}:]\$SubPath_VHD\$NewBootEntry.vhdx"
    }
    
    $SequentialNumber += 1
}
