<#
.SYNOPSIS
    Gets the SQL Agent Operators
	
.DESCRIPTION
    Writes the SQL Agent Operators out to Agent_Operators.sql
	
.EXAMPLE
    04_Agent_Operators.ps1 localhost
	
.EXAMPLE
    04_Agent_Operators.ps1 server01 sa password
	
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
Write-Host  -f Yellow -b Black "04 - Agent Operators"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Operators.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
        Set-Location $BaseFolder
	    exit
	}
}

$sql = 
"
USE msdb
set nocount on;

create table #tbl (
id int not null,
name sysname not null,
enabled tinyint not null,
email_address nvarchar(100) null,
last_email_date int not null,
last_email_time int not null,
pager_address nvarchar(100) null,
last_pager_date int not null,
last_pager_time int not null,
weekday_pager_start_time int not null,
weekday_pager_end_time int not null,
Saturday_pager_start_time int not null,
Saturday_pager_end_time int not null,
Sunday_pager_start_time int not null,
Sunday_pager_end_time int not null,
pager_days tinyint not null,
netsend_address nvarchar(100) null,
last_netsend_date int not null,
last_netsend_time int not null,
category_name sysname null);

insert into #tbl
  EXEC sp_help_operator; 


select 'USE msdb' + char(13) + char(10) + 'GO' +CHAR(13)+CHAR(10)+ 
'exec sp_add_operator ' + 
'@name = ' + quotename(name, char(39)) + ', ' + 
'@enabled = ' + cast (enabled as char(1)) + ', ' + 
'@email_address = ' + quotename(email_address, char(39)) + ', ' + 
case 
when pager_address is not null then '@pager_address = ' + quotename(pager_address, char(39)) + ', '
else ''
end + 
'@weekday_pager_start_time = ' + ltrim(str(weekday_pager_start_time)) + ', ' + 
'@weekday_pager_end_time = ' + ltrim(str(weekday_pager_end_time)) + ', ' +
'@Saturday_pager_start_time = ' + ltrim(str(Saturday_pager_start_time)) + ', ' +
'@Saturday_pager_end_time = ' + ltrim(str(Saturday_pager_end_time)) + ', ' +
'@Sunday_pager_start_time = ' + ltrim(str(Sunday_pager_start_time)) + ', ' +
'@Sunday_pager_end_time = ' + ltrim(str(Sunday_pager_end_time)) + ', ' +
'@pager_days = ' + cast(pager_days as varchar(3)) +  
case
when netsend_address is not null then ', @netsend_address = ' + quotename(netsend_address, char(39)) 
else ''
end + 
case 
when category_name != '[Uncategorized]' then ', @category_name = ' + category_name  
else '' 
end +
char(13) + char(10) + 'go' 
from #tbl order by id;

drop table #tbl;

"


$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Operators"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}
	
# Test for Username/Password needed to connect - else assume WinAuth passthrough
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "Using SQL Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance –Username $myuser –Password $mypass 	
    if ($results -eq $null )
    {
        Write-Output "No Agent Operators Found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Operators Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

	New-Item "$fullfolderPath\Agent_Operators.sql" -type file -force  |Out-Null
    Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\Agent_Operators.sql" -Encoding ascii -Append
		Add-Content -Value "`r`n" -Path "$fullfolderPath\Agent_Operators.sql" -Encoding Ascii
    }
}
else
{
	Write-Output "Using Windows Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance  	
    if ($results -eq $null )
    {
        Write-Output "No Agent Operators Found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Operators Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

	New-Item "$fullfolderPath\Agent_Operators.sql" -type file -force  |Out-Null
    Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\Agent_Operators.sql" -Encoding ascii -Append
		Add-Content -Value "`r`n" -Path "$fullfolderPath\Agent_Operators.sql" -Encoding Ascii
    }
}

# Return to Base
set-location $BaseFolder
