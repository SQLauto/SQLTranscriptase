<#
.SYNOPSIS
    Gets the SQL Agent Database Mail Profiles
	
.DESCRIPTION
    Writes the SQL Agent Database Mail Profiles out to DBMail_Profiles.sql
	
.EXAMPLE
    05_DBMail_Profiles.ps1 localhost
	
.EXAMPLE
    05_DBMail_Profiles.ps1 server01 sa password
	
.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
    DBMail Profiles to DBMAIL_Profiles.sql
	
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
Write-Host  -f Yellow -b Black "05 - DBMail Profiles"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./05_DBMail_Profiles.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
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

Import-Module “sqlps” -DisableNameChecking -erroraction SilentlyContinue

# Load SQL SMO Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

#Set the server to script from 
$Server= $SQLInstance;

#Get a server object which corresponds to the default instance 
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

# Error trapping off for webserviceproxy calls
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

$DBMailProfiles = $srv.Mail.Script();

# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 

set-location $BaseFolder

# Export
if ($DBMailProfiles -ne $null)
{
    
    # Create output folder
    $fullfolderPath = "$BaseFolder\$sqlinstance\05 - DBMail Profiles"
    if(!(test-path -path $fullfolderPath))
    {
    	mkdir $fullfolderPath | Out-Null
    }

    $DBMailProfiles | out-file "$fullfolderPath\DBMail_Profiles.sql" -Encoding ascii -Append
	
}
else
{
    Write-Output "No Database Mail Profiles found on $SQLInstance"
    echo null > "$BaseFolder\$SQLInstance\05 - No Database Mail Profiles found.txt"
    Set-Location $BaseFolder    
}

# Return to Base
set-location $BaseFolder
