<#
.SYNOPSIS
    Gets the Hardware/Software Inventory of the target SQL server
	
.DESCRIPTION
    This script lists the Hardware and Software installed on the targeted SQL Server
    CPU, RAM, DISK, Installation and Backup folders, SQL Version, Edition, Patch Levels, Cluster/HA
	
.EXAMPLE
    01_Server_Appliance.ps1 localhost
	
.EXAMPLE
    01_Server_Appliance.ps1 server01 sa password

.Inputs
    ServerName\Instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
    George Walkey
    Richmond, VA USA
	
.LINK
    https://github.com/gwalkey
	
#>

Param(
    [parameter(Position=0,mandatory=$false,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLInstance,

    [parameter(Position=1,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,20)]
    [string]$myuser,

    [parameter(Position=2,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,35)]
    [string]$mypass
)


[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Import-Module "sqlps" -DisableNameChecking -erroraction SilentlyContinue


#  Script Name
Write-Host -f Yellow -b Black "01 - Server Appliance"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$SQLInstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-Host -f yellow "Usage: ./01_Server_Appliance.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

# fix target servername if given a SQL named instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

# Server connection check
try
{
    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Output "Testing SQL Auth"
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
    	$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
        $serverauth = "win"
    }

    if($results -ne $null)
    {        
        Write-Output ("SQL Version: {0}" -f $results.Column1)
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 	

}
catch
{
    Write-Host -f red "$SQLInstance appears offline - Try Windows Auth?"
    Set-Location $BaseFolder
	exit
}

# Create folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Appliance"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Load SQL SMO Assemblies  - let me count the ways
# Original PShell 1/2 method is LoadWithPartialName
# Works fine in PS 3/4
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

# Throws error looking for version 9.0 (2005), unless 2005 is loaded, then it works fine
# Something to do with how the various libs register the verisons in the Registry
# Yet there are 3 Ways to do this, while LoadwithPartial only has one syntax (and it seems to work everywhere)

#Add-Type -AssemblyName “Microsoft.SqlServer.Smo”
#Add-Type –AssemblyName “Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91”
#Add-Type –AssemblyName “Microsoft.SqlServer.SmoExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91”

# 2008/R2
#Add-Type -path "C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\10.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll"

# 2012
#Add-Type -path “C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\11.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll”

# 2014
#Add-Type -path “C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\12.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll”

# 2016
#Add-Type -path “C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\13.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll”

# Set Local Vars
[string]$server = $SQLInstance

# Create SMO Server Object
if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)    
}


# Create output text file and add first line
New-Item "$fullfolderPath\Server_Appliance.txt" -type file -force  |Out-Null
Add-Content -Value "Server Hardware and Software Inventory for $SQLInstance `r`n" -Path "$fullfolderPath\Server_Appliance.txt" -Encoding Ascii

$mystring =  "Server Name: " +$srv.Name 
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Version: " +$srv.Version 
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Edition: " +$srv.EngineEdition
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Build Number: " +$srv.BuildNumber
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Product: " +$srv.Product
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Product Level: " +$srv.ProductLevel
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Processors: " +$srv.Processors
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Max Physical Memory MB: " +$srv.PhysicalMemory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Physical Memory in Use MB: " +$srv.PhysicalMemoryUsageinKB
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL MasterDB Path: " +$srv.MasterDBPath
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL MasterDB LogPath: " +$srv.MasterDBLogPath
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Backup Directory: " +$srv.BackupDirectory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Install Shared Dir: " +$srv.InstallSharedDirectory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Install Data Dir: " +$srv.InstallDataDirectory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "SQL Service Account: " +$srv.ServiceAccount
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

" " | out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

 
# Windows
$mystring =  "OS Version: " +$srv.OSVersion
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "OS Is Clustered: " +$srv.IsClustered
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "OS Is HADR: " +$srv.IsHadrEnabled
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring = Get-WmiObject –class Win32_OperatingSystem -ComputerName $server | select Name, BuildNumber, BuildType, CurrentTimeZone, InstallDate, SystemDrive, SystemDevice, SystemDirectory
Write-output ("OS Host Name: {0} " -f $mystring.Name)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("OS BuildNumber: {0} " -f $mystring.BuildNumber)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("OS Buildtype: {0} " -f $mystring.BuildType)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("OS CurrentTimeZone: {0}" -f $mystring.CurrentTimeZone)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("OS InstallDate: {0} " -f $mystring.InstallDate)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("OS SystemDrive: {0} " -f $mystring.SystemDrive)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("OS SystemDevice: {0} " -f $mystring.SystemDevice)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("OS SystemDirectory: {0} " -f $mystring.SystemDirectory)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append


" " | out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

# Hardware
$mystring = Get-WmiObject -class Win32_Computersystem -ComputerName $server | select manufacturer
Write-output ("HW Manufacturer: {0} " -f $mystring.Manufacturer)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring = Get-WmiObject –class Win32_processor -ComputerName $server | select Name,NumberOfCores,NumberOfLogicalProcessors
Write-output ("HW Processor: {0} " -f $mystring.Name)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("HW CPUs: {0}" -f $mystring.NumberOfLogicalProcessors)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append
Write-output ("HW Cores: {0}" -f $mystring.NumberOfCores)| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "`r`nSQL Builds for reference: http://sqlserverbuilds.blogspot.com/ "
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

# Return To Base
set-location $BaseFolder
