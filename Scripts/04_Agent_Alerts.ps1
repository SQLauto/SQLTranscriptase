<#
.SYNOPSIS
    Gets the SQL Agent Alerts
	
.DESCRIPTION
   Writes the SQL Agent Alerts out to the "04 - Agent Alerts" folder, Agent_Alerts.sql file
   One file for all Alerts
   
.EXAMPLE
    04_Agent_Alerts.ps1 localhost
	
.EXAMPLE
    04_Agent_Alerts.ps1 server01 sa password

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

Import-Module “sqlps” -DisableNameChecking -erroraction SilentlyContinue

#  Script Name
Write-Host  -f Yellow -b Black "04 - Agent Alerts"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Alerts.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
       Set-Location $BaseFolder
    exit
}


# Working
Write-host "Server $SQLInstance"



$sql = 
"
SELECT 'EXEC msdb.dbo.sp_add_alert '+char(13)+char(10)+
' @name=N'+CHAR(39)+tsha.NAME+CHAR(39)+char(13)+char(10)+
',@message_id='+CONVERT(VARCHAR(6),tsha.message_id)+char(13)+char(10)+
',@severity='+CONVERT(VARCHAR(10),tsha.severity)+char(13)+char(10)+
',@enabled='+CONVERT(VARCHAR(10),tsha.[enabled])+char(13)+char(10)+
',@delay_between_responses='+convert(varchar(10),tsha.delay_between_responses)+char(13)+char(10)+
',@include_event_description_in='+CONVERT(VARCHAR(5),tsha.include_event_description)+char(13)+char(10)+
',@job_id=N'+char(39)+'00000000-0000-0000-0000-000000000000'+char(39)+char(13)+char(10)
FROM msdb.dbo.sysalerts tsha

"

$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Alerts"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}
	
# Test for Username/Password needed to connect - else assume WinAuth pass-through
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-host "Using SQL Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql  -Server $SQLInstance –Username $myuser –Password $mypass 

    if ($results -eq $null)
    {
        write-host "No Agent Alerts Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alerts Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    New-Item "$fullfolderPath\Agent_Alerts.sql" -type file -force  |Out-Null
    Add-Content -Value "--Please Set your own DBMail Operator on these Alerts when finished`r`n" -Path "$fullfolderPath\Agent_Alerts.sql" -Encoding Ascii
    Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alerts.sql" -Encoding Ascii
    Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\Agent_Alerts.sql" -Encoding ascii -Append
    }
}
else
{
	Write-host "Using Windows Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql  -Server $SQLInstance  
    if ($results -eq $null)
    {
        write-host "No Agent Alerts Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alerts Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

	New-Item "$fullfolderPath\Agent_Alerts.sql" -type file -force  |Out-Null
    Add-Content -Value "--Please Set your own DBMail Operator on these Alerts when finished`r`n" -Path "$fullfolderPath\Agent_Alerts.sql" -Encoding Ascii
    Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alerts.sql" -Encoding Ascii
    Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\Agent_Alerts.sql" -Encoding ascii -Append
    }
}

set-location $BaseFolder


