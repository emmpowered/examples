<#	
	.NOTES
	===========================================================================
	 Created on:   	09/03/2025
	 Created by:   	Jamie Marsh - https://emmpowered.blog
	 Filename:     	UEMAuth.ps1
     Version:       5.0
	===========================================================================
	.DESCRIPTION 
		This script is called on by other scripts to set Workspace One UEM tenant variables, request OAuth Tokens & generate headers required for these scripts to successfully run. 
		For scheduled tasks or automation, please run this script manually once to generate the required credentials XML file   
		Please specify the following values in the variable sections directly below:
		1. ASnumber - environment server number, eg. 500
		2. Domain - either awmdm.com, airwatchportals.com or your own custom URL if you have one
		3. Region - used to obtain OAuth tokens from the correct data centre for your Region
#>

#####################################################
######## SET YOUR VALUES IN THIS SECTION ############
#####################################################

# Set your UEM environment details
$global:ASnumber = "as" + "NNN" # replace NNN with number for your tenant eg. 500
$global:Domain = "airwatchportals.com" # you may need to change this to awmdm.com for your UEM tenant, or specify a custom domain if you have one
$global:WS1url = $global:ASnumber + "." + $global:domain

# Set your Workspace ONE UEM SaaS Data Center Location
$global:Region = "None" # Set this value to US, Canada, UK, Germany, India, Japan, Singapore, Australia or Hong Kong depending on the Data Centre location of your UEM Tenant

#####################################################
################ END OF SECTION #####################
#####################################################

# Set additional variables
$global:Content = "application/xml"

# Set location for OAuth Credentials file
$CredentialsFile = "$(Get-Location)\UEMCredentials.xml"

# Get the name of the calling script
$CallingScript = if ($MyInvocation.ScriptName) { [System.IO.Path]::GetFileName($MyInvocation.ScriptName) } else { "Unknown Script" }

# Try to generate the credentials file
function Prompt-ForCredentials {
    try {
        # Prompt for credentials and export to an XML file
        Get-Credential | Export-CliXml -Path $CredentialsFile
        Write-Host "Credentials generation successful." -ForegroundColor Green
    } catch {
        Write-Host "Error: Generating credentials file failed, retrying..." -ForegroundColor Red
    }
}

# Initial credentials prompt
Prompt-ForCredentials

# Check if the credentials file was created, if not, prompt again
if (!(Test-Path $CredentialsFile)) {
    Write-Host "Credentials file not found. Please enter credentials again." -ForegroundColor Yellow
    Prompt-ForCredentials
    
    # Final check, exit if still missing
    if (!(Test-Path $CredentialsFile)) {
        Write-Host "Error: Credentials file not created. Exiting." -ForegroundColor Red
        throw "Halting execution of '$CallingScript' due to an error."
    }
}

# Import XML with encrypted credentials for OAuth Token requests
try {
    $Credentials = Import-CliXml -Path $CredentialsFile
    Write-Host "`nCredentials successfully loaded from '$CredentialsFile'" -ForegroundColor Green
} catch {
    Write-Host "Error: Importing credentials file failed. Exiting." -ForegroundColor Red
    throw "Halting execution of '$CallingScript' due to an error."
}


# Define the mapping of regions to token URLs
$DataCentres = @{
    "US"         = "https://na.uemauth.vmwservices.com/connect/token"
    "Canada"     = "https://na.uemauth.vmwservices.com/connect/token"
    "UK"         = "https://emea.uemauth.vmwservices.com/connect/token"
    "Germany"    = "https://emea.uemauth.vmwservices.com/connect/token"
    "India"      = "https://apac.uemauth.vmwservices.com/connect/token"
    "Japan"      = "https://apac.uemauth.vmwservices.com/connect/token"
    "Singapore"  = "https://apac.uemauth.vmwservices.com/connect/token"
    "Australia"  = "https://apac.uemauth.vmwservices.com/connect/token"
    "Hong Kong"  = "https://apac.uemauth.vmwservices.com/connect/token"
}

# Set the access token URL based on the selected region, and display this information on screen.
if ($DataCentres.ContainsKey($global:Region)) {
    $TokenURL = $DataCentres[$global:Region]
    Write-Host "`nRegion has been set to " -NoNewline
    Write-Host "$global:Region" -ForegroundColor Magenta -NoNewline
    Write-Host ", Token URL set to " -NoNewline
    Write-Host "$TokenURL" -ForegroundColor Green
} else {
    Write-Host "`nInvalid region specified. Please re-run the script after specifying a valid region in UEMAuth.ps1 file." -ForegroundColor Red
    throw "Halting execution of '$CallingScript' due to an error."
}

# Function to retrieve OAuth Token from Workspace One UEM
Function Get-OAuthUEMToken {
$ClientID = $Credentials.GetNetworkCredential().UserName
$ClientSecret = $Credentials.GetNetworkCredential().Password
$TokenBody = @{
	grant_type    = "client_credentials"
	client_id     = $ClientID
	client_secret = $ClientSecret
}
$UEMResponse = Invoke-WebRequest -Method Post -Uri $TokenURL -Body $TokenBody -UseBasicParsing
$UEMResponse = $UEMResponse | ConvertFrom-Json
$OAuthToken = [string]$($UEMResponse.access_token)

Return $OAuthToken
}

# Function to create UEM headers including OAuth Token for Workspace One UEM API calls
Function Get-UEMHeader {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$version
    )

    $Token = Get-OAuthUEMToken

    $global:UEMHeaders[$version] = @{
        "Authorization" = "Bearer $Token"
        "Accept"        = "application/xml;version=$global:version"
        "Content-Type"  = "$global:Content"
    }
    return $UEMHeader
}

# Initialize headers and timers globally
$global:UEMHeaders = @{}
$global:UEMOAuthTimers = @{}

# Generate headers for API versions 1 to 4
for ($i = 1; $i -le 4; $i++) {
    $global:UEMHeaders[$i] = Get-UEMHeader -version $i
    $global:UEMOAuthTimers[$i] = [System.Diagnostics.Stopwatch]::StartNew()
}

# Check expiration for all versions and refresh if needed
foreach ($i in 1..4) {
    if (-not $global:UEMOAuthTimers.ContainsKey($i) -or $global:UEMOAuthTimers[$i].Elapsed.TotalMinutes -gt 55) {
        Write-Host "OAuth token for version $i expiring within 5 min or doesn't exist, requesting new token."
        $global:UEMHeaders[$i] = Get-UEMHeader -version $i
        $global:UEMOAuthTimers[$i] = [System.Diagnostics.Stopwatch]::StartNew()
    }
}
