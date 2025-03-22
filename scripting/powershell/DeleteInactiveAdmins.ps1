# Author: Jamie Marsh
# Purpose: Removes all inactive admins from EMM & CN500.
# Version History:
# 01/05/2023- v1.0 - Initial release

. C:\Scriptwork\WS1OAuth\WS1OAuthEMM.ps1
. C:\Scriptwork\WS1OAuth\WS1OAuthCN500.ps1 

# Declaring global variables
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$EMMOutput = "C:\Scriptwork\DeleteInactiveAdmins\EMMAdminIDs.txt"
$CN500Output = "C:\Scriptwork\DeleteInactiveAdmins\CN500AdminIDs.txt"
$checkemm = Test-Path "C:\Scriptwork\DeleteInactiveAdmins\EMMAdminIDs.txt"
$checkcn500 = Test-Path "C:\Scriptwork\DeleteInactiveAdmins\CN500AdminIDs.txt" 
$Proxy = "http://vzen01.internal.bunnings.com.au:80"

#Check for existing exports and remove these files
If ($checkemm -like "True")
{
Remove-Item "C:\Scriptwork\DeleteInactiveAdmins\EMMAdminIDs.txt" -Force
}
New-Item "C:\Scriptwork\DeleteInactiveAdmins\EMMAdminIDs.txt" -type file

If ($checkcn500 -like "True")
{
Remove-Item "C:\Scriptwork\DeleteInactiveAdmins\CN500AdminIDs.txt" -Force
}
New-Item "C:\Scriptwork\DeleteInactiveAdmins\CN500AdminIDs.txt" -type file


# Pulling data from Workspace One & exporting to CSV file

if(($Global:emmOAuthtimer2.Elapsed.TotalMinutes -gt 55) -or ($null -eq $Global:emmOAuthtimer2)){
    Write-Host "OAuth token expiring within 5 min or doesn't exist, requesting new token."
    $global:emmheader_v2 = Get-EMMHeader -version 2
}
if(($Global:cn500OAuthtimer2.Elapsed.TotalMinutes -gt 55) -or ($null -eq $Global:cn500OAuthtimer2)){
    Write-Host "OAuth token expiring within 5 min or doesn't exist, requesting new token."
    $global:cn500header_v2 = Get-cn500Header -version 2
}

#Pull a list of inactive admins from EMM & extract Udids
Invoke-RestMethod -Method Get -ContentType "application/xml" -headers $emmHeader_v2 -Uri "https://emm.bunnings.com.au/api/system/admins/search?status=Inactive" -DisableKeepAlive -Verbose -Proxy $Proxy | `
Select-Object -ExpandProperty AdminSearchResultv2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Admins | `
Select-Object -ExpandProperty AdminUserv2 | Select-Object -ExpandProperty Uuid | Out-File $EMMOutput -Append
 
#Delete inactive admins in EMM based on Udids
Get-Content $EMMOutput | ForEach-Object {
Write-Host "Deleting admin account in EMM with ID $_"
Invoke-RestMethod -Method Delete -ContentType "application/xml" -headers $emmHeader_v2 -Uri "https://emm.bunnings.com.au/api/system/admins/$_" -DisableKeepAlive -Verbose -Proxy $Proxy }

#Pull a list of inactive admins from CN500 & extract Udids
Invoke-RestMethod -Method Get -ContentType "application/xml" -headers $cn500Header_v2 -Uri "https://cn500.airwatchportals.com/api/system/admins/search?status=Inactive" -DisableKeepAlive -Verbose -Proxy $Proxy | `
Select-Object -ExpandProperty AdminSearchResultv2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Admins | `
Select-Object -ExpandProperty AdminUserv2 | Select-Object -ExpandProperty Uuid | Out-File $CN50
#Delete inactive admins in CN500 based on Udids
Get-Content $CN500Output | ForEach-Object {
Write-Host "Deleting admin account in CN500 with ID $_"
Invoke-RestMethod -Method Delete -ContentType "application/xml" -headers $cn500Header_v2 -Uri "https://cn500.airwatchportals.com/api/system/admins/$_" -DisableKeepAlive -Verbose -Proxy $Proxy }
#>