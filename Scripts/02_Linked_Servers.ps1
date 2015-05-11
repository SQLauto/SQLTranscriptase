<#
.SYNOPSIS
    Gets the Linked Servers on the target server
	
.DESCRIPTION
   Writes the Linked Servers out to the "02 - Linked Servers" folder
   One file for all servers 
   Once recreated, you will have to input the server credentials, as passwords are NOT scripted out
   
.EXAMPLE
    02_Linked_Servers.ps1 localhost
	
.EXAMPLE
    02_Linked_Servers.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "02 - Linked Servers"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./02_Linked_Servers.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
      Set-Location $BaseFolder
    exit
}


# Working
Write-host "Server $SQLInstance"


$sql = 
"
SELECT
    'EXEC master.dbo.sp_addlinkedserver @server=N'+CHAR(39)+serv.NAME+CHAR(39)+
	', @srvproduct=N'+CHAR(39)+serv.product+CHAR(39)+
	case serv.product when 'SQL Server' then '' else ', @provider=N'+char(39)+serv.provider+CHAR(39) END +
	', @datasrc=N'+CHAR(39)+serv.data_source+CHAR(39)+
	CHAR(13)+CHAR(10)+
    'EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'+CHAR(39)+serv.name+CHAR(39)+
	', @useself=N'+CHAR(39)+case when ls_logins.uses_self_credential=1 then 'True' else 'False' END +CHAR(39)+	
	', @locallogin=N'+CHAR(39)+COALESCE(prin.name,'',prin.name)+CHAR(39)+
    case when ls_logins.uses_self_credential=0 then ', @rmtuser=N'+char(39)+ coalesce(ls_logins.remote_name,'',ls_logins.remote_name)+char(39)+ ', @rmtpassword='+ char(39) + '########' + char(39) else '' end
FROM
    sys.servers AS serv
    LEFT JOIN sys.linked_logins AS ls_logins
    ON serv.server_id = ls_logins.server_id
    LEFT JOIN sys.server_principals AS prin
    ON ls_logins.local_principal_id = prin.principal_id
WHERE serv.name<>@@SERVERNAME

"

# Create Output Folder
$fullfolderPath = "$BaseFolder\$sqlinstance\02 - Linked Servers"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}

# Delete pre-existing negative file
if(test-path -path "$BaseFolder\$SQLInstance\02 - No Linked Servers Found.txt")
{
    Remove-Item "$BaseFolder\$SQLInstance\02 - No Linked Servers Found.txt"
}

	
# Test for Username/Password needed to connect - else assume WinAuth passthrough
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-host "Using Sql Auth"	

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance –Username $myuser –Password $mypass 

    if ($results -eq $null)
    {
        write-host "No Linked Servers Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\02 - No Linked Servers Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    New-Item "$fullfolderPath\Linked_Servers.sql" -type file -force  |Out-Null    
    Add-Content -Value "--- Remember to add proper credentials to your Linked Servers `r`n" -Path "$fullfolderPath\Linked_Servers.sql" -Encoding Ascii
	
    # Script out
    Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\Linked_Servers.sql" -Encoding ascii -Append
		Add-Content -Value "GO`r`n" -Path "$fullfolderPath\Linked_Servers.sql" -Encoding Ascii
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
        write-host "No Linked Servers Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\02 - No Linked Servers Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    New-Item "$fullfolderPath\Linked_Servers.sql" -type file -force  |Out-Null    
    Add-Content -Value "--- Remember to add proper credentials to your Linked Servers `r`n" -Path "$fullfolderPath\Linked_Servers.sql" -Encoding Ascii

    # Script Out	
    Foreach ($row in $results)
    {
        $row.column1 | out-file "$fullfolderPath\Linked_Servers.sql" -Encoding ascii -Append
		Add-Content -Value "GO`r`n" -Path "$fullfolderPath\Linked_Servers.sql" -Encoding Ascii
    }
}

set-location $BaseFolder


