param(
    [parameter(mandatory=$true)]
    $projectFilePath
)

Set-StrictMode -Version "2.0"
$ErrorActionPreference = "Stop"

. $PSScriptRoot\common\ProjectAnalysis.ps1
. $PSScriptRoot\common\Filters.ps1

function Unify-CodeSnippet 
{
    param(
        [parameter(ValueFromPipeline=$true)]
        [string]$codeSnippet
    )

    $codeSnippet `
        | Replace -pattern "[\r][\n]" -on "`n" `
        | Replace -pattern "[\n]+" -on " " `
        | Replace -pattern "[\t]+" -on " " `
        | Replace -pattern "[ ]+" -on " "
}

$entryFilePath = Get-ProjectEntryPointPath -projectFilePath $projectFilePath

$entryClassName = Split-Path -Leaf $entryFilePath | Substring -beforeFirst "."

# the only thing that entry point class should have in its static constructor 
# is the assembly resolving handler. Other code can potentially trigger initialization of types
# that yet cannot be resolved
$embeddedAssemblyResolverCode = 
@"
static $entryClassName()
{
    AppDomain.CurrentDomain.AssemblyResolve += (sender, args) =>
	{
		var resourceName = Assembly.GetExecutingAssembly().GetName().Name
			+ ".Embedded."
			+ new AssemblyName(args.Name).Name
			+ ".dll";

		using (var assemblyDataStream = Assembly
			.GetExecutingAssembly()
			.GetManifestResourceStream(resourceName))
		{
			if (assemblyDataStream == null)
			{
				return null;
			}

			var assemblyData = new byte[assemblyDataStream.Length];
			assemblyDataStream.Read(assemblyData, 0, assemblyData.Length);
			return Assembly.Load(assemblyData);
		}     
    };
}
"@ | Out-String 

$unifiedEntryFileContent =  Get-Content $entryFilePath `
    | Out-String `
    | Unify-CodeSnippet

$unifiedAssemblyResolverCode = $embeddedAssemblyResolverCode | Unify-CodeSnippet

if (-not $unifiedEntryFileContent.Contains($unifiedAssemblyResolverCode))
{
    $entryClassFileName = $entryFilePath | Split-Path -Leaf

    $errorMessage = 
@"
Assembly resolver handler for embedded assembiles is not detected. Consider to add the following code snippet to the assembly's entry class file ($entryClassFileName):

$embeddedAssemblyResolverCode`n}
"@ | Out-String

    Write-Error $errorMessage
}