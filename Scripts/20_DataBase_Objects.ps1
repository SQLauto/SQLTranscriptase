<#
.SYNOPSIS
    Gets the core Database Objects on the target server

.DESCRIPTION
	Writes the Objects out into subfolders in the "20 - DataBase Objects" folder
	Scripted Objects include:
	DataBase Triggers
	Filegroups
	Full Text Catalogs
	Schemas
    Sequences
	Stored Procedures
	Synonyms
	Tables
	Table Triggers
	User Defined Functions
	User Defined Table Types
	Views	


.EXAMPLE
    20_DataBase_Objects.ps1 localhost

.EXAMPLE
    20_DataBase_Objects.ps1 server01 sa password

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

Write-Host  -f Yellow -b Black "20 - DataBase Objects (Triggers, Tables, Views, Procs, UDFs, FullTextCats, TableTypes, Schemas)"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./20_DataBase_Objects.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    exit
}


# Working
Write-host "Server $SQLInstance"


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
 	Try{
    $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
    if($results -ne $null)
    {
        $myver = $results.Column1
        #Write-Host $myver
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
$tbl	= New-Object ("Microsoft.SqlServer.Management.SMO.Table")


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


# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}

    # Script out objects for each DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\20 - DataBase Objects\$fixedDBname"

    # paths
    $table_path 		= "$output_path\Tables\"
    $TableTriggers_path	= "$output_path\TableTriggers\"
    $views_path 		= "$output_path\Views\"
    $storedProcs_path 	= "$output_path\StoredProcedures\"
    $udfs_path 			= "$output_path\UserDefinedFunctions\"
    $textCatalog_path 	= "$output_path\FullTextCatalogs\"
    $udtts_path 		= "$output_path\UserDefinedTableTypes\"
    $DBTriggers_path 	= "$output_path\DBTriggers\"
    $Schemas_path       = "$output_path\Schemas\"
    $Filegroups_path    = "$output_path\Filegroups\"
    $Sequences_path     = "$output_path\Sequences\"
    $Synonyms_path      = "$output_path\Synonyms\"


    #Get Objects via SMO into PS Objects
    # Mar 10, 2015 - OK this is where .NET gobbles memory, so switch to this:
    # 1) Load objects from server
    # 2) Write objects to disk file
    # 3) Set variables to null
    # 4) Let GC (hopefully) do its nefarious job of cleanup 
    # 5) Does it work?  Testing a batch file running against 22 SQL servers still uses about 16Gigs 'O Ram, even though the ps1 files are called in a chain,
    #    giving GC a chance to release memory between powershell.exe sessions, but doesnt.
    #    Swell.

    <#
    Write-Host "Starting Memory: $db"
    [System.gc]::gettotalmemory("forcefullcollection") /1MB

    ps powershell* | Select *memory* | ft -auto `
    @{Name='VirtualMemMB';Expression={($_.VirtualMemorySize64)/1MB}}, `
    @{Name='PrivateMemMB';Expression={($_.PrivateMemorySize64)/1MB}}
    #>

    
    # All Database Properties
    $DBSettingsPath = $output_path+"\Settings"

    if(!(test-path -path $DBSettingsPath))
    {
        mkdir $DBSettingsPath | Out-Null	
    }

    New-Item "$DBSettingsPath\Database_Settings.txt" -type file -force  |Out-Null
    # Export DB Settings
    [int]$i = 0
    [int]$mypropcount = $db.Properties.Count
    $myproperties = $db.Properties |Sort-Object -Property name
    [string[]]$mypropname = @()
    [string[]]$mypropval  = @()
    for($i=0; $i -le $mypropcount; $i++)
    {
        $mypropname+= $myproperties[$i].name
        $mypropval+=  $myproperties[$i].Value
        $mypropname[$i]+": "+$mypropval[$i] | out-file "$DBSettingsPath\Database_Settings.txt" -Encoding ascii -Append
    }
    

    # Tables
    Write-Host "$fixedDBName - Tables"
    $tbl = $db.Tables  | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $tbl $table_path


    # Stored Procs
    Write-Host "$fixedDBName - Stored Procs"
    $storedProcs = $db.StoredProcedures | Where-object  {-not $_.IsSystemObject  }
    CopyObjectsToFiles $storedProcs $storedProcs_path


    # Views
    Write-Host "$fixedDBName - Views"
    $views = $db.Views | Where-object { -not $_.IsSystemObject   } 
    CopyObjectsToFiles $views $views_path


    # UDFs
    Write-Host "$fixedDBName - UDFs"
    $udfs = $db.UserDefinedFunctions | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $udfs $udfs_path


    # Table Types
    Write-Host "$fixedDBName - Table Types"
    $udtts = $db.UserDefinedTableTypes  
    CopyObjectsToFiles $udtts $udtts_path


    # FullTextCats
    Write-Host "$fixedDBName - FullTextCatalogs"
    $catalog = $db.FullTextCatalogs
    CopyObjectsToFiles $catalog $textCatalog_path


    # DB Triggers
    Write-Host "$fixedDBName - Database Triggers"
    $DBTriggers	= $db.Triggers
    CopyObjectsToFiles $DBTriggers $DBTriggers_path


    # Table Triggers
    Write-Host "$fixedDBName - Table Triggers"
    $TableTriggers = $db.Tables.Triggers
    CopyObjectsToFiles $TableTriggers $TableTriggers_path


    # Schemas
    Write-Host "$fixedDBName - Schemas"
    $Schemas = $db.Schemas | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $Schemas $Schemas_path


    # Sequences
    Write-Host "$fixedDBName - Sequences"
    $Sequences = $db.Sequences
    CopyObjectsToFiles $Sequences $Sequences_path


    # Synonyms
    Write-Host "$fixedDBName - Synonyms"
    $Synonyms = $db.Synonyms
    CopyObjectsToFiles $Synonyms $Synonyms_path


    # Release Memory - Test Set to $null vs Remove-Variable
    
    $tbl = $null
    $storedProcs = $null
    $views = $null
    $udfs = $null
    $udtts = $null
    $catalog = $null
    $DBTriggers = $null
    $TableTriggers = $null
    $Schemas = $null
    $Sequences = $null
    $Synonyms = $null
    


    <#    
    Remove-Variable $tbl
    Remove-Variable $storedProcs
    Remove-Variable $views
    Remove-Variable $udfs
    Remove-Variable $udtts
    Remove-Variable $catalog
    Remove-Variable $DBTriggers
    Remove-Variable $TableTriggers
    Remove-Variable $Schemas
    Remove-Variable $Sequences
    Remove-Variable $Synonyms 
    #>
    

    # List Filegroups, Files and Path
    Write-Host "$fixedDBName - FileGroups"

    # Create output folder
    $myoutputfile = $Filegroups_path+"Filegroups.txt"
    if(!(test-path -path $Filegroups_path))
    {
        mkdir $Filegroups_path | Out-Null	
    }

    # Create Output File
    out-file -filepath $myoutputfile -encoding ascii -Force
    Add-Content -path $myoutputfile -value "FileGroupName:          DatabaseFileName:           FilePath:"

    # Prep SQL
    $mySQLquery = "USE $db; SELECT `
    cast(sysFG.name as char(24)) AS FileGroupName,
    cast(dbfile.name as char(28)) AS DatabaseFileName,
    dbfile.physical_name AS DatabaseFilePath
    FROM
    sys.database_files AS dbfile
    INNER JOIN
    sys.filegroups AS sysFG
    ON
    dbfile.data_space_id = sysFG.data_space_id
    order by dbfile.file_id
    "

    #Run SQL
    if ($serverauth -eq "win")
    {
        $sqlresults2 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
    }
    else
    {
        $sqlresults2 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
    }

    # Script Out
    foreach ($FG in $sqlresults2)
    {
        $myoutputstring = $FG.FileGroupName+$FG.DatabaseFileName+$FG.DatabaseFilePath
        $myoutputstring | out-file -FilePath $myoutputfile -append -encoding ascii -width 500
    }


    # Force GC
    # March 10, 2015 - Still need to call this to kick off a GC pass?
    # Testing with Perfmon
    # Seems only ending the script/session releases memory
    [System.GC]::Collect()

    <#
    Write-Host "Ending Memory: $db"
    [System.gc]::gettotalmemory("forcefullcollection") /1MB

    ps powershell* | Select *memory* | ft -auto `
    @{Name='VirtualMemMB';Expression={($_.VirtualMemorySize64)/1MB}}, `
    @{Name='PrivateMemMB';Expression={($_.PrivateMemorySize64)/1MB}}
    #>


# Process Next Database
}



# finish
set-location $BaseFolder

