<#
.SYNOPSIS
    Gets the Server Triggers on the target server
	
.DESCRIPTION
   Writes the Server Triggers out to the "01 - Server Triggers" folder
   One file for all Triggers   
   
.EXAMPLE
    01_Server_Triggers.ps1 localhost
	
.EXAMPLE
    01_Server_Triggers.ps1 server01 sa password

.Inputs
    ServerName\Instance, [SQLUser], [SQLPassword]

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
Write-Host  -f Yellow -b Black "01 - Server Triggers"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Triggers.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-location $BaseFolder
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
SELECT
ssmod.definition AS [Definition],
'ENABLE TRIGGER ' + name +' ON ALL SERVER' as enablecmd
FROM
master.sys.server_triggers AS tr
LEFT OUTER JOIN master.sys.server_assembly_modules AS mod ON mod.object_id = tr.object_id
LEFT OUTER JOIN sys.server_sql_modules AS ssmod ON ssmod.object_id = tr.object_id
WHERE (tr.parent_class = 100)

"


# Test for Username/Password needed to connect - else assume WinAuth passthrough
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "Using SQL Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance –Username $myuser –Password $mypass 
	if ($results -eq $null)
    {
        Write-Output "No Server Triggers Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\01 - No Server Triggers Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    $fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Triggers"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }

     
    # SMO Script Out
	Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\Server_Triggers.sql" -Encoding ascii -Append
		Add-Content -Value "`r`n" -Path "$fullfolderPath\Server_Triggers.sql" -Encoding Ascii
    }
	
}
else
{
	Write-Output "Using Windows Auth"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance	
    if ($results -eq $null)
    {
        Write-Output "No Server Triggers Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\01 - No Server Triggers Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    $fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Triggers"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }

	# Export
	Foreach ($row in $results)
    {
        $row.Definition+"`r`nGO`r`n`r`n",$row.enableCMD+"`r`nGO`r`n" | out-file "$fullfolderPath\Server_Triggers.sql" -Encoding ascii -Append
    }
	    
}

# Return to Base
set-location $BaseFolder
