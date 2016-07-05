param(
    [parameter(mandatory=$true)]
    [string]$projectFilePath,

    [parameter(mandatory=$true)]
    [string]$outputPathPatternOfReferencedProjects
)

.$PSScriptRoot\VerifyAppEntryPointContainsEmbeddedAssemblyResolver.ps1 -projectFilePath $projectFilePath

.$PSScriptRoot\EnsureAllDependenciesAreEmbedded.ps1 -projectFilePath $projectFilePath

.$PSScriptRoot\RestoreEmbeddedAssemblies.ps1 `
    -projectFilePath $projectFilePath `
    -outputPathPatternOfReferencedProjects $outputPathPatternOfReferencedProjects