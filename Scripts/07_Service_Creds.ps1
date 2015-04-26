﻿<#
.SYNOPSIS
    Gets the NT Service Credentials used to start each SQL Server exe
	
.DESCRIPTION
    Writes the Service Credentials out to the "07 - Service Startup Creds" folder, 
	file "Service Startup Credentials.sql"
	
.EXAMPLE
    07_Service_Creds.ps1 localhost
	
.EXAMPLE
    07_Service_Creds.ps1 server01 sa password

.Inputs
    ServerName

.Outputs
	HTML Files
	
.NOTES
    George Walkey
    Richmond, VA USA
	
.LINK
    https://github.com/gwalkey
	
#>

Param(
  [string]$SQLInstance
)



[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "07 - Service Credentials"


if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./07_Service_Creds.ps1 'SQLServerName'"
    Set-Location $BaseFolder
    exit
}


# Working
Write-host "Server $SQLInstance"


# If SQLInstance is a named instance, drop the instance part so we can connect to the Windows server only
$pat = "\\"

if ($SQLInstance -match $pat)
{    
    $SQLInstance2 = $SQLInstance.Split('\')[0]
}
else
{
    $SQLInstance2 = $SQLInstance
}


# Lets trap some WMI errors
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'


# Get SQL Services with stardard names 
try
{
    $results1 = @()
    $results1 = gwmi -class win32_service  -computer $SQLInstance2 -filter "name like 'MSSQLSERVER%' or name like 'MsDtsServer%' or name like 'MSSQLFDLauncher%'  or Name like 'MSSQLServerOLAPService%'  or Name like 'SQL Server Distributed Replay Client%'  or Name like 'SQL Server Distributed Replay Controller%'  or Name like 'SQLBrowser%'  or Name like 'SQLSERVERAGENT%'  or Name like 'SQLWriter%'  or Name like 'ReportServer%' or Name like 'SQLAgent%' or Name like 'MSSQL%'" 
    if ($?)
    {
        Write-Host "WMI Connected"
    }
    else
    {
        $fullfolderpath = "$BaseFolder\$SQLInstance\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }

        Write-Host -b black -f red "No WMI connection to target server"
        echo null > "$fullfolderpath\07 - Service Creds - WMI Could not connect.txt"
        Set-Location $BaseFolder
        exit
    }

}
catch
{
    $fullfolderpath = "$BaseFolder\$SQLInstance\"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }

    Write-Host -b black -f red "No WMI connection to target server"
    echo null > "$fullfolderpath\07 - Service Creds - WMI Could not connect.txt"
    Set-Location $BaseFolder
    exit
}

# Reset default PS error handler - WMI errors
$ErrorActionPreference = $old_ErrorActionPreference 


$fullfolderPath = "$BaseFolder\$sqlinstance\07 - Service Startup Creds"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
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

$myCSS | out-file "$fullfolderPath\HTMLReport.css" -Encoding ascii

$mySettings = $results1
$mySettings | select Name, startName  | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\HtmlReport.html"


set-location $BaseFolder