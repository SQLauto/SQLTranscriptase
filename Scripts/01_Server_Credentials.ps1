<#
.SYNOPSIS
    Gets the SQL Server Credentials on the target server
	
.DESCRIPTION
   Writes the SQL Server Credentials out to the "01 - Server Credentials" folder
   One file per Credential
   Credentials are used for PKI, TDE, Replication, Azure Connections, Remote Server connections for Agent Proxies or Database Synonyms   
   
.EXAMPLE
    01_Server_Credentials.ps1 localhost
	
.EXAMPLE
    01_Server_Credentials.ps1 server01 sa password

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

Write-Host  -f Yellow -b Black "01 - Server Credentials"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Credentials.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-host "Server $SQLInstance"

# fix target servername if given a SQL named instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

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


# Load SQL SMO Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

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




# Dump Server Credentials
Write-Host "$SQLInstance - Credentials"
$Credentials_path  = "$BaseFolder\$SQLInstance\01 - Server Credentials\"
if(!(test-path -path $Credentials_path))
{
    mkdir $Credentials_path | Out-Null	
}

$mySQLquery = "USE master; SELECT `
credential_id, name, credential_identity, create_date, modify_date, target_type, target_id
FROM
sys.credentials
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

# Output to file
foreach ($Cred in $sqlresults)
{   $myFixedCredName = $Cred.name.replace('\','_')
	$myFixedCredName = $myFixedCredName.replace('/', '-')
	$myFixedCredName = $myFixedCredName.replace('[','(')
	$myFixedCredName = $myFixedCredName.replace(']',')')
	$myFixedCredName = $myFixedCredName.replace('&', '-')
	$myFixedCredName = $myFixedCredName.replace(':', '-')
    $myoutputfile = $Credentials_path+$myFixedCredName+".sql"
    $myoutputstring = "CREATE CREDENTIAL "+$Cred.Name+" WITH IDENTITY='"+$Cred.credential_identity+"'"
    $myoutputstring | out-file -FilePath $myoutputfile -append -encoding ascii -width 500
}


# finish
set-location $BaseFolder



