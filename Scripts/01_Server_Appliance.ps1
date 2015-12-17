﻿<#
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

	
.LINK
	https://github.com/gwalkey/SQLTranscriptase
	
#>

Param(
    [parameter(Position=0,mandatory=$false,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLInstance='localhost',

    [parameter(Position=1,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,20)]
    [string]$myuser,

    [parameter(Position=2,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,35)]
    [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Import-Module "sqlps" -DisableNameChecking -erroraction SilentlyContinue
Import-Module ".\LoadSQLSMO"
LoadSQLSMO


#  Script Name
Write-Host -f Yellow -b Black "01 - Server Appliance"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Appliance.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
		# .NET Method
		# Open connection and Execute sql against server
		$DataSet = New-Object System.Data.DataSet
		$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = "select serverproperty('productversion')"
		$SqlCmd.Connection = $Connection
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd
    
		# Insert results into Dataset table
		$SqlAdapter.Fill($DataSet) | out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

		# SQLCMD.EXE Method
        #$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
		# .NET Method
		# Open connection and Execute sql against server using Windows Auth
		$DataSet = New-Object System.Data.DataSet
		$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = "select serverproperty('productversion')"
		$SqlCmd.Connection = $Connection
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd
    
		# Insert results into Dataset table
		$SqlAdapter.Fill($DataSet) | out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

		# SQLCMD.EXE Method
    	#$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
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
    Write-Host -f red "$SQLInstance appears offline - Try Windows Authorization."
    Set-Location $BaseFolder
	exit
}


# Create folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Appliance"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


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
$fullFileName = $fullfolderPath+"\Server_Appliance.txt"
New-Item $fullFileName -type file -force  |Out-Null
Add-Content -Value "Server Hardware and Software Capabilities for $SQLInstance `r`n" -Path $fullFileName -Encoding Ascii

# SQL
$mySQLQuery1 = 
"SELECT	[updatedate] AS 'column1'
FROM	[sys].[syslogins]
WHERE	[sid] = 0x01
"

# connect correctly
if ($serverauth -eq "win")
{
    $sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery1 -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
    $sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery1 -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}

$myCreateDate = $sqlresults.column1
$mystring =  "Server Create Date: " +$MyCreateDate
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "Server Name: " +$srv.Name 
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Version: " +$srv.Version 
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Edition: " +$srv.EngineEdition
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Build Number: " +$srv.BuildNumber
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Product: " +$srv.Product
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Product Level: " +$srv.ProductLevel
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Processors: " +$srv.Processors
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Max Physical Memory MB: " +$srv.PhysicalMemory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Physical Memory in Use MB: " +$srv.PhysicalMemoryUsageinKB
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL MasterDB Path: " +$srv.MasterDBPath
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL MasterDB LogPath: " +$srv.MasterDBLogPath
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Backup Directory: " +$srv.BackupDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Install Shared Dir: " +$srv.InstallSharedDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Install Data Dir: " +$srv.InstallDataDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Service Account: " +$srv.ServiceAccount
$mystring | out-file $fullFileName -Encoding ascii -Append

" " | out-file $fullFileName -Encoding ascii -Append

# Windows
$mystring =  "OS Version: " +$srv.OSVersion
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Is Clustered: " +$srv.IsClustered
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Is HADR: " +$srv.IsHadrEnabled
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Platform: " +$srv.Platform
$mystring | out-file $fullFileName -Encoding ascii -Append


# Turn off default Error Handler for WMI
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

$mystring2 = Get-WmiObject –class Win32_OperatingSystem -ComputerName $server | select Name, BuildNumber, BuildType, CurrentTimeZone, InstallDate, SystemDrive, SystemDevice, SystemDirectory

# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference

try
{
    Write-output ("OS Host Name: {0} " -f $mystring2.Name)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("OS BuildNumber: {0} " -f $mystring2.BuildNumber)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("OS Buildtype: {0} " -f $mystring2.BuildType)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("OS CurrentTimeZone: {0}" -f $mystring2.CurrentTimeZone)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("OS InstallDate: {0} " -f $mystring2.InstallDate)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("OS SystemDrive: {0} " -f $mystring2.SystemDrive)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("OS SystemDevice: {0} " -f $mystring2.SystemDevice)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("OS SystemDirectory: {0} " -f $mystring2.SystemDirectory)| out-file $fullFileName -Encoding ascii -Append
}
catch
{
    Write-output "Error getting OS specs via WMI - WMI/firewall issue?"| out-file $fullFileName -Encoding ascii -Append
    Write-output "Error getting OS specs via WMI - WMI/firewall issue?"
}

" " | out-file $fullFileName -Encoding ascii -Append

# Hardware

# Motherboard
# Turn off default Error Handler for WMI
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

$mystring3 = Get-WmiObject -class Win32_Computersystem -ComputerName $server | select manufacturer

# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference

try
{
    Write-output ("HW Manufacturer: {0} " -f $mystring3.Manufacturer)| out-file $fullFileName -Encoding ascii -Append
}
catch
{
    Write-output "Error getting Hardware specs via WMI - WMI/firewall issue? "| out-file $fullFileName -Encoding ascii -Append
    Write-output "Error getting Hardware specs via WMI - WMI/firewall issue? "
}

" " | out-file $fullFileName -Encoding ascii -Append

# Proc, CPUs, Cores
# Turn off default Error Handler for WMI
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

$mystring4 = Get-WmiObject –class Win32_processor -ComputerName $server | select Name,NumberOfCores,NumberOfLogicalProcessors

# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference

try
{
    Write-output ("HW Processor: {0} " -f $mystring4.Name)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("HW CPUs: {0}" -f $mystring4.NumberOfLogicalProcessors)| out-file $fullFileName -Encoding ascii -Append
    Write-output ("HW Cores: {0}" -f $mystring4.NumberOfCores)| out-file $fullFileName -Encoding ascii -Append
}
catch
{
    Write-output "Error getting CPU specs via WMI - WMI/Firewall issue? "| out-file $fullFileName -Encoding ascii -Append
    Write-output "Error getting CPU specs via WMI - WMI/Firewall issue? "
}

" " | out-file $fullFileName -Encoding ascii -Append


# PowerPlan
# Turn off default Error Handler for WMI
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

$mystring41 = Get-WmiObject -namespace "root\cimv2\power" –class Win32_PowerPlan -ComputerName $server | where {$_.IsActive} | select ElementName

# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference

try
{
    Write-output ("PowerPlan: {0} " -f $mystring41.ElementName)| out-file $fullFileName -Encoding ascii -Append    
}
catch
{
    Write-output "Error getting PowerPlan via WMI - WMI/Firewall issue? "| out-file $fullFileName -Encoding ascii -Append
    Write-output "Error getting PowerPlan via WMI - WMI/Firewall issue? "
}

" " | out-file $fullFileName -Encoding ascii -Append


# PowerShell Version
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

$MyPSVersion = Invoke-Command -ComputerName $SQLInstance -ScriptBlock {$PSVersionTable.PSVersion.Major}
if ($MyPSVersion -ne $null)
{    
    $mystring =  "Powershell Version: " +$myPSVersion
}
else
{
    $mystring =  "Powershell Version: Unknown"
}
$mystring | out-file $fullFileName -Encoding ascii -Append


$ErrorActionPreference = $old_ErrorActionPreference

# Footer
$mystring5 =  "`r`nSQL Build reference: http://sqlserverbuilds.blogspot.com/ "
$mystring5| out-file $fullFileName -Encoding ascii -Append

$mystring5 =  "`r`nSQL Build reference: http://sqlserverupdates.com/ "
$mystring5| out-file $fullFileName -Encoding ascii -Append


$mystring5 = "`r`nMore Detailed Diagnostic Queries here:`r`nhttp://www.sqlskills.com/blogs/glenn/sql-server-diagnostic-information-queries-for-september-2015"
$mystring5| out-file $fullFileName -Encoding ascii -Append

# Dump out loaded DLLs
$mySQLquery = "select * from sys.dm_os_loaded_modules order by name"

# connect correctly
if ($serverauth -eq "win")
{
    $sqlresults2 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
    $sqlresults2 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}

# Create some CSS for help in column formatting during HTML exports
$myCSS = 
"
table
    {
        Margin: 0px 0px 0px 4px;
        Border: 1px solid rgb(190, 190, 190);
        Font-Family: Tahoma;
        Font-Size: 9pt;
        Background-Color: rgb(252, 252, 252);
    }
tr:hover td
    {
        Background-Color: rgb(150, 150, 220);
        Color: rgb(255, 255, 255);
    }
tr:nth-child(even)
    {
        Background-Color: rgb(242, 242, 242);
    }
th
    {
        Text-Align: Left;
        Color: rgb(150, 150, 220);
        Padding: 1px 4px 1px 4px;
    }
td
    {
        Vertical-Align: Top;
        Padding: 1px 4px 1px 4px;
    }
"
# CSS file
if(!(test-path -path "$fullfolderPath\HTMLReport.css"))
{
    $myCSS | out-file "$fullfolderPath\HTMLReport.css" -Encoding ascii    
}

$RunTime = Get-date
$sqlresults2 | select file_version, product_version, debug, patched, prerelease, private_build, special_build, language, company, description, name `
| ConvertTo-Html    -PostContent "<h3>Ran on : $RunTime</h3>" -PreContent "<h1>$SqlInstance</H1><H2>Loaded DLLs</h2>" -CSSUri "HtmlReport.css" | Set-Content "$fullfolderPath\02_Loaded_Dlls.html"


# Dump Trace Flags
$mySQLquery2= "dbcc tracestatus()"

# connect correctly
if ($serverauth -eq "win")
{
    $sqlresults3 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery2 -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
    $sqlresults3 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery2 -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}

if ($sqlresults3 -ne  $null)
{
    $sqlresults3 | select TraceFlag, Status, Global, Session | ConvertTo-Html   -PostContent "<h3>Ran on : $RunTime</h3>" -PreContent "<h1>$SqlInstance</H1><H2>Trace Flags</h2>"  -CSSUri "HtmlReport.css" | Set-Content "$fullfolderPath\03_Trace_Flags.html"
}


# Return to Base
set-location $BaseFolder
