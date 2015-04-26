<#
.SYNOPSIS
    Gets the SQL Server Roles on the target server
	
.DESCRIPTION
   Writes the SQL Server Roles out to the "01 - Server Roles" folder
   One file for each role 
   
.EXAMPLE
    01_Server_Roles.ps1 localhost
	
.EXAMPLE
    01_Server_Roles.ps1 server01 sa password

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

Set-Location $BaseFolder

#  Script Name
Write-Host  -f Yellow -b Black "01 - Server Roles"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow -b black "Usage: ./01_Server_Roles.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
       Set-Location $BaseFolder
    exit
}


# Working
Write-host "Server $SQLInstance"


# Server connection check
$serverauth = "win"
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-host "Testing SQL Auth"
	try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Host $myver
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
	Write-host "Testing Windows Auth"
 	Try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Host $myver
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
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended')  | out-null

# Set Local Vars
$server 	= $SQLInstance

if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)
}
else
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)    
    $scripter   = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)
}

# Create Output Folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Roles"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Use TSQL, SMO is un-usable for Server Roles folks
$sql = 
"
with ServerPermsAndRoles as
(
    /*
    select
		'permission' as security_type,
		spm.permission_name collate SQL_Latin1_General_CP1_CI_AS as security_entity,
		spr.type_desc as principal_type,
        spr.name as principal_name,
        spm.state_desc
    from sys.server_principals spr
    inner join sys.server_permissions spm
    on spr.principal_id = spm.grantee_principal_id
    where type_desc='R'

    union all
    */

    select
		'role membership' as security_type,
		spr.name as security_entity,
		sp.type_desc as principal_type,
        sp.name as principal_name,        
        null as state_desc
    from sys.server_principals sp
    inner join sys.server_role_members srm
    on sp.principal_id = srm.member_principal_id
    inner join sys.server_principals spr
    on srm.role_principal_id = spr.principal_id
    where sp.type in ('s','u','r')
)
select 
    security_type,
    security_entity,
    principal_type,
    principal_name,
    state_desc 
from ServerPermsAndRoles
order by 1,2,3

"


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

# Run SQL
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-host "Using Sql Auth"
	$results = Invoke-SqlCmd -query $sql -Server $SQLInstance –Username $myuser –Password $mypass 
}
else
{
	Write-host "Using Windows Auth"	
	$results = Invoke-SqlCmd -query $sql  -Server $SQLInstance      
}

# Write out rows
$results | select security_type, security_entity, principal_type, principal_name, state_desc | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\HtmlReport.html"

set-location $BaseFolder
