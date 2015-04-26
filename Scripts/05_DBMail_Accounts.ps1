<#
.SYNOPSIS
    Gets the SQL Agent Database Mail Accounts
	
.DESCRIPTION
    Writes the SQL Agent Database Mail Accounts out to DBMail_Accounts.sql
	
.EXAMPLE
    05_DBMail_Accounts.ps1 localhost
	
.EXAMPLE
    05_DBMail_Accounts.ps1 server01 sa password
	
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
Write-Host  -f Yellow -b Black "05 - DBMail Accounts"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./05_DBMail_Accounts.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-host "Server $SQLInstance"

Import-Module “sqlps” -DisableNameChecking -erroraction SilentlyContinue

$sql = 
"
USE msdb
set nocount on;

create table #tbl (
id int not null,
[name] sysname not null,
[description] nvarchar(254) null,
email_address nvarchar(100) null,
display_name nvarchar(100) null,
replyto_address nvarchar(100) null,
servertype NVARCHAR(100) null,
servername NVARCHAR(100) NULL,
port NVARCHAR(100) NULL,
username NVARCHAR(100) NULL,
use_default_credentials NVARCHAR(100) NULL,
enable_ssl NVARCHAR(100) NULL
)

insert into #tbl
  EXEC msdb.dbo.sysmail_help_account_sp;

--SELECT * FROM #tbl
--DROP table #tbl;

DECLARE @mystring VARCHAR(max)

select 'USE msdb' + char(13) + char(10) + 'GO' +CHAR(13)+CHAR(10)+
'exec sysmail_add_account_sp '+
'@account_name = ' + quotename(#tbl.[name],CHAR(39)) + ', '+
'@description = '+ COALESCE(QUOTENAME(#tbl.[description],CHAR(39)),'null') + ', '+
'@email_address = ' + COALESCE(quotename(#tbl.email_address, char(39)),'NULL') + ', ' +
'@display_name = ' + QUOTENAME(#tbl.display_name,CHAR(39)) + ', ' + 
'@replyto_address = ' + QUOTENAME(#tbl.replyto_address,CHAR(39)) + ', ' +
'@mailserver_type = ' + QUOTENAME(#tbl.servertype,CHAR(39)) + ', '+
'@mailserver_name = ' + QUOTENAME(#tbl.servername,CHAR(39)) + ', '+
'@port = ' + QUOTENAME(#tbl.port,CHAR(39)) + ', '+
'@username = ' + coalesce(QUOTENAME(#tbl.username,CHAR(39)),'NULL')+ ', '+
'@use_default_credentials = ' + QUOTENAME(#tbl.use_default_credentials,CHAR(39)) +  ', '+
'@enable_ssl = ' + QUOTENAME(#tbl.enable_ssl,CHAR(39)) + CHAR(13) + char(10) + 'go' 
from #tbl order by id;

drop table #tbl;

"


$fullfolderPath = "$BaseFolder\$sqlinstance\05 - DBMail Accounts"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}
	
# Test for Username/Password needed to connect - else assume WinAuth passthrough
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-host "Using SQL Auth"
    
    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance –Username $myuser –Password $mypass 	
    if ($results -eq $null )
    {
        write-host "No Database Mail Accounts found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\05 - No Database Mail Accounts found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    New-Item "$fullfolderPath\DBMail_Accounts.sql" -type file -force  |Out-Null
    Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\DBMail_Accounts.sql" -Encoding ascii -Append
		Add-Content -Value "`r`n" -Path "$fullfolderPath\DBMail_Accounts.sql" -Encoding Ascii
    }
}
else
{
	Write-host "Using Windows Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance  	
    if ($results -eq $null )
    {
        write-host "No Database Mail Accounts found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\05 - No Database Mail Accounts found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 


	New-Item "$fullfolderPath\DBMail_Accounts.sql" -type file -force  |Out-Null
	Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\DBMail_Accounts.sql" -Encoding ascii -Append
		Add-Content -Value "`r`n" -Path "$fullfolderPath\DBMail_Accounts.sql" -Encoding Ascii
    }
}

set-location $BaseFolder



