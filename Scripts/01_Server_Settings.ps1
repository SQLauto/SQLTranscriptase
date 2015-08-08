<#
.SYNOPSIS
    Gets the SQL Server Configuration Settings on the target server
	
.DESCRIPTION
   Writes the SQL Server Configuration Settings out to the "01 - Server Settings" folder
   One file for all settings
   Contains MinMax Memory, MAX DOP, Affinity, Cost Threshold, Network Packet size and other instance-level engine settings
   Helps to document a server that had non-default settings
   
.EXAMPLE
    01_Server_Settings.ps1 localhost
	
.EXAMPLE
    01_Server_Settings.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	HTML Files
	
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

Import-Module "sqlps" -DisableNameChecking -erroraction SilentlyContinue

#  Script Name
Write-Host  -f Yellow -b Black "01 - Server Settings"


# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Settings.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
        set-location $BaseFolder
	    exit
	}

}


# Load SQL SMO Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

# Set Local Vars
$server 	= $SQLInstance

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


# Create output folder
set-location $BaseFolder
$output_path = "$BaseFolder\$SQLInstance\01 - Server Settings\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }


# Create some CSS for help in column formatting
$myCSS = 
"
table
    {
        Margin: 0px 0px 0px 4px;
        Border: 1px solid rgb(190, 190, 190);
        Font-Family: Tahoma;
        Font-Size: 9pt;
        Background-Color: rgb(252, 252, 252);
    }
tr:hover td
    {
        Background-Color: rgb(150, 150, 220);
        Color: rgb(255, 255, 255);
    }
tr:nth-child(even)
    {
        Background-Color: rgb(242, 242, 242);
    }
th
    {
        Text-Align: Left;
        Color: rgb(150, 150, 220);
        Padding: 1px 4px 1px 4px;
    }
td
    {
        Vertical-Align: Top;
        Padding: 1px 4px 1px 4px;
    }
"


$myCSS | out-file "$output_path\HTMLReport.css" -Encoding ascii

$mySettings = $srv.Configuration.Properties
$mySettings | sort-object DisplayName | select Displayname, ConfigValue, runValue | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$output_path\HtmlReport.html"

# Get Buffer Pool Extensions

$mySQLquery = "
USE Master; select State, path, current_size_in_kb as sizeKB from sys.dm_os_buffer_pool_extension_configuration
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

# Export it
if ($sqlresults.state -eq 5)
{
    $strExport = "
    ALTER SERVER CONFIGURATION SET BUFFER POOL EXTENSION
    ON
    (
    	FILENAME = N'" + $sqlresults.path + "'," +
    "   SIZE = " + $sqlresults.sizeKB +"KB"+"`r`n"+
"    );"

    $strExport | out-file "$output_path\Buffer_Pool_Extension.sql" -Encoding ascii
}

# Return to Base
set-location $BaseFolder


