<#
.SYNOPSIS
    Gets the SQL Server Analysis Services database objects on the target server
	
.DESCRIPTION
   Writes the SSAS Objects out to the "10 - SSAS" folder   
   Objects are written out in XMLA format for easy re-creation in SSMS
   Objects include:
   Cubes
   KPI
   Fact Tables
   Dimensions
   Data   
   
.EXAMPLE
    10_SSAS_Databases.ps1 localhost
	
.EXAMPLE
    10_SSAS_Databases.ps1 server01 sa password


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
Write-Host  -f Yellow -b Black "10 - SSAS Databases"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./10_SSAS_Databases.ps1 `"ServerName`" ([`"Username`"] [`"Password`"] if DMZ/SQL-Auth machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-host "Server $SQLInstance"


# load the AMO and XML assemblies into the current session
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") > $null 
[System.Reflection.Assembly]::LoadWithPartialName("System.Xml") > $null 
$dateStamp = (get-Date).ToString("yyyyMMdd")

## connect to the server 


try
{
    $svr = new-Object Microsoft.AnalysisServices.Server 
    $svr.Connect($SQLInstance) 

    # Create output folder
    if ($svr.Databases.Count -ge 1)
    {
        $fullfolderPath = "$BaseFolder\$sqlinstance\10 - SSAS\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
    }

    # Write Out
    foreach ($db in $svr.Databases) 
    { 
        write-Host "Scripting SSAS Database: " $db.Name 
        $xw = new-object System.Xml.XmlTextWriter("$($fullfolderPath)10 - $($db.Name)_$($dateStamp).xmla", [System.Text.Encoding]::UTF8) 
        $xw.Formatting = [System.Xml.Formatting]::Indented 
        [Microsoft.AnalysisServices.Scripter]::WriteCreate($xw,$svr,$db,$true,$true) 
        $xw.Close() 
    } 
    $svr.Disconnect()
}
catch
{
    write-host "SSAS NOT running or cant connect on $SQLInstance"
    echo null > "$BaseFolder\$SQLInstance\10 - SSAS NOT running or cant connect.txt"
    exit
}

set-location $BaseFolder

