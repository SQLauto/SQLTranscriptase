<#
.SYNOPSIS
    AMO Testing

.DESCRIPTION
    AMO Testing
	
.EXAMPLE
    30_SSAS_Objects.ps1 localhost
	
.EXAMPLE
    30_SSAS_Objects.ps1 server01 sa password

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
Write-Host -f Yellow -b Black "30 - SSAS Objects"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Host "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./30_SSAS_Objects.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-host "Server $SQLInstance"


# SSAS MD Server connection check
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

if (!($myver -like "11.0*") -and !($myver -like "12.0*"))
{
    Write-Host "Supports Extended Events only on SQL Server 2012 or higher"
    exit
}

# Load Asssemblies
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | out-null

# Create a server object :
$serverAS = New-Object Microsoft.AnalysisServices.Server

# Connect to your Analysis Services server 
$serverAS.connect($SQLInstance)

# Select the information
#$serverAS.serverproperties | select Name, Value

# Iterate over each DB
if ($serverAS.Databases.Count -gt 0)
{
    foreach($SSASDB in $serverAS.Databases)
    {   
        # DB Properties
        $serverAS.databases | select Name, EstimatedSize, StorageMode, LastProcessed | Format-Table -AutoSize

        # Dimensions
        $serverAS.dimensions | select name, isparentchild, lastprocessed, storagemode

        if ($SSASDB.Cubes.count -gt 0)
        {
            foreach($Cube in $SSASDB.Cubes)
            {
                $Cube | select Name,LastProcessed
                # $Cube.Process("ProcessFull")
            }
            
        }
    }
}

set-location $BaseFolder
