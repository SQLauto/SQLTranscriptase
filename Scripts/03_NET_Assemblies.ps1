<#
.SYNOPSIS
    Gets the .NET Assemblies registered on the target server
	
.DESCRIPTION
   Writes the .NET Assemblies out to the "03 - NET Assemblies" folder
   One folder per Database
   One file for each registered DLL
   CREATE ASSEMBLY with the binary as a HEX STRING
   
.EXAMPLE
    03_NET_Assemblies.ps1 localhost
	
.EXAMPLE
    03_NET_Assemblies.ps1 server01 sa password

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

Write-Host  -f Yellow -b Black "03 - .NET Assemblies"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-Host -f yellow "Usage: ./03_NET_Assemblies.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
	    exit
	}
}


# Load SQL SMO Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended') | out-null

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
$output_path = "$BaseFolder\$SQLInstance\03 - NET Assemblies\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases - unless you actually installed SOME DLLs here!- bad monkey
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}


    # Strip brackets from DBname
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\03 - NET Assemblies\$fixedDBname"
    
               
    # Get Assemblies
    $mySQLquery = 
    "
    USE $fixedDBName
    GO
    SELECT  
    a.name as [AName],
    af.name as [DLL],
    'CREATE ASSEMBLY [' + a.name + '] FROM 0x' +
    convert(varchar(max),af.content,2) +
     ' WITH PERMISSION_SET=' +
    case 
	    when a.permission_set=1 then 'SAFE' 
	    when a.permission_set=2 then 'EXTERNAL_ACCESS' 
	    when a.permission_set=3 then 'UNSAFE'
    end as 'Content'
    FROM sys.assemblies a
    INNER JOIN sys.assembly_files af ON a.assembly_id = af.assembly_id 
    WHERE a.name <> 'Microsoft.SqlServer.Types' 
    "

    # Run SQL
    $results = @()
    if ($serverauth -eq "win")
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue -MaxCharLength 10000000 
    }
    else
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue -MaxCharLength 10000000 
    }

    # Any results?
    if ($results.count -gt 0)
    {
        Write-Output "Scripting out .NET Assemblies for: "$fixedDBName
    }

    foreach ($assembly in $results)
    {        
        # One Sub for each DB
        if(!(test-path -path $output_path))
        {
            mkdir $output_path | Out-Null
        }

        $myoutputfile = $output_path+"\"+$assembly.AName+'.sql'        
        $myoutputstring = $assembly.Content
        $myoutputstring | out-file -FilePath $myoutputfile -encoding ascii -width 5000000
    } 
            

# Process Next Database
}


# Return to Base
set-location $BaseFolder



