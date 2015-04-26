﻿<#
.SYNOPSIS
    Gets the Managed Backups on the target server
	
.DESCRIPTION
   Writes the SQL Server Credentials out to the "17 - Managed Backups" folder
   Saves the Master Switch settings to the file "Managed_Backups_Server_Settings.sql"
   And the Managed Backup settings for each Database into its own folder with the filename "Managed_Backup_Settings.sql"
   Managed Backups save your Databases automatically to Azure Blob Storage using a Container and locally stored Credentials
   
.EXAMPLE
    17_Managed_Backups.ps1 localhost
	
.EXAMPLE
    17_Managed_Backups.ps1 server01 sa password

.NOTES
    George Walkey
    Richmond, VA USA

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs


.LINK
    https://github.com/gwalkey
#>

Param(
  [string]$SQLInstance,
  [string]$myuser,
  [string]$mypass
)


[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "17 - Managed Backups"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./17_Managed_Backups.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-host "Server $SQLInstance"

import-module "sqlps" -DisableNameChecking -erroraction SilentlyContinue

# Server connection check
$serverauth = "win"
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
        Set-Location $BaseFolder
	    exit
	}
}

# Bail out if not 2014 or greater
[int]$ver = $myver.Substring(0,$myver.IndexOf('.'))

IF ( $ver -eq "7" )
{
   Write-Host "SQL Server 7"
}

IF ( $ver -eq "8" )
{
   Write-Host "SQL Server 2000"
}

IF ( $ver -eq "9" )
{
   Write-Host "SQL Server 2005"
}

IF ( $ver -eq "10" )
{
   Write-Host "SQL Server 2008/R2"
}

IF ( $ver -eq "11" )
{
   Write-Host "SQL Server 2012"
}

IF ( $ver -eq "12" )
{
   Write-Host "SQL Server 2014"
}

# Bail if not 2014 or greater
if ($ver -lt 12)
{
    Write-Host "Not 2014 or greater...exiting"
    echo null > "$BaseFolder\$SQLInstance\17 - Managed Backups - Requires SQL 2014 or greater.txt"
    Set-Location $BaseFolder    
    exit
}

# Load SQL SMO Assemblies
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended') | out-null


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


# Create output folder
$output_path = "$BaseFolder\$SQLInstance\17 - Managed Backups\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

# Bail if Managed Backups not setup yet, nothing to do
if ($srv.smartadmin.isenabled -eq "false")
{
    set-location $BaseFolder
    exit
}

# Export Server-Level Settings
New-Item "$output_path\Managed_Backups_Server_Settings.sql" -type file -force  |Out-Null

# MB Master Switch
Add-Content -Value "--- Managed Backups Configuration for $SQLInstance `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
Add-Content -Value "--- Master Switch `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
if ($srv.SmartAdmin.MasterSwitch -eq "true")
{
    Add-Content -Value "EXEC [msdb].[smart_admin].[sp_backup_master_switch] @new_state  = 1; `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
}
else
{
    Add-Content -Value "EXEC [msdb].[smart_admin].[sp_backup_master_switch] @new_state  = 0; `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
}

# Instance-Level Default Settings
[string]$strEXEC = "EXEC [msdb].[smart_admin].[sp_set_instance_backup] "

Add-Content -Value "--- Default Instance-Level Settings for $SQLInstance `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
if ($srv.SmartAdmin.BackupEnabled -eq "true")
{
    $strEXEC += " `r`n @enable_backup = 1 `r`n"
}
else
{
    $strEXEC += " `r`n @enable_backup = 0 `r`n"
}


$strEXEC += " ,@retention_days = "        + $srv.smartadmin.BackupRetentionPeriodInDays+" `r`n"
$strEXEC += " ,@credential_name = N'"     + $srv.smartadmin.CredentialName+"' `r`n"
$strEXEC += " ,@storage_url= N'"          + $srv.smartadmin.StorageUrl+"' `r`n"
$strEXEC += " ,@encryption_algorithm= N'" + $srv.smartadmin.EncryptionAlgorithm+"' `r`n"
$strEXEC += " ,@encryptor_type= N'"       + $srv.smartadmin.EncryptorType+"' `r`n"
$strEXEC += " ,@encryptor_name= N'"       + $srv.smartadmin.EncryptorName+"'; `r`n"


# push out concatenated string
Add-Content $strEXEC -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii

$mySQLquery = "USE msdb; SELECT `
db_name, 
is_managed_backup_enabled, 
storage_url, 
retention_days, 
credential_name, 
encryption_algorithm, 
encryptor_type, 
encryptor_name
FROM
smart_admin.fn_backup_db_config(null) where is_managed_backup_enabled=1
order by 1
"


# connect correctly
if ($serverauth -eq "win")
{
    $sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
    $sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}

# Script out
foreach ($MB in $sqlresults)
{    
    $db = $MB.db_name
    $fixedDBName = $db.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $DBOutput_path = "$BaseFolder\$SQLInstance\17 - Managed Backups\$fixedDBname"

    # Only create path if something to write
    if(!(test-path -path $DBOutput_path))
    {
        mkdir $DBOutput_path | Out-Null
    }

    $myoutputfile   = $DBOutput_path+"\Managed_Backup_Settings.sql"
    $myoutputstring = "--- Managed Backup for " + $fixedDBName + " `r`n"
    $myoutputstring += "Use msdb  `r`nGO `r`n`r`n EXEC smart_admin.sp_set_db_backup `r`n"
    $myoutputstring += " @database_name='"+ $MB.db_name+ "' `r`n"
    $myoutputstring += " ,@enable_backup=1 `r`n"
    $myoutputstring += " ,@storage_url= '" + $MB.storage_url + "' `r`n"
    $myoutputstring += " ,@retention_days= '" + $MB.retention_days + "' `r`n"
    $myoutputstring += " ,@credential_name= N'" + $MB.credential_name + "' `r`n"
    $myoutputstring += " ,@encryption_algorithm= N'" + $MB.encryption_algorithm + "' `r`n"
    $myoutputstring += " ,@encryptor_type= N'" + $MB.encryptor_type + "' `r`n"
    $myoutputstring += " ,@encryptor_name= N'" + $MB.encryptor_name + "' `r`n"

    $myoutputstring | out-file -FilePath $myoutputfile -append -encoding ascii -width 500
}

# finish
set-location $BaseFolder
