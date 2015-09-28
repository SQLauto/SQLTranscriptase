#$assembly = [Reflection.Assembly]::LoadWithPartialName(‘Microsoft.SqlServer.Dmf’)
#$assembly.GetExportedTypes() 

$asm = [Reflection.Assembly]::LoadFile("C:\Program Files (x86)\Microsoft SQL Server\120\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll")
$asm.GetTypes() | select Name, Namespace | sort Namespace, Name | ft -groupby Namespace

 [appdomain]::CurrentDomain

 [appdomain]::currentdomain.GetAssemblies()


 [appdomain]::currentdomain.GetAssemblies() | where {!($_.globalassemblycache)}