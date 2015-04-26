<#
.SYNOPSIS
    Gets the SQL Agent Schedules
	
.DESCRIPTION
    Writes the SQL Sgent Job Schedules out to the "04 - Agent Schedules" folder, "Agent_Schedules.sql" file
	
.EXAMPLE
    04_Agent_Schedules.ps1 localhost
	
.EXAMPLE
    04_Agent_Schedules.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOT/ES
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


#  Script Name
Write-Host  -f Yellow -b Black "04 - Agent Schedules"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Schedules.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    exit
}

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Working
Write-host "Server $SQLInstance"

Import-Module “sqlps” -DisableNameChecking -erroraction SilentlyContinue

$sql = 
"

SELECT     
	'Exec msdb.dbo.sp_add_schedule '+
	' @schedule_name='+char(39)+[name]+char(39)+
	' ,@enabled=' + CASE [enabled] WHEN 1 THEN '1' WHEN 0 THEN '0' END+
	' ,@freq_type=' + convert(varchar(4),[freq_type])+
    ' ,@freq_interval=' +convert(varchar(3),[freq_interval])+
	' ,@freq_subday_type='+convert(varchar(3),[freq_subday_type])+
	' ,@freq_subday_interval='+convert(varchar(3),[freq_subday_interval])+
	' ,@freq_relative_interval='+convert(varchar(3),[freq_relative_interval])+
    ' ,@freq_recurrence_Factor='+convert(varchar(3),[freq_recurrence_factor])+
	' ,@active_start_date='+convert(varchar(8),[active_start_date])+
	' ,@active_end_date='+convert(varchar(8),[active_end_date])+
	' ,@active_start_time='+convert(varchar(8),[active_start_time])+
	' ,@active_end_time='+convert(varchar(8),[active_end_time])
FROM [msdb].[dbo].[sysschedules]
"

$fullfolderPath = "$BaseFolder\$SQLInstance\04 - Agent Schedules"
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
	
    $outdata = Invoke-SqlCmd -query $sql  -Server $SQLInstance –Username $myuser –Password $mypass 
    if ($outdata -eq $null )
    {
        write-host "No Agent Schedules Found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Schedules Found.txt"
        Set-Location $BaseFolder
        exit
    }
    
    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 
    
    New-Item "$fullfolderPath\Agent_Schedules.sql" -type file -force |Out-Null
    $Outdata| Select column1 -ExpandProperty column1 | out-file "$fullfolderPath\Agent_Schedules.sql" -Encoding ascii -Append -Width 10000
    
}
else
{
	Write-host "Using Windows Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    $Outdata = Invoke-SqlCmd -query $sql -Server $SQLInstance
    if ($outdata -eq $null )
    {
        write-host "No Agent Schedules Found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Schedules Found.txt"
        Set-Location $BaseFolder
        exit
    }
    
    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 
    
    New-Item "$fullfolderPath\Agent_Schedules.sql" -type file -force |Out-Null
    $Outdata| Select column1 -ExpandProperty column1 | out-file "$fullfolderPath\Agent_Schedules.sql" -Encoding ascii -Append -Width 10000
    
}

set-location $BaseFolder


