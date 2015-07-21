<#
.SYNOPSIS
    Dumps the Extended Events Sessions to .SQL files

.DESCRIPTION
    Dumps the Extended Events Sessions to .SQL files
	
.EXAMPLE
    15_Extended_Events.ps1 localhost
	
.EXAMPLE
    15_Extended_Events.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
    .sql files
	
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
Write-Host -f Yellow -b Black "15 - Extended Events"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./15_Extended_Events.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"


# Server connection check
[string]$serverauth = "win"
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
 	Try
    {
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
        set-location $BaseFolder
	    exit
	}
}

if (!($myver -like "11.0*") -and !($myver -like "12.0*"))
{
    Write-Output "Supports Extended Events only on SQL Server 2012 or higher"
    exit
}

#  Any to DO?
$sqlES = 
" 
select [event_session_id],[name] from sys.server_event_sessions
"

# Connect Correctly
[string]$serverauth = "win"
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "Using Sql Auth"	

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$EvtSessions = Invoke-SqlCmd -query $sqlES -Server $SQLInstance –Username $myuser –Password $mypass 

    if ($EvtSessions -eq $null)
    {
        Write-Output "No Extended Event Sessions found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\15 - No Extended Event Sessions found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    $serverauth="sql"
}
else
{
	Write-Output "Using Windows Auth"	

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$EvtSessions = Invoke-SqlCmd -query $sqlES  -Server $SQLInstance  
    if ($EvtSessions -eq $null)
    {
        Write-Output "No Extended Event Sessions found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\15 - No Extended Event Sessions found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 
}

# Create Output folder
set-location $BaseFolder
$fullfolderPath = "$BaseFolder\$sqlinstance\15 - Extended Events"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# *Must Credit*
# Jonathan Kehayias for the following code, including the correct DLLs, order of things and the need to use the ConnectionStringBuilder
# https://www.sqlskills.com/blogs/jonathan/
# http://sqlperformance.com/author/jonathansqlskills-com
# 
# Load SQL SMO Assemblies
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.XEvent") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.XEventEnum") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Sdk.Sfc") | out-null

$conBuild = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
$conBuild.psbase.DataSource = $SQLInstance
$conBuild.psbase.InitialCatalog = "master";

if ($serverauth -eq "win")
{
    $conBuild.psbase.IntegratedSecurity = $true;
}
else
{
    $conbuild.psbase.IntegratedSecurity = $false
    $conbuild.psbase.UserID = $myuser
    $conbuild.psbase.Password = $mypass
}

# Connect to server
$sqlconn = New-Object System.Data.SqlClient.SqlConnection $conBuild.ConnectionString.ToString();

# Grab the SqlStoreConnection
$Server = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection $sqlconn

# XE Sessions are stored in the XEStore Object
$XEStore = New-Object Microsoft.SqlServer.Management.XEvent.XEStore $Server

foreach($XESession in $XEStore.Sessions)
{    
    Write-Host "Scripting out ["$XESession.Name"]"

    $output_path = $fullfolderPath+"\"+$XESession.name+".sql"    
    
    $script = $XESession.ScriptCreate().GetScript()    
    $script | out-file  $output_path -Force -encoding ascii
}

set-location $BaseFolder
