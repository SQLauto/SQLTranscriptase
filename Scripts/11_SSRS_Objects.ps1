<#
.SYNOPSIS
    Gets the SQL Server Reporting Services objects on the target server
	
.DESCRIPTION
   Writes the SSRS Objects out to the "11 - SSRS" folder   
   Objects written include:
   RDL files
   Timed Subscriptions
   RSreportserver.config file
   Encryption Keys   
   
.EXAMPLE
    11_SSRS_Objects.ps1 localhost
	
.EXAMPLE
    11_SSRS_Objects.ps1 server01 sa password


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
Write-Host  -f Yellow -b Black "11 - SSRS Objects"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./11_SSRS_Objects.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ/SQL Auth machine)"
    set-location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"


# Preload SQL PS module
import-module "sqlps" -DisableNameChecking -erroraction SilentlyContinue

set-location $BaseFolder

# Create output folder
$folderPath = "$BaseFolder\$sqlinstance"
if(!(test-path -path $folderPath))
{
    mkdir $folderPath | Out-Null
}

$mySQL = 
"
    --The first CTE gets the content as a varbinary(max)
    --as well as the other important columns for all reports,
    --data sources and shared datasets.
    WITH ItemContentBinaries AS
    (
      SELECT
         ItemID,
         ParentID,
         Name,
         [Type],
         CASE Type
           WHEN 2 THEN 'Report'
           WHEN 5 THEN 'Data Source'
           WHEN 7 THEN 'Report Part'
           WHEN 8 THEN 'Shared Dataset'
           ELSE 'Other'
         END AS TypeDescription,
         CONVERT(varbinary(max),Content) AS Content
      FROM ReportServer.dbo.Catalog
      WHERE Type IN (2,5,7,8)
    ),

    --The second CTE strips off the BOM if it exists...
    ItemContentNoBOM AS
    (
      SELECT
         ParentID,
         Name,
         [Type],
         TypeDescription,
         CASE
           WHEN LEFT(Content,3) = 0xEFBBBF
             THEN CONVERT(varbinary(max),SUBSTRING(Content,4,LEN(Content)))
           ELSE
             Content
         END AS Content
      FROM ItemContentBinaries
    )

    --The outer query gets the content in its varbinary, varchar and xml representations...
    SELECT
       ParentID,
       Name,
       [Type],
       TypeDescription,
       Content, --varbinary
       CONVERT(varchar(max),Content) AS ContentVarchar, --varchar
       CONVERT(xml,Content) AS ContentXML --xml
    FROM ItemContentNoBOM
    order by 2
"

$sqlToplevelfolders = "
SELECT [ItemId],[ParentID],[Path]
  FROM [ReportServer].[dbo].[Catalog]
  where Parentid is not null and [Type] = 1  
"


$Packages = @()
$toplevelfolders = @()

if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
Write-Output "Using SQL Auth"

	# First, see if the SSRS Database exists
	$exists = $FALSE
	
    [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
	   
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
    $server.ConnectionContext.LoginSecure = $false 
	$server.ConnectionContext.Login=$myuser
    $server.ConnectionContext.Password=$mypass

    if ( $null -ne $server.Databases["ReportServer"] ) { $exists = $true } else { $exists = $false }
	
    <#
    foreach($db in $server.databases)
	{  
	    if ($db.name -eq "ReportServer") {$exists = $TRUE; break}
	}
	#>

	if ($exists -eq $FALSE)
    {
        Write-Output "SSRS Database not found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\11 - SSRS Catalog - Not found or cant connect.txt"
        Set-Location $BaseFolder
        exit
    }

    $Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query $mySQL
    $toplevelfolders = Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance  -Username $myuser -Password $mypass  -Query $sqlToplevelfolders

}
else
{
    Write-Output "Using Windows Auth"

	# See if the SSRS Database Exists
	$exists = $FALSE

    # we set this to null so that nothing is displayed
	$null = [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
	   
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
	
    if ( $null -ne $server.Databases["ReportServer"] ) { $exists = $true } else { $exists = $false }   
    <#
	foreach($db in $server.databases)
	{  
	    if ($db.name -eq "ReportServer") {$exists = $TRUE; break}
	}
    #>
	
	if ($exists -eq $FALSE)
    {
        Write-Output "SSRS Catalog not found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\11 - SSRS Catalog - Not found or cant connect.txt"
        set-location $BaseFolder
        exit
    }

    $Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $mySQL
    $toplevelfolders = Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $sqlToplevelfolders

}

# Create output folders
set-location $BaseFolder
$fullfolderPath = "$BaseFolder\$sqlinstance\11 - SSRS"
$fullfolderPathRDL = "$BaseFolder\$sqlinstance\11 - SSRS\RDL"
$fullfolderPathSUB = "$BaseFolder\$sqlinstance\11 - SSRS\Timed Subscriptions"
$fullfolderPathKey = "$BaseFolder\$sqlinstance\11 - SSRS\Encryption Key"
$fullfolderPathSecurity = "$BaseFolder\$sqlinstance\11 - SSRS\Security"

if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}

if(!(test-path -path $fullfolderPathRDL))
{
    mkdir $fullfolderPathRDL | Out-Null
}

if(!(test-path -path $fullfolderPathSUB))
{
    mkdir $fullfolderPathSUB | Out-Null
}

if(!(test-path -path $fullfolderPathKey))
{
    mkdir $fullfolderPathKey | Out-Null
}

if(!(test-path -path $fullfolderPathSecurity))
{
    mkdir $fullfolderPathSecurity | Out-Null
}
	
# --------
# 1) RDL
# --------
Write-Host "Writing RDL.."

# Create Folder Structure to mirror SSRS ReportServer Catalog while dumping RDL into the respective folders
foreach ($tlfolder in $toplevelfolders)
{
    # Only Script out the Items for this Folder
    # Create Folder Structure
    $myNewStruct = $fullfolderPathRDL+$tlfolder.Path
    # Fixup forward slashes
    $myNewStruct = $myNewStruct.replace('/','\')
    if(!(test-path -path $myNewStruct))
    {
        mkdir $myNewStruct | Out-Null
    }

    # Only Script out the Items for this Folder
    $myParentID = $tlfolder.ItemID
    Foreach ($pkg in $Packages)
    {
        if ($pkg.ParentID -eq $myParentID)
        {
            # Report RDL
            if ($pkg.Type -eq 2)
            {    
                #Export
                $pkgName = $Pkg.name
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.rdl"
            }

            # Data Source
            if ($pkg.Type -eq 5)
            {    

                # Export
                $pkgName = $Pkg.name
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.dsrc.txt"
            }

            # Shared Dataset
            if ($pkg.Type -eq 8)
            {    

                $pkgName = $Pkg.name
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.shdset.txt"
            }

            # Other Types include
            # 3 - File/Resource
            # 4 - Linked Report
            # 6 - Model
            # 7 - 
            # 9 - 

        }
    }


}

<#
Foreach ($pkg in $Packages)
{
    $pkgName = $Pkg.name
   
    $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$fullfolderPathRDL\Reports\$pkgName.rdl"
}

#>


# ------------------------
# 2) SSRS Configuration
# ------------------------
Write-Output "Writing SSRS Settings to file..."
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

[int]$wmi1 = 0
try 
{
    $junk = get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_MSSQLSERVER\v10\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
    if ($?)
    {
        $wmi1 = 10
        Write-Output "Found SSRS v10 (2008)"
    }
    else
    {
        #Write-Host "NOT v10"
    }
}
catch
{
    #Write-Host "NOT v10"
}


if ($wmi1 -eq 0)
{
    try 
    {
        get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_MSSQLSERVER\v11\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
        if ($?)
        {
            $wmi1 = 11
            Write-Output "Found SSRS v11 (2012)"
        }
        else
        {
            #Write-Host "NOT v11"
        }
    }
    catch
    {
        #Write-Host "NOT v11"
    }
}

if ($wmi1 -eq 0)
{
    try 
    {
        get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_MSSQLSERVER\v12\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
        if ($?)
        {
            $wmi1 = 12
            Write-Output "Found SSRS v12 (2014)"
        }
        else
        {
            #Write-Host "NOT v12"
        }
    }
    catch
    {
        #Write-Host "NOT v12"
    }
}

# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 

# -------------------------
# 3) RSReportServer.config File
# -------------------------
# https://msdn.microsoft.com/en-us/library/ms157273.aspx

Write-Output "Saving RSReportServer.config file..."

# 2008
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# 2008 R2
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10_50.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10_50.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# 2012
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS11.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS11.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# 2014
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS12.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS12.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# -----------------------
# 4) Database Encryption Key
# -----------------------
Write-Output "Backing up SSRS Encryption Key..."
Write-Output "WMI found SSRS version "$wmi1

if ($wmi1 -eq 10)
{
    Write-Output "SSRS 2008 - cant access Encryption key from WMI. Please use rskeymgmt.exe on server to export the key"
    New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
    Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
}

# We use WMI against 2012/2014 SSRS Servers
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

# 2012
if ($wmi1 -eq 11)
{
    try
    {
        $serverClass = get-wmiobject -namespace "root\microsoft\sqlserver\reportserver\rs_mssqlserver\v11\admin" -class "MSReportServer_ConfigurationSetting" -computername $SQLInstance
        if ($?)
        {
            $result = $serverClass.BackupEncryptionKey("SomeNewSecurePassword$!")
            $stream = [System.IO.File]::Create("$fullfolderPathKey\ssrs_master_key.snk", $result.KeyFile.Length);
            $stream.Write($result.KeyFile, 0, $result.KeyFile.Length);
            $stream.Close();
        }
        else
        {
            New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
            Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
            Write-Output "Error Connecting to WMI for config file (v11)"
        }
    }
    catch
    {
        New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
        Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii        
        Write-Output "Error Connecting to WMI for config file (v11) 2"
    }
}

# 2014
if ($wmi1 -eq 12)
{
    try
    {
        $serverClass = get-wmiobject -namespace "root\microsoft\sqlserver\reportserver\rs_mssqlserver\v12\admin" -class "MSReportServer_ConfigurationSetting" -computername $SQLInstance
        if ($?)
        {
            $result = $serverClass.BackupEncryptionKey("SomeNewSecurePassword$!")
            $stream = [System.IO.File]::Create("$fullfolderPathKey\ssrs_master_key.snk", $result.KeyFile.Length);
            $stream.Write($result.KeyFile, 0, $result.KeyFile.Length);
            $stream.Close();
        }
        else
        {
            New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
            Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii            
            Write-Output "Error Connecting to WMI for config file (v12)"
        }
    }
    catch
    {
        New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
        Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
        Write-Output "Error Connecting to WMI for config file (v12) 2"
    }
}

# Reset default PS error handler - cause WMI error trapping sucks
$ErrorActionPreference = $old_ErrorActionPreference 

# ---------------------
# 5) Timed Subscriptions
# ---------------------
Write-Output "Dumping Timed Subscriptions..."

# Need an array for this to work
$rs2012 = @()

# Error trapping off for webserviceproxy calls
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

[int]$websvc1 = 0
try
{
    $rs2012 += New-WebServiceProxy -Uri "http://$SQLInstance/ReportServer/ReportService2010.asmx" -Namespace SSRS.ReportingService2010 -UseDefaultCredential
    if ($?)
    {
        $websvc1 = 1
        Write-Output "Found SSRS Webservice running...dumping Timed Subscriptions"

        # WebService is up and running, dump out Subscriptions
        $subscriptions += $rs2012.ListSubscriptions("/"); # use "/" for default native mode site        
        foreach ($sub in $subscriptions)
        {        
            $myoutputfile = $sub.Report+".txt"
            $sub | select Path,Report, Description, Owner, SubscriptionID, Status  | out-file -filepath $fullfolderPathSUB\$myoutputfile -Encoding ascii
        }
    }
    else
    {
        Write-Output "SSRS Web Service was not running"
    }
}
catch
{
    Write-Output "SSRS Web Service was not running"
}

# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 

# --------------------
# 6) Report Security
# --------------------
# http://stackoverflow.com/questions/6600480/ssrs-determine-report-permissions-via-reportserver-database-tables
#
# Item-level role assignments
# System-level role assignments
# Predefined roles - https://msdn.microsoft.com/en-us/library/ms157363.aspx
#  Content Manager Role
#  Publisher Role 
#  Browser Role
#  Report Builder Role
#  My Reports Role
#  System Administrator Role
#  System User Role

$sqlSecurity = "
Use ReportServer;
select E.Path, E.Name, C.UserName, D.RoleName
from dbo.PolicyUserRole A
   inner join dbo.Policies B on A.PolicyID = B.PolicyID
   inner join dbo.Users C on A.UserID = C.UserID
   inner join dbo.Roles D on A.RoleID = D.RoleID
   inner join dbo.Catalog E on A.PolicyID = E.PolicyID
order by 1
"


# Get Permissions
# Error trapping off for webserviceproxy calls
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
    Write-Output "Using SQL Auth"
    $sqlPermissions = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $sqlSecurity -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
    Write-Output "Using Windows Auth"
    $sqlPermissions = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $sqlSecurity -QueryTimeout 10 -erroraction SilentlyContinue
}


# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 

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

$myCSS | out-file "$fullfolderPathSecurity\HTMLReport.css" -Encoding ascii


$sqlPermissions | select Path, Name, UserName, RoleName  | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPathSecurity\HtmlReport.html"


# Return to Base
set-location $BaseFolder

