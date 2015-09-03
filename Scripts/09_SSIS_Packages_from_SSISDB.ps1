<#
.SYNOPSIS
    Gets the SQL Server Integration Services Catalog objects on the target server
	
.DESCRIPTION
   Writes the SSIS Packages out to the "09 - SSISDB" folder
   
.EXAMPLE
    09_SSIS_Packages_from_SSISDB.ps1 localhost
	
.EXAMPLE
    09_SSIS_Packages_from_SSISDB.ps1 server01 sa password

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
  [string]$SQLInstance,
  [string]$myuser,
  [string]$mypass
)


[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


#  Script Name
Write-Host  -f Yellow -b Black "09 - SSIS Packages from SSISDB"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$SQLInstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./09_SSIS_Packages_from_SSISDB.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"


# See if the SSISDB Catalog Exists first
$Folders = @()
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "Using SQL Auth"
	
	# See if the SSISDB Catalog Exists first
	[bool]$exists = $FALSE

    # we set this to null so that nothing is displayed
	$null = [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
	   
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
    $server.ConnectionContext.LoginSecure = $false 
	$server.ConnectionContext.Login=$myuser
    $server.ConnectionContext.Password=$mypass
    $backupfolder = $server.Settings.BackupDirectory

	# if a UNC path, use it 
    $unc = 0
    if ($backupfolder -like "*\\*")
    {
        $unc = 1
    }

    # Look for the 2012+ SSIS Catalog on this server
    if ( $null -ne $server.Databases["SSISDB"] ) { $exists = $true } else { $exists = $false }
	
	if ($exists -eq $FALSE)
    {
        Write-Output "SSISDB Catalog not found on $SQLInstance"
        # Create output folder
        $fullfolderPath = "$BaseFolder\$sqlinstance\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }	
        Write-Output "SSIS Catalog not found or version NOT 2012+"
        echo null > "$BaseFolder\$SQLInstance\09 - SSISDB Catalog - Not found.txt"
        Set-Location $BaseFolder
        exit
    }
 
	# Get Folders/Projects Tree
	$Folders +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query "SELECT `
	f.name as 'Folder',
	j.name as 'Project'
	FROM [SSISDB].[catalog].[projects] j
	inner join [SSISDB].[catalog].[folders] f
	on j.[folder_id] = f.[folder_id]
	order by f.folder_id,j.project_id
" 
}
else
{
	Write-Output "Using Windows Auth"
	
	# See if the SSISDB Catalog Exists first		
	$exists = $FALSE

    # we set this to null so that nothing is displayed
	$null = [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
	   
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
	$backupfolder = $server.Settings.BackupDirectory

	# if a UNC path, use it 
    $unc = 0
    if ($backupfolder -like "*\\*")
    {
        $unc = 1
    }
   
    # Only if the Catalog is found    
    if ( $null -ne $server.Databases["SSISDB"] ) { $exists = $true } else { $exists = $false }

	if ($exists -eq $FALSE)
    {
        Write-Output "SSISDB Catalog not found on $SQLInstance"
        # Create output folder
        $fullfolderPath = "$BaseFolder\$sqlinstance\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }	
        Write-Output "SSIS Catalog not found or version NOT 2012+"
        echo null > "$BaseFolder\$SQLInstance\09 - SSISDB Catalog - Not found.txt"
        Set-Location $BaseFolder
        exit
    }
 
	# Get Folders/Projects Tree
	$Folders +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query "SELECT `
	f.name as 'Folder',
	j.name as 'Project'
	FROM [SSISDB].[catalog].[projects] j
	inner join [SSISDB].[catalog].[folders] f
	on j.[folder_id] = f.[folder_id]
	order by 1,2
"

}

# Create output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\09 - SSISDB"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}
	
Write-Output "Writing out Folders/Projects/Packages in ISPAC format..."
Foreach ($folder in $Folders)
{
    $foldername = $folder.folder
	$prjname = $folder.project
    $SSISFolderPath = "$BaseFolder\$sqlinstance\09 - SSISDB\$foldername"
    if(!(test-path -path $SSISFolderPath))
    {
        mkdir $SSISFolderPath | Out-Null
    }
	
    # Script out with BCP and a format file
    bcp "exec [ssisdb].[catalog].[get_project] '$foldername','$prjname'" queryout "$SSISFolderPath\$prjname.ispac" -S $SQLInstance -T -f "$BaseFolder\ssisdb.fmt" | Out-Null
}

# Export SSISDB Catalog Master Key
Set-Location $fullfolderPath
$destfrag = "\"+$sqlinstance+"_SSISDB_Master_Key.txt"
$destfile = $backupfolder+$destfrag

Write-Output "Writing out Key File..."
$myquery = "use SSISDB; "
$myquery += " backup master key to file = '$destfile'"
$myquery += " encryption by password = 'Brf7d5XtWc5gJiTBU8uW'"

if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
    set-location $fullfolderPath
    $keyresult = Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $myquery -Username $myuser -Password $mypass 
}
else
{
    set-location $fullfolderPath
    $keyresult = Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $myquery
}

# Copy Key File down from admin share
Write-Output "Copying down key file..."

if ($unc -eq 1)
{
    $sourcefolder = $backupfolder    
    $src = $sourcefolder+$destfrag
    set-location $fullfolderPath
    copy-item $src $fullfolderPath
    # Leave no trace on server
    remove-item $src -ErrorAction SilentlyContinue 
}
else
{
    if ($sqlinstance -eq "localhost") # change drive letter into unc share if localhost using UNC
    {
        $sourcefolder = $backupfolder
        $src = $sourcefolder+$destfrag
    }
    else
    {
        $sourcefolder = $backupfolder.Replace(":","$") # server is remote, but itself uses drive letter, which we need as unc from our point of view
        $src = "\\$sqlinstance\$sourcefolder"+$destfrag
    }
    set-location $BaseFolder
    copy-item $src "$fullfolderPath"
    # Leave no trace on server
    remove-item $src -ErrorAction SilentlyContinue
}


# Create stub Restore Command
set-location $fullfolderPath
$myrestorecmd = "Restore master key from file = 'SSISDB_Master_Key.txt' `
       Decryption by password = 'Brf7d5XtWc5gJiTBU8uW!' -- from above
       Encryption by password = 'SomeNewSecurePassword$!' -- New Password
       Force"

Write-Output "Writing out Master Key Restore Command..."
$myrestorecmd | out-file $fullfolderPath\Master_Key_Restore_cmd.sql -Encoding ascii

Write-Output ("{0} Packages Exported" -f $Folders.count)

set-location $BaseFolder
