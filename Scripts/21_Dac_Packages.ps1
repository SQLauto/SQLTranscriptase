﻿<#
.SYNOPSIS
   Gets the DAC Packages registered on target server
	
.DESCRIPTION
   Writes the registered Dac Packages out to the "21 - DacPackages" folder
      
.EXAMPLE
    21_Dac_Packages.ps1 localhost
	
.EXAMPLE
    21_Dac_Packages.ps1 server01 sa password

.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
    The DAC FX APIs are in flux, So I used SQLPackage.exe which does the trick, and is installed with SQL Server
	
	George Walkey
	Richmond, VA USA

.LINK
	https://github.com/gwalkey
	
	
#>

Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "21 - DAC Packages"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./21_Dac_Packages.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Load Additional Assemblies



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

# Set Local Vars
$server = $SQLInstance


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


# Output Folder
Write-Output "$SQLInstance - Dac Packages"
$Output_path  = "$BaseFolder\$SQLInstance\21 - DAC Packages\"
if(!(test-path -path $Output_path))
{
    mkdir $Output_path | Out-Null
}


# Check for Existence of DAC Packages
Write-Output "Exporting Dac Packages..."

$myoutstring = "@ECHO OFF`n" | out-file -FilePath "$Output_path\DacExtract.cmd" -Force -Encoding ascii

foreach($sqlDatabase in $srv.databases)
{

    # Skip System Databases
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}

    # Strip brackets from DBname
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')

    # One Output folder per DB
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

    # Script Out
    $pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\100\DAC\bin\sqlpackage.exe"
    if((test-path -path $pkgexe))
    {
        $pkgver = $pkgexe
    }

    $pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\sqlpackage.exe"
    if((test-path -path $pkgexe))
    {
        $pkgver = $pkgexe
    }

    $pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\sqlpackage.exe"
    if((test-path -path $pkgexe))
    {
        $pkgver = $pkgexe
    }

    $pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\sqlpackage.exe"
    if((test-path -path $pkgexe))
    {
        $pkgver = $pkgexe
    }

    set-location $Output_path
    
    $myDB = $db.name
    $myServer = $SQLInstance   
    $myoutstring = [char]34+$pkgver + [char]34+ " /action:extract /sourcedatabasename:$myDB /sourceservername:$MyServer /targetfile:$MyDB.dacpac `n"
    $myoutstring | out-file -FilePath "$Output_path\DacExtract.cmd" -Encoding ascii -append

}

# Run the batch file
.\DacExtract.cmd

remove-item -Path "$Output_path\DacExtract.cmd" -Force -ErrorAction SilentlyContinue

# Return Home
set-location $BaseFolder



