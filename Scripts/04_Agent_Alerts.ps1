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
    ServerName\Instance, [SQLUser], [SQLPassword]

.Outputs
	Agent Alerts in .SQL format
	
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

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-Host -f yellow "Usage: ./04_Agent_Alerts.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


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


 # Get the Alerts Themselves
$sql1 = 
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


# Get the Notifications for Each Alert (typically Email to an Operator)
$sql2 = 
"
select 
	'EXEC msdb.dbo.sp_add_notification '+char(13)+char(10)+
	' @alert_name =N'+CHAR(39)+A.[name]+CHAR(39)+CHAR(13)+CHAR(10)+
	' ,@operator_name = N'+CHAR(39)+O.[name]+CHAR(39)+CHAR(13)+CHAR(10)+	
	' ,@notification_method= 1'
from 
	[msdb].[dbo].[sysalerts] a
inner join 
	[msdb].[dbo].[sysnotifications] n
ON
	a.id = n.alert_id
inner join
	[msdb].[dbo].[sysoperators] o
on 
	n.operator_id = o.id
"

# Create Output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Alerts"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}
	
# Turn off default error handler
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'


# Get Alerts
# Connect Correctly
if ($serverauth -eq "win")
{
    Write-Output "Using Windows Auth"
    $results1 = Invoke-SqlCmd -query $sql1  -Server $SQLInstance
}
else
{
    Write-Output "Using SQL Auth"
    $results1 = Invoke-SqlCmd -query $sql1  -Server $SQLInstance –Username $myuser –Password $mypass
}

if ($results1 -eq $null)
{
    Write-Output "No Agent Alerts Found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alerts Found.txt"
    Set-Location $BaseFolder
    exit
}

# Export Alerts
New-Item "$fullfolderPath\Agent_Alerts.sql" -type file -force  |Out-Null
Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alerts.sql" -Encoding Ascii
Foreach ($row in $results1)
{
    $row.column1 | out-file "$fullfolderPath\Agent_Alerts.sql" -Encoding ascii -Append
}

    Write-Output ("{0} Alerts Exported" -f $results1.count)


# Get Alert Notifications
# Connect Correctly
if ($serverauth -eq "win")
{
    Write-Output "Using Windows Auth"
    $results2 = Invoke-SqlCmd -query $sql2  -Server $SQLInstance
}
else
{
    Write-Output "Using SQL Auth"
    $results2 = Invoke-SqlCmd -query $sql2  -Server $SQLInstance –Username $myuser –Password $mypass
}

$results2 = Invoke-SqlCmd -query $sql2  -Server $SQLInstance –Username $myuser –Password $mypass 

if ($results2 -eq $null)
{
    Write-Output "No Agent Alert Notifications Found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alert Notifications Found.txt"
    Set-Location $BaseFolder
    exit
}

# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference 

# Export Alert Notifications
New-Item "$fullfolderPath\Agent_Alert_Notifications.sql" -type file -force  |Out-Null
Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alert_Notifications.sql" -Encoding Ascii
Foreach ($row in $results2)
{
    $row.column1 | out-file "$fullfolderPath\Agent_Alert_Notifications.sql" -Encoding ascii -Append
}

Write-Output ("Exported: {0} Alert Notifications" -f $results2.count)


set-location $BaseFolder