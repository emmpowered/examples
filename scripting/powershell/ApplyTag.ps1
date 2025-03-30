<#	
	.NOTES
	===========================================================================
	 Created on:   	10/06/2022
	 Created by:   	Jamie Marsh - https://emmpowered.blog
	 Filename:     	ApplyTag.ps1
     	 Version:       2.0
	===========================================================================
	.DESCRIPTION
		This script applies a tag to all devices in a specific smartgroup.
		Please specify the following values in the variable sections directly below:
			Smart Group number
			Tag Id
        To run this script, you may need to modify the Powershell Execution Policy from the Powershell CLI, using the following command:
			Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
		This is a temporary settings that change only applies for the current powershell session.  
		For scheduled tasks or automation, please run the UEMAuth.ps1 script manually once to generate the required credentials XML file
		#>

#####################################################
######## SET YOUR VALUES IN THIS SECTION ############
#####################################################

$SmartGroup = "enter smartgroup number here"
$TagID = "enter tag id number here"

#####################################################
################ END OF SECTION #####################
#####################################################


# Import UEM Authentication script
$AuthScript = "UEMAuth.ps1"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$AuthScriptPath = Join-Path -Path $ScriptDir -ChildPath $AuthScript

# Check if the authentication script exists before proceeding
if (!(Test-Path $AuthScriptPath)) {
    Write-Host "Error: $AuthScript not found in script directory. Please ensure it is present." -ForegroundColor Red
    exit 1
}

. $AuthScriptPath  # Dot-source the authentication script

# Ensure API credentials and headers are loaded
if (-not $global:UEMHeaders -or -not $global:ws1url) {
    Write-Host "Error: Authentication script did not set required variables." -ForegroundColor Red
    exit 1
}

# Set API version
$global:version = "2"

# Obtain list of devices assigned to the product
try {
    $Response = Invoke-RestMethod -Method Get -ContentType "$global:Content" -Headers $global:UEMHeaders[$version] `
        -Uri "https://$global:ws1url/api/mdm/smartgroups/$SmartGroup/devices" -DisableKeepAlive
    
    $DeviceIDs = $Response.SmartGroupDevices.Devices.Device.Id
} catch {
    Write-Host "Error retrieving devices: $_" -ForegroundColor Red
    exit 1
}

# Validate if DeviceIDs were retrieved
if (-not $DeviceIDs) {
    Write-Host "No devices found for SmartGroup ID $SmartGroup." -ForegroundColor Yellow
    exit 1
}

# Force Reprocess Product for each device
ForEach ($DeviceID in $DeviceIDs) {
    Write-Host "Applying Tag ID $TagID for Device ID $DeviceID" -ForegroundColor Cyan

$Body = @"
<?xml version="1.0"?>
<BulkInput xmlns="http://www.air-watch.com/servicemodel/resources">
  <BulkValues>
    <Value>$DeviceID</Value>
  </BulkValues>
</BulkInput>
"@

    try {
        Invoke-RestMethod -Method Post -ContentType "$global:Content" -Headers $global:UEMHeaders[$version] `
            -Uri "https://$global:ws1url/api/mdm/tags/$TagID/adddevices" -Body $Body | Out-Null
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to add tag to Device ID $DeviceID - $ErrorMessage" -ForegroundColor Red
    }
}

Write-Host "`nScript execution completed successfully!" -ForegroundColor Green
