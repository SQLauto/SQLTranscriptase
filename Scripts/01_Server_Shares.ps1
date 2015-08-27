<#
.SYNOPSIS
    Gets the Windows SMB Shares on the target server
	
.DESCRIPTION
   Writes the SMB Shares out to the "01 - Server Shares" folder
   One file for all shares
   
.EXAMPLE
    01_Server_Shares.ps1 localhost
	
.EXAMPLE
    01_Server_Shares.ps1 server01 sa password

.Inputs
    ServerName\Instance, [SQLUser], [SQLPassword]

.Outputs
	Server NTFS File Shares in HTML Format
	
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

Set-StrictMode -Version latest

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "01 - Server Shares"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$SQLinstance = 'localhost'
}


# Parameter Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -b black -f yellow "Usage: ./01_Server_Shares.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"

# Need a string array to hold the Shares Objects from WMI
$ShareArray = @()

# We connect to the Windows Server Name, not the SQL Server Named Instance, so Split at the backslash
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

# Turn off automatic error handling, allow the error to surface into the ($?) object below
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

# Ping machine first, if dead, then dont even try WMI, it will hang
If (Test-Connection $WinServer -count 1 -quiet) 
{
    Write-Output 'The host responded to a ping'
}
else
{
    Write-Output 'The Queen is Dead. Long live the Queen'
    exit
}

# Do WMI Call
try
{
    $ShareArray = Get-WmiObject -Computer $WinServer -class Win32_Share | select Name, Path, Description | Where-Object -filterscript {$_.Name -ne "ADMIN$" -and $_.Name -ne "IPC$"} | sort-object name
	
	# Check "Automatic Variable"
	# https://technet.microsoft.com/en-us/library/hh847768.aspx
    if ($?)
    {
        Write-Output "Good WMI Connection"
    }
    else
    {
		#Warn User
        Write-Host -b black -f red "WMI could not connect"
        
        $fullfolderpath = "$BaseFolder\$SQLInstance\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        echo null > "$fullfolderpath\01 - Server Shares - WMI Could not connect.txt"
        
        Set-Location $BaseFolder
        exit
    }
}

catch
{
    #Warn User
    Write-Host -b black -f red "WMI could not connect"
    
    $fullfolderpath = "$BaseFolder\$SQLInstance\"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }
    echo null > "$fullfolderpath\01 - Server Shares - WMI Could not connect.txt"
       
    Set-Location $BaseFolder
    exit
}


# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 

# Create Output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Shares\"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}


# Create some CSS to help my HTML with rollover highlighting
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

# Create the CSS File
$myCSS | out-file "$fullfolderPath\HTMLReport.css" -Encoding ascii


# Iterate and Export
$ShareArray | select Name, Path, Description  | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\HtmlReport.html"


# Return to base
set-location "$BaseFolder"
