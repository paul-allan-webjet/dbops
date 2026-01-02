Function Get-DBOModuleFileList {
    <#
.SYNOPSIS
Returns all module files based on json file in the module root

.DESCRIPTION
Returns objects from internal\json\dbops.json. Is used internally to load files into the package.

.PARAMETER Type
Type of the module files to display

.PARAMETER Edition
Select only libraries relevant to the current edition of Powershell

.EXAMPLE
# Returns module files
Get-DBOModuleFileList

.EXAMPLE
# Returns only function files
Get-DBOModuleFileList -Type Functions
#>
    Param (
        [string[]]$Type,
        [string[]]$Edition = @('Desktop', 'Core')
    )
    Function ModuleFile {
        Param (
            $Path,
            $Type
        )
        $Path = Join-PSFPath -Normalize $Path
        $obj = @{} | Select-Object Path, Name, FullName, Type, Directory
        $obj.Path = $Path
        $obj.Directory = Split-Path $Path -Parent
        $obj.Type = $Type
        if ($Path -like '*:*') {
            $file = Get-Item -Path $Path
        }
        else {
            # Use module root set by dbops.psm1, fall back to PSScriptRoot parent for compatibility
            $moduleRoot = if ($script:ModuleRoot) { $script:ModuleRoot } else { (Get-Item $PSScriptRoot).Parent.FullName }
            $file = Get-Item -Path (Join-Path $moduleRoot $Path)
        }
        $obj.FullName = $file.FullName
        $obj.Name = $file.Name
        $obj
    }
    # Use module root set by dbops.psm1, fall back to PSScriptRoot parent for compatibility  
    $moduleRoot = if ($script:ModuleRoot) { $script:ModuleRoot } else { (Get-Item $PSScriptRoot).Parent.FullName }
    $moduleCatalog = Get-Content (Join-PSFPath -Normalize $moduleRoot "internal\json\dbops.json") -Raw | ConvertFrom-Json
    foreach ($property in $moduleCatalog.psobject.properties.Name) {
        if (!$Type -or $property -in $Type) {
            if ($property -eq 'Libraries') {
                $files = @()
                foreach ($e in $Edition) {
                    $files += $moduleCatalog.$property.$e
                }
            }
            else {
                $files = $moduleCatalog.$property
            }
            foreach ($file in $files) {
                ModuleFile -Path $file -Type $property
            }
        }
    }
}
