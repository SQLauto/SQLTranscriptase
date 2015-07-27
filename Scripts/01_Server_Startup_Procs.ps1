<#
.SYNOPSIS
    Gets the Stored Procedures in the Master Database from the target server
    These procs automatially run when the Instance starts up
    SSIS_Cleanup and DQS install some startup procs here

.DESCRIPTION
	Writes out any Stored Procedure from Master into SQL files in the "01 - Server Startup Procs" folder


.EXAMPLE
    01_Server_Startup_Procs.ps1 localhost

.EXAMPLE
    01_Server_Startup_Procs.ps1 server01 sa password

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

Write-Host  -f Yellow -b Black "01 - Server Startup Stored Procedures"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Startup_Procs.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    exit
}


# Working
Write-Output "Server $SQLInstance"


# Server connection check
$serverauth = "win"
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1)
{
	Write-Output "Testing SQL Auth"
	try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Output $myver
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
	Write-Output "Testing Windows Auth"
 	Try{
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

function CopyObjectsToFiles($objects, $outDir) {
	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | out-null
	}
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
			if ($o.Schema -ne $null -and $o.Schema -ne "") {
				$schemaPrefix = $o.Schema + "."
			}
		
			$fixedOName = $o.name.replace('\','_')			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $fixedOName + ".sql"			
			$scripter.EnumScript($o)
		}
	}
}



# Load SQL SMO Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

# Set Local Vars
$server = $SQLInstance

if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $scripter = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)
}

$db 	= New-Object ("Microsoft.SqlServer.Management.SMO.Database")

# Set scripter options to ensure only data is scripted
$scripter.Options.ScriptSchema 	= $true;
$scripter.Options.ScriptData 	= $false;

# Add your favorite options from 
# https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.scriptingoptions.aspx
# https://www.simple-talk.com/sql/database-administration/automated-script-generation-with-powershell-and-smo/
$scripter.Options.AllowSystemObjects 	= $false
$scripter.Options.AnsiFile 				= $true

$scripter.Options.ClusteredIndexes 		= $true

$scripter.Options.DriAllKeys            = $true
$scripter.Options.DriForeignKeys        = $true
$scripter.Options.DriChecks             = $true
$scripter.Options.DriPrimaryKey         = $true
$scripter.Options.DriUniqueKeys         = $true
$scripter.Options.DriWithNoCheck        = $true
$scripter.Options.DriAllConstraints 	= $true
$scripter.Options.DriIndexes 			= $true
$scripter.Options.DriClustered 			= $true
$scripter.Options.DriNonClustered 		= $true

$scripter.Options.EnforceScriptingOptions 	= $true
$scripter.Options.ExtendedProperties    = $true

$scripter.Options.FullTextCatalogs      = $true
$scripter.Options.FullTextIndexes 		= $true
$scripter.Options.FullTextStopLists     = $true
$scripter.Options.IncludeFullTextCatalogRootPath= $true


$scripter.Options.IncludeHeaders        = $false
$scripter.Options.IncludeDatabaseRoleMemberships= $true
$scripter.Options.Indexes 				= $true

$scripter.Options.NoCommandTerminator 	= $false;
$scripter.Options.NonClusteredIndexes 	= $true

$scripter.Options.NoTablePartitioningSchemes = $false

$scripter.Options.Permissions 			= $true

$scripter.Options.SchemaQualify 		= $true
$scripter.Options.SchemaQualifyForeignKeysReferences = $true

$scripter.Options.ToFileOnly 			= $true


# WithDependencies create one huge file for all tables in the order needed to maintain RefIntegrity
$scripter.Options.WithDependencies		= $false
$scripter.Options.XmlIndexes            = $true

Write-Output "Starting Export..."

# Master DB Only
$sqlDatabase = $srv.Databases['Master']

# Script out objects for each DB
$db = $sqlDatabase
$fixedDBName = $db.name.replace('[','')
$fixedDBName = $fixedDBName.replace(']','')
$output_path = "$BaseFolder\$SQLInstance\01 - Server Startup Procs\"

# Get list of User SPs in Master
Write-Output "$fixedDBName - Stored Procs"

$storedProcs = $db.StoredProcedures | Where-object  {-not $_.IsSystemObject  }
CopyObjectsToFiles $storedProcs $output_path

# Return to Base
set-location $BaseFolder

