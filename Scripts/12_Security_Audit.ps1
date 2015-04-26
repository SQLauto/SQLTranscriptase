﻿<#
.SYNOPSIS
    Gets SQL Server Security Information from the target server
	
.DESCRIPTION
   Writes out the results of 5 SQL Queries to a sub folder of the Server Name
   One HTML file for each Query
   
.EXAMPLE
   12_Security_Audit.ps1 localhost
	
.EXAMPLE
    12_Security_Audit.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "12 - SQL Security Audit"


# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Host "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow -b black "Usage: ./SQLSecurityAudit.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
       Set-Location $BaseFolder
    exit
}


# Working
Write-host "Server $SQLInstance"


# Server connection check and Get Running Version
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


# Load SQL SMO Assemblies
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended')  | out-null

# Set Local Vars
$server = $SQLInstance

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

# Create Output Folder
$fullfolderPath = "$BaseFolder\$sqlinstance\12 - Security Audit"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Export Security Information:
# 1) SQL Logins

$sql1 = 
"
--- Server Logins
--- Q1 Logins, Default DB,  Auth Type, and FixedServerRole Memberships
SELECT 
	name as 'Login', 
	dbname as 'DBName',
	[language],  
	CONVERT(CHAR(10),CASE denylogin WHEN 1 THEN 'X' ELSE '--' END) AS IsDenied, 
	CONVERT(CHAR(10),CASE isntname WHEN 1 THEN 'X' ELSE '--' END) AS IsWinAuthentication, 
	CONVERT(CHAR(10),CASE isntgroup WHEN 1 THEN 'X' ELSE '--' END) AS IsWinGroup, 
	Createdate,
	Updatedate, 
	CONVERT(VARCHAR(2000), 
	CASE sysadmin WHEN 1 THEN 'sysadmin,' ELSE '' END + 
	CASE securityadmin WHEN 1 THEN 'securityadmin,' ELSE '' END + 
	CASE serveradmin WHEN 1 THEN 'serveradmin,' ELSE '' END + 
	CASE setupadmin WHEN 1 THEN 'setupadmin,' ELSE '' END + 
	CASE processadmin WHEN 1 THEN 'processadmin,' ELSE '' END + 
	CASE diskadmin WHEN 1 THEN 'diskadmin,' ELSE '' END + 
	CASE dbcreator WHEN 1 THEN 'dbcreator,' ELSE '' END + 
	CASE bulkadmin WHEN 1 THEN 'bulkadmin' ELSE '' END ) AS ServerRoles,
	CASE sysadmin WHEN 1 THEN '1' ELSE '0' END as IsSysAdmin
INTO 
	#syslogins 
FROM 
	master..syslogins WITH (nolock) 

UPDATE 
	#syslogins 
SET 
	ServerRoles = SUBSTRING(ServerRoles,1,LEN(ServerRoles)-1) 
WHERE 
	SUBSTRING(ServerRoles,LEN(ServerRoles),1) = ',' 

UPDATE 
	#syslogins SET ServerRoles = '--' 
WHERE 
	LTRIM(RTRIM(ServerRoles)) = '' 

select * from #syslogins order by IsSysAdmin desc, Login

drop table #syslogins

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

# Run Query 1
if ($serverauth -ne "win")
{
	Write-host "Using Sql Auth"
	$results = Invoke-SqlCmd -query $sql1 -Server $SQLInstance –Username $myuser –Password $mypass 
}
else
{
	Write-host "Using Windows Auth"	
	$results = Invoke-SqlCmd -query $sql1 -Server $SQLInstance      
}

# Write out rows
$results | select Login, DBName, language, IsDenied, IsWinAuthentication, IsWinGroup, CreateDate, UpdateDate, ServerRoles, IsSysAdmin| ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\1_Server_Logins.html"


set-location $BaseFolder

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{
    # Skip Certain System Databases
    if ($sqlDatabase.Name -in 'Model','TempDB','SSISDB','distribution','ReportServer','ReportServerTempDB') {continue}

    # Create Output Folders - One Per DataBase
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$fullfolderPath\Databases\$fixedDBname"
    
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null	
    }

    # Run Query 2
    $sql2 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
	    sp.name AS 'Login', 
	    dp.name AS 'User' 
    FROM 
    	sys.database_principals dp 
    INNER JOIN sys.server_principals sp 
        ON dp.sid = sp.sid 
    ORDER BY 
    	sp.name, 
    	dp.name;
    "
    #Write-Host $sql2

    # Run SQL
    if ($serverauth -ne "win")
    {
    	#Write-host "Using Sql Auth"
    	$results2 = Invoke-SqlCmd -query $sql2 -Server $SQLInstance –Username $myuser –Password $mypass 
    }
    else
    {
    	#Write-host "Using Windows Auth"	
    	$results2 = Invoke-SqlCmd -query $sql2 -Server $SQLInstance      
    }

    # Write out rows
    $myCSS | out-file "$output_path\HTMLReport.css" -Encoding ascii
    $results2 | select Login, User | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$output_path\2_Login_to_User_Mapping.html"

    set-location $BaseFolder

    # Run Query 3
    $sql3 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
	    b.name AS Role_name, 
	    a.name AS User_name 
    FROM 
    sysusers a 
    INNER JOIN sysmembers c 
    	on a.uid = c.memberuid
    INNER JOIN sysusers b 
    	ON c.groupuid = b.uid 
    	WHERE a.name <> 'dbo' 
    order by 
    	1,2
    "
    
    if ($serverauth -ne "win") 
    {
    	#Write-host "Using Sql Auth"
    	$results3 = Invoke-SqlCmd -query $sql3 -Server $SQLInstance –Username $myuser –Password $mypass 
    }
    else
    {
    	#Write-host "Using Windows Auth"	
    	$results3 = Invoke-SqlCmd -query $sql3 -Server $SQLInstance      
    }

    # Write out rows
    $results3 | select Role_Name, User_Name | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$output_path\3_Roles_Per_User.html"

    set-location $BaseFolder

    # Run Query 4
    $sql4 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
	    usr.name as 'User', 
	    CASE WHEN perm.state <> 'W' THEN perm.state_desc ELSE 'GRANT' END as 'Operation', 
	    perm.permission_name,  
	    CASE WHEN perm.state <> 'W' THEN '--' ELSE 'X' END AS IsGrantOption 
    FROM 
    	sys.database_permissions AS perm 
    INNER JOIN 
    	sys.database_principals AS usr 
    ON 
    	perm.grantee_principal_id = usr.principal_id 
    WHERE 
    	perm.major_id = 0 
    ORDER BY 
    	usr.name, perm.permission_name ASC, perm.state_desc ASC
    "
    
    if ($serverauth -ne "win") 
    {
    	#Write-host "Using Sql Auth"
    	$results4 = Invoke-SqlCmd -query $sql4 -Server $SQLInstance –Username $myuser –Password $mypass 
    }
    else
    {
    	#Write-host "Using Windows Auth"	
    	$results4 = Invoke-SqlCmd -query $sql4 -Server $SQLInstance      
    }

    # Write out rows    
    $results4 | select User, Operation, permission_name, IsGrantOption | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$output_path\4_DBLevel_Permissions.html"

    set-location $BaseFolder

    # Run Query 5
    $sql5 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
	    usr.name AS 'User', 
	    CASE WHEN perm.state <> 'W' THEN perm.state_desc ELSE 'GRANT' END AS PermType, 
	    perm.permission_name,
	    USER_NAME(obj.schema_id) AS SchemaName, 
	    obj.name AS ObjectName, 
	    CASE obj.Type  
		    WHEN 'U' THEN 'Table'
		    WHEN 'V' THEN 'View'
		    WHEN 'P' THEN 'Stored Proc'
		    WHEN 'FN' THEN 'Function'
	    ELSE obj.Type END AS ObjectType, 
	    CASE WHEN cl.column_id IS NULL THEN '--' ELSE cl.name END AS ColumnName, 
	    CASE WHEN perm.state = 'W' THEN 'X' ELSE '--' END AS IsGrantOption 
    FROM
	    sys.database_permissions AS perm 
    INNER JOIN sys.objects AS obj 
	    ON perm.major_id = obj.[object_id] 
    INNER JOIN sys.database_principals AS usr 
	    ON perm.grantee_principal_id = usr.principal_id 
    LEFT JOIN sys.columns AS cl 
	    ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id 
    WHERE 
	    obj.Type <> 'S'
    ORDER BY 
	    usr.name, perm.state_desc ASC, perm.permission_name ASC

    "
    
    if ($serverauth -ne "win") 
    {
    	#Write-host "Using Sql Auth"
    	$results5 = Invoke-SqlCmd -query $sql5 -Server $SQLInstance –Username $myuser –Password $mypass
    }
    else
    {
    	#Write-host "Using Windows Auth"	
    	$results5 = Invoke-SqlCmd -query $sql5 -Server $SQLInstance
    }

    # Write out rows    
    $results5 | select User, PermType, permission_name, SchemaName, ObjectName, ObjectType, ColumnName, IsGrantOption | ConvertTo-Html  -CSSUri "HtmlReport.css"| Set-Content "$output_path\5_Object_Permissions.html"

    set-location $BaseFolder

        
}



set-location $BaseFolder