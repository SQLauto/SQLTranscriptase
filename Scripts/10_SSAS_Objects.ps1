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
    10_SSAS_Objects.ps1 localhost
	
.EXAMPLE
    10_SSAS_Objects.ps1 server01 sa password


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
  [string]$SQLInstance = "localhost",
  [string]$myuser,
  [string]$mypass
)

$dateStamp = (get-Date).ToString("yyyyMMdd")

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


#  Script Name
Write-Host  -f Yellow -b Black "10 - SSAS Objects"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$SQLInstance = 'localhost'
}

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./10_SSAS_Objects.ps1 `"ServerName`" ([`"Username`"] [`"Password`"] if DMZ/SQL-Auth machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"


# load the AMO and XML assemblies into the current session
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("System.Xml") | out-null


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
    Write-Output "Scripting out SSAS Database Objects..."

    $encoding = [System.Text.Encoding]::UTF8
    foreach ($db in $svr.Databases) 
    {         
        # Create SubFolder for each SSAS Database
        $SSASDBname = $db.Name
        $SSASDBFolderPath = "$fullfolderPath\$SSASDBname"
        if(!(test-path -path $SSASDBFolderPath))
        {
            mkdir $SSASDBFolderPath | Out-Null
        }

        # 0) Script Out Entire Database as XMLA
        $xw = new-object System.Xml.XmlTextWriter("$SSASDBFolderPath\Full Database - $($db.Name).xmla",$encoding)
        $xw.Formatting = [System.Xml.Formatting]::Indented 
        [Microsoft.AnalysisServices.Scripter]::WriteCreate($xw,$svr,$db,$true,$true) 
        $xw.Close() 
        
        # --------------------------------------------------------------------------------------------
        # If I am a MultiDimensional Cube-type DB, Process here, else handle Tabular Databases below
        # --------------------------------------------------------------------------------------------
        if ($Db.ModelType -eq "Multidimensional")
        {

        Write-Output ("Multidimensional Database: {0}" -f $db.Name)

        # Now, each SSAS element: Cube, Measures, Dimensions, Partitions, Mining Structures, Roles, Assemblies, Data Sources, Data Source Views
        $CubeFolderPath = "$SSASDBFolderPath\Cubes"
        if(!(test-path -path $CubeFolderPath))
        {
            mkdir $CubeFolderPath | Out-Null
        }
        
        # 1) Cubes
        $Cubes=New-object Microsoft.AnalysisServices.Cube
        $Cubes=$db.cubes
        foreach ($cube in $cubes)
        {
            # Each Cube gets its own folder of Cubes, MeasureGroups and MGPartition objects
            $CubeName = $Cube.Name
            $Cube2FolderPath = "$CubeFolderPath\$CubeName"
            if(!(test-path -path $Cube2FolderPath))
            {
                mkdir $Cube2FolderPath | Out-Null
            }

            $xc = new-object System.Xml.XmlTextWriter("$Cube2FolderPath\Cube - $($cube.Name).xmla",$encoding)
            $xc.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xc,$svr,$cube,$true,$true) 
            $xc.Close() 

            # Write con
            Write-Output (" Cube: {0}, State:{1}, LastProcessed:{2}" -f $cube.name, $cube.state, $cube.lastprocessed)
        

            # 2) Measure Groups and Partitions
            $MGFolderPath = "$Cube2FolderPath\MeasureGroups"
            if(!(test-path -path $MGFolderPath))
            {
                mkdir $MGFolderPath | Out-Null
            }

            $MGroups=$cube.MeasureGroups
            foreach ($MG in $MGroups)
            {

                # Each Measure Group gets its own folder for Measure Group Partition objects
                $MGName = $MG.Name
                $MGPartFolderPath = "$MGFolderPath\$MGName"
                if(!(test-path -path $MGPartFolderPath))
                {
                    mkdir $MGPartFolderPath | Out-Null
                }

                $xm = new-object System.Xml.XmlTextWriter("$MGPartFolderPath\MeasureGroup - $($MG.Name).xmla",$encoding)
                $xm.Formatting = [System.Xml.Formatting]::Indented 
                [Microsoft.AnalysisServices.Scripter]::WriteCreate($xm,$svr,$MG,$true,$true) 
                $xm.Close() 

                # Write con
                Write-Output ("  Measure Group: {0}" -f $MG.Name)
                
                # 3) Measure Group Partitions
                foreach ($partition in $mg.Partitions)
                {


                    $xmgp = new-object System.Xml.XmlTextWriter("$MGPartFolderPath\Measure Group Partition - $($partition.Name).xmla",$encoding)
                    $xmgp.Formatting = [System.Xml.Formatting]::Indented 
                    [Microsoft.AnalysisServices.Scripter]::WriteCreate($xmgp,$svr,$partition,$true,$true) 
                    $xmgp.Close() 
    
                    # Write con
                    Write-Output ("   Measure Group Partition: {0}" -f $partition.Name)
                }
                        
            }

        }

        # 4) Dimensions
        $DimFolderPath = "$SSASDBFolderPath\Dimensions"
        if(!(test-path -path $DimFolderPath))
        {
            mkdir $DimFolderPath | Out-Null
        }
        $Dimensions=New-object Microsoft.AnalysisServices.Dimension
        $Dimensions=$db.Dimensions
        foreach ($dim in $Dimensions)
        {
            $xd = new-object System.Xml.XmlTextWriter("$DimFolderPath\Dimension - $($dim.Name).xmla",$encoding)
            $xd.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xd,$svr,$dim,$true,$true) 
            $xd.Close() 

            # Write con
            Write-Output (" Dimension: {0}" -f $Dim.Name)
        }

        # 5) Mining Structures
        $MiningFolderPath = "$SSASDBFolderPath\MiningStructures"
        if(!(test-path -path $MiningFolderPath))
        {
            mkdir $MiningFolderPath | Out-Null
        }
        
        # 6) Roles
        $RolesFolderPath = "$SSASDBFolderPath\Roles"
        if(!(test-path -path $RolesFolderPath))
        {
            mkdir $RolesFolderPath | Out-Null
        }

        # 7) Assemblies
        $AssemblyFolderPath = "$SSASDBFolderPath\Assemblies"
        if(!(test-path -path $AssemblyFolderPath))
        {
            mkdir $AssemblyFolderPath | Out-Null
        }

        # 8) Data Sources
        $DSFolderPath = "$SSASDBFolderPath\DataSources"
        if(!(test-path -path $DSFolderPath))
        {
            mkdir $DSFolderPath | Out-Null
        }

        # 9) Data Source Views
        $DSVFolderPath = "$SSASDBFolderPath\DataSourceViews"
        if(!(test-path -path $DSVFolderPath))
        {
            mkdir $DSVFolderPath | Out-Null
        }

        # End MD Scripting
        }

        else
        {
            Write-Output ("Tabular Database: {0}" -f $db.Name)
        }

    } 
    $svr.Disconnect()
}
catch
{
    Write-Output "SSAS not running or cant connect to $SQLInstance"
    echo null > "$BaseFolder\$SQLInstance\10 - SSAS not running or cant connect.txt"
    exit
}


Write-Output ("Exported: {0} SSAS Databases" -f $svr.Databases.Count)

set-location $BaseFolder

