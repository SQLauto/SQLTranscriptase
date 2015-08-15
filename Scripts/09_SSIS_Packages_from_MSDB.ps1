<#
.SYNOPSIS
    Gets the SQL Server Integration Services packages stored in MSDB on the target server
	
.DESCRIPTION
   Writes the SSIS Packages out to the "09 - SSIS_MSDB" folder
   
.EXAMPLE
    09_SSIS_Packages_from_MSDB.ps1 localhost
	
.EXAMPLE
    09_SSIS_Packages_from_MSDB.ps1 server01 sa password

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


#  Script Name
Write-Host  -f Yellow -b Black "09 - SSIS Packages from MSDB"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-Host -f yellow "Usage: ./09_SSIS_Packages_from_MSDB.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"

import-module "sqlps" -DisableNameChecking -erroraction SilentlyContinue
	
# Get SQL Version Number First, the Queries below need to look in other tables based on 2005 or later
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{	   
	try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Output $myver
        }	
	}
	catch
    {
	    Write-Output "Cannot Connect to $SQLInstance" 
        set-location $BaseFolder
	    exit
	}
}

else

{
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
        Write-Output "Cannot Connect to $SQLInstance"
        set-location $BaseFolder
	    exit
	}

}

# Create output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\09 - SSIS_MSDB"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }


# SSIS 2005
if ($myver -like "9.0*")
{

    Write-Output "SSIS is 2005"

    $Packages = @()
    # SQL Auth
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
        {
        Write-Output "Using SQL Auth"

        $Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query "        
        with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysdtspackagefolders90 PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysdtspackagefolders90 CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysdtspackages90 P on P.folderid = F.folderid
        WHERE F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "

         
    }
    else
    {
        Write-Output "Using Windows Auth"
        $Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query "
        with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysdtspackagefolders90 PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysdtspackagefolders90 CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysdtspackages90 P on P.folderid = F.folderid
        WHERE F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "
    }

    #Save
    Foreach ($pkg in $Packages)
    {
    
        $pkgName = $Pkg.packagename
        $folderPath = $Pkg.rootfolder
        $fullfolderPath = "$BaseFolder\$SQLInstance\09 - SSIS_MSDB\$folderPath\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"
    }
}

# SSIS 2008 +
else
{
    Write-Output "SSIS is 2008+"
	
    $Packages = @()
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
        {
        Write-Output "Using SQL Auth"

        $Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query "
        with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysssispackagefolders PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysssispackagefolders CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysssispackages P on P.folderid = F.folderid
        WHERE    F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "

    }
    else
    {
        Write-Output "Using Windows Auth"
        $Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query "
        with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysssispackagefolders PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysssispackagefolders CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysssispackages P on P.folderid = F.folderid
        WHERE    F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "
    }


    # Export
    Foreach ($pkg in $Packages)
    {
    
        $pkgName = $Pkg.packagename
        $folderPath = $Pkg.rootfolder
        $fullfolderPath = "$BaseFolder\$SQLInstance\09 - SSIS_MSDB\$folderPath\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"
		$Pkg.packagename
    }
    Write-Output ("Exported: {0} SSIS MSDB Packages" -f $packages.count)
}

# Return to Base
set-location $BaseFolder
