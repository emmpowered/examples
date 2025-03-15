<#	
	.NOTES
	===========================================================================
	 Created on:   	07/01/2021
	 Created by:   	Jamie Marsh - https://emmpowered.blog
	 Filename:     	ForceReprocess.ps1
   Version:       2.0
	===========================================================================
	.DESCRIPTION
		This script force reprocesses a specific product for all devices it has been assigned to.
		Please specify the following values in the variable sections directly below:
			Smart Group number
			Product Number/Id
        To run this script, you may need to modify the Powershell Execution Policy from the Powershell CLI, using the following command:
			Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
		This is a temporary settings that change only applies for the current powershell session.  
		For scheduled tasks or automation, please run the UEMAuth.ps1 script manually once to generate the required credentials XML file
		#>

#####################################################
######## SET YOUR VALUES IN THIS SECTION ############
#####################################################

$SmartGroup = "enter smartgroup number here"
$ProductNumber = "enter product number here"

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
    Write-Host "Force re-processing product $ProductNumber for Device ID $DeviceID" -ForegroundColor Cyan

    $Body = @"
<?xml version="1.0"?>
<ReprocessProductInputEntity>
  <ForceFlag>true</ForceFlag>
  <DeviceIds>
    <DeviceIds>
      <ID>$DeviceID</ID>
    </DeviceIds>
  </DeviceIds>
  <ProductID>$ProductNumber</ProductID>
</ReprocessProductInputEntity>
"@

    try {
        Invoke-RestMethod -Method Post -ContentType "$global:Content" -Headers $global:UEMHeaders[$version] `
            -Uri "https://$global:ws1url/api/mdm/products/reprocessProduct" -Body $Body
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to reprocess product for device $DeviceID - $ErrorMessage" -ForegroundColor Red
    }
}

Write-Host "\nScript execution completed successfully!" -ForegroundColor Green
