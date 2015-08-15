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
    ServerName\Instance, [SQLUser], [SQLPassword]

.Outputs

	
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

# Save Starting Folder
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Im working Here...
Write-Host  -f Yellow -b Black "20 - DataBase Objects (Triggers, Tables, Views, Procs, UDFs, FullTextCats, TableTypes, Schemas)"

# Assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Parameter Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./20_DataBase_Objects.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
        Write-Output $myver
    }
	}
	catch
    {
	    Write-Host -f red "$SQLInstance appears offline - Try SQL Auth?" 
        Set-Location $BaseFolder
	    exit
	}

}

# This is the SMO Scripter Function used below for each object
function CopyObjectsToFiles($objects, $outDir) {

    # Create Object Output Folder	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | out-null
	}
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
            # Add any schema to the output filename 
			if ($o.Schema -ne $null -and $o.Schema -ne "") {
				$schemaPrefix = $o.Schema + "."
			}
		
            # Fixup object backslashes with underscores
			$fixedOName = $o.name.replace('\','_')			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $fixedOName + ".sql"
            try
            {
			    $scripter.EnumScript($o)
            }
            catch
            {
                $msg = "Cannot script this element:"+$o
                Write-output $msg
            }
		}
	}
}



# Load SQL SMO Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

# Set Local Vars
$server = $SQLInstance

# Connect using proper auth
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

# Prep top-level Server objects
$db 	= New-Object ("Microsoft.SqlServer.Management.SMO.Database")
$tbl	= New-Object ("Microsoft.SqlServer.Management.SMO.Table")

# Set scripter options to ensure only schema is scripted-out
$scripter.Options.ScriptSchema 	= $true;

# Really want me, flip this switch
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
# Use with CAUTION
$scripter.Options.WithDependencies		= $false

$scripter.Options.XmlIndexes            = $true

# Data 
$scripter.Options.ScriptData            = $false

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}

    # Skip Offline Databases (SMO still enumerates them, but you cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal') {continue}

    # Prep Database for output
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\20 - DataBase Objects\$fixedDBname"

    # Set output paths for the Scripter Function above
    $DB_Path            = "$output_path\"
    $Table_path 		= "$output_path\Tables\"
    $TableTriggers_path	= "$output_path\TableTriggers\"
    $Views_path 		= "$output_path\Views\"
    $StoredProcs_path 	= "$output_path\StoredProcedures\"
    $UDFs_path 			= "$output_path\UserDefinedFunctions\"
    $TextCatalog_path 	= "$output_path\FullTextCatalogs\"
    $UDTTs_path 		= "$output_path\UserDefinedTableTypes\"
    $DBTriggers_path 	= "$output_path\DBTriggers\"
    $Schemas_path       = "$output_path\Schemas\"
    $Filegroups_path    = "$output_path\Filegroups\"
    $Sequences_path     = "$output_path\Sequences\"
    $Synonyms_path      = "$output_path\Synonyms\"


    # Get Objects via SMO into PS Objects
    # This is where .NET gobbles memory, so go get a coffee
    
    
    # Export Database Properties    
    $DBSettingsPath = $output_path+"\Settings"
    if(!(test-path -path $DBSettingsPath))
    {
        mkdir $DBSettingsPath | Out-Null	
    }


    # Script Out the Main Database itself with its Files and FileGroups (with disk paths)
    Write-Output "$fixedDBName - Database"
    $MainDB = $db  | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $MainDB $DB_Path


    # Create some CSS for help in column formatting
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
    $myCSS | out-file "$DBSettingsPath\HTMLReport.css" -Encoding ascii
   
    # Export DB Settings
    Write-Output "$fixedDBName - Settings"
    $mySettings = $db.Properties
    $mySettings | sort-object Name | select Name, Value | ConvertTo-Html  -CSSUri "$DBSettingsPath\HTMLReport.css"| Set-Content "$DBSettingsPath\HtmlReport.html"
    
    # Tables
    Write-Output "$fixedDBName - Tables"
    $tbl = $db.Tables  | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $tbl $table_path


    # Stored Procs
    Write-Output "$fixedDBName - Stored Procs"
    $storedProcs = $db.StoredProcedures | Where-object  {-not $_.IsSystemObject  }
    CopyObjectsToFiles $storedProcs $storedProcs_path


    # Views
    Write-Output "$fixedDBName - Views"
    $views = $db.Views | Where-object { -not $_.IsSystemObject   } 
    CopyObjectsToFiles $views $views_path


    # UDFs
    Write-Output "$fixedDBName - UDFs"
    $udfs = $db.UserDefinedFunctions | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $udfs $udfs_path


    # Table Types
    Write-Output "$fixedDBName - Table Types"
    $udtts = $db.UserDefinedTableTypes  
    CopyObjectsToFiles $udtts $udtts_path


    # FullTextCats
    Write-Output "$fixedDBName - FullTextCatalogs"
    $catalog = $db.FullTextCatalogs
    CopyObjectsToFiles $catalog $textCatalog_path


    # DB Triggers
    Write-Output "$fixedDBName - Database Triggers"
    $DBTriggers	= $db.Triggers
    CopyObjectsToFiles $DBTriggers $DBTriggers_path


    # Table Triggers
    Write-Output "$fixedDBName - Table Triggers"
    $TableTriggers = $db.Tables.Triggers
    CopyObjectsToFiles $TableTriggers $TableTriggers_path


    # Schemas
    Write-Output "$fixedDBName - Schemas"
    $Schemas = $db.Schemas | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $Schemas $Schemas_path


    # Sequences
    Write-Output "$fixedDBName - Sequences"
    $Sequences = $db.Sequences
    CopyObjectsToFiles $Sequences $Sequences_path


    # Synonyms
    Write-Output "$fixedDBName - Synonyms"
    $Synonyms = $db.Synonyms
    CopyObjectsToFiles $Synonyms $Synonyms_path


    # Release Memory by setting the vars to $null
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


    
	<# Release Memory by doing Remove-Variable    
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
    

    # Force GC
    [System.GC]::Collect()

 
    # Process Next Database
}

# Return to Base
set-location $BaseFolder

