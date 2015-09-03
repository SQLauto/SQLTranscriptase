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

Write-Host  -f Yellow -b Black "01 - Server Shares"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -b black -f yellow "Usage: ./01_Server_Shares.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"


$ShareArray = @()
# We connect to the Windows Server Name, not the SQL Server Named Instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

try
{

    $ShareArray = Get-WmiObject -Computer $WinServer -class Win32_Share | select Name, Path, Description | Where-Object -filterscript {$_.Name -ne "ADMIN$" -and $_.Name -ne "IPC$"} | sort-object name
    #$ShareArray | Out-GridView
    if ($?)
    {
        Write-Output "Good WMI Connection"
    }
    else
    {
    #Warn User
        Write-Host -b black -f red "Access Denied using WMI against target server"
        
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
    Write-Host -b black -f red "Access Denied using WMI against target server"
    
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


$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Shares\"
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

# Export It
$mySettings = $ShareArray
$mySettings | select Name, Path, Description  | ConvertTo-Html  -PreContent "<h1>$SqlInstance</H1><H2>Server Shares</h2>" -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\HtmlReport.html"


set-location "$BaseFolder"

