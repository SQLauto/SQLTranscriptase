<#
.SYNOPSIS
    Gets the Hardware/Software config of the targeted SQL server
	
.DESCRIPTION
    This script lists the Hardware and Software installed on the targeted SQL Server
    CPU, RAM, DISK, Installation and Backup folders, SQL Version, Edition, Patch Levels, Cluster/HA
	
.EXAMPLE
    01_Server_Appliance.ps1 localhost
	
.EXAMPLE
    01_Server_Appliance.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

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
	Write-Host "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Appliance.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-host "Server $SQLInstance"


# Server connection check
[string]$serverauth = "win"
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-host "Testing SQL Auth"
	try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Host $myver
            $serverauth="sql"
        }	
	}
	catch
    {
		Write-Host -f red "$SQLInstance appears offline - Try Windows Auth?"
        Set-Location $BaseFolder
		exit
	}
}
else
{
	Write-host "Testing Windows Auth"
 	Try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Host $myver
        }
	}
	catch
    {
	    Write-Host -f red "$SQLInstance appears offline - Try SQL Auth?" 
        set-location $BaseFolder
	    exit
	}
}

# Create folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Appliance"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Load SQL SMO Assembly  - let me count the ways
# Original PShell 1/2 method 
# Works fine in PS 3/4
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

# Throws error looking for version 9.0 (2005), unless 2005 is loaded, then this works fine
# Something to do with how the various libs register the verisons in the Registry?
# Yet there are 3! Ways to do this, while LoadwithPartial only has one syntax (and it works)

#Add-Type -AssemblyName “Microsoft.SqlServer.Smo” 

# 
#Add-Type –AssemblyName “Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91”
#Add-Type –AssemblyName “Microsoft.SqlServer.SmoExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91”

# 2008/R2
#Add-Type -path "C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\10.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll"

# 2012
#Add-Type -path “C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\11.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll”

# 2014
#Add-Type -path “C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\12.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll”

# Set Local Vars
[string]$server = $SQLInstance

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


# Dump info to output file
New-Item "$fullfolderPath\Server_Appliance.txt" -type file -force  |Out-Null
Add-Content -Value "Server Hardware and Software Capabilities for $SQLInstance `r`n" -Path "$fullfolderPath\Server_Appliance.txt" -Encoding Ascii

$mystring =  "Server Name: " +$srv.Name 
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Version: " +$srv.Version 
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Edition: " +$srv.EngineEdition
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Build Number: " +$srv.BuildNumber
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Product: " +$srv.Product
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Product Level: " +$srv.ProductLevel
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Processors: " +$srv.Processors
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Physical Memory: " +$srv.PhysicalMemory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Physical Memory in Use: " +$srv.PhysicalMemoryUsageinKB
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "MasterDB Path: " +$srv.MasterDBPath
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "MasterDB LogPath: " +$srv.MasterDBLogPath
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Backup Directory: " +$srv.BackupDirectory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Install Shared Dir: " +$srv.InstallSharedDirectory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Install Data Dir: " +$srv.InstallDataDirectory
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Service Account: " +$srv.ServiceAccount
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "OS Version: " +$srv.OSVersion
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Is Clustered: " +$srv.IsClustered
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "Is HADR: " +$srv.IsHadrEnabled
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

$mystring =  "`r`nSQL Builds for reference: http://sqlserverbuilds.blogspot.com/ "
$mystring| out-file "$fullfolderPath\Server_Appliance.txt" -Encoding ascii -Append

set-location $BaseFolder
