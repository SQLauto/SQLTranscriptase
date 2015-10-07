<#
.SYNOPSIS
    Gets the SQL Agent Proxies
	
.DESCRIPTION
   Writes the SQL Agent Proxies out to the "04 - Agent Proxies" folder
   Proxies are typically used when you need to use alternate credentials in a job step
   For instance when calling an SSIS package that needs to connect with SQL Auth credentials for a DMZ/Non-Domain Server
   
.EXAMPLE
    04_Agent_Proxies.ps1 localhost
	
.EXAMPLE
    04_Agent_Proxies.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

.NOTES
	
.LINK

	
#>

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

#  Script Name
Write-Host  -f Yellow -b Black "04 - Agent Proxies"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Proxies.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    exit
}
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


# Working
Write-Output "Server $SQLInstance"

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
			
			$myProxyname = $o.Name
			$myProxyname = $myProxyname.Replace('\', '-')
			$myProxyname = $myProxyname.Replace('/', '-')
			$myProxyname = $myProxyname.Replace('&', '-')
			$myProxyname = $myProxyname.Replace(':', '-')
			$myProxyname = $myProxyname.Replace('[', '(')
			$myProxyname = $myProxyname.Replace(']', ')')
			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $myProxyname + ".sql"
			$scripter.EnumScript($o)
		}
	}
}



# Set Local Vars
$server 	= $SQLInstance

if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)
}
else
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $scripter   = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)

}

$scripter.Options.ToFileOnly = $true


# create output folder
$proxy_path = "$BaseFolder\$sqlinstance\04 - Agent Proxies\"
if(!(test-path -path $proxy_path))
{
	mkdir $proxy_path | Out-Null
}

# Export Agent Proxy Object Collection
$pa = $srv.JobServer.ProxyAccounts
CopyObjectsToFiles $pa $proxy_path

Write-Output ("{0} Agent Proxies Exported" -f $pa.count)

set-location $BaseFolder
