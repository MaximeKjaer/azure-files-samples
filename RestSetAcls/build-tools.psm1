function Get-PowerShellFiles {
    Get-ChildItem $PSScriptRoot -Exclude bin `
    | Get-ChildItem -Recurse -Include *.psd1, *.psm1, *.ps1
}

function Lint {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path = "$PSScriptRoot\RestSetAcls"
    )

    Invoke-ScriptAnalyzer -Path $Path -Settings $PSScriptRoot\PSScriptAnalyzerSettings.ps1 -Recurse -Outvariable issues
    $errors = $issues.Where({ $_.Severity -eq 'Error' })
    $warnings = $issues.Where({ $_.Severity -eq 'Warning' })
    $infos = $issues.Where({ $_.Severity -eq 'Information' })

    if ($errors.Count -gt 0 -or $warnings.Count -gt 0) {
        Write-Error "There were $($errors.Count) errors, $($warnings.Count) warnings and $($infos.Count) infos total." -ErrorAction Stop
    }
    else {
        Write-Output "There were $($errors.Count) errors, $($warnings.Count) warnings and $($infos.Count) infos total."
    }
}

function Test-Format {
    $failed = $false

    foreach ($file in Get-PowerShellFiles) {
        $content = Get-Content -Path $file -Raw
        $formatted = Invoke-Formatter -ScriptDefinition $content -Settings $PSScriptRoot\PSScriptAnalyzerSettings.ps1
        
        if ($content -ne $formatted) {
            Write-Host "File $($file.FullName) is not formatted correctly." -ForegroundColor Red
            $failed = $true
        }
    }

    if ($failed) {
        Write-Error "There were formatting issues." -ErrorAction Stop
    }
    else {
        Write-Output "There were no formatting issues."
    }
}

function Format {
    foreach ($file in Get-PowerShellFiles) {
        $content = Get-Content -Path $file -Raw
        $formatted = Invoke-Formatter -ScriptDefinition $content -Settings $PSScriptRoot\PSScriptAnalyzerSettings.ps1
        
        if ($content -ne $formatted) {
            Write-Host "Reformatting $file" -ForegroundColor Blue
            Set-Content -Path $file -Value $formatted            
        }
        else {
            Write-Host "File $($file.FullName) is already formatted correctly." -ForegroundColor Green
        }
    }
}

function Test {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path = "$PSScriptRoot\test\unit"
    )
    Invoke-Pester -Path $Path -Output Detailed
}

function Test-Integration {
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile = "$PSScriptRoot\test\integration\config.json",

        [Parameter(ValueFromRemainingArguments = $true)]
        [psobject[]]$RemainingArgs
    )
    # Check if the config file exists
    if (-not (Test-Path -Path $ConfigFile)) {
        Write-Error "Config file not found: $ConfigFile" -ErrorAction Stop
    }

    # Parse config into Pester container
    $config = Get-Content -Raw $ConfigFile | ConvertFrom-Json -AsHashtable
    $container = New-PesterContainer -Path $PSScriptRoot\test\integration -Data @{ InputConfig = $config }

    # Build object we can splat into Invoke-Pester
    # See https://stackoverflow.com/a/71073148/918389
    $params = foreach ($arg in $RemainingArgs) {
        if ($arg.StartsWith('-')) {
            $prop = [psnoteproperty]::new('<CommandParameterName>', $arg)
            $arg.PSObject.Properties.Add($prop)
        }
        $arg
    }

    Invoke-Pester -Container $container -Output Detailed @params
}

function Test-Manifest {
    Test-ModuleManifest -Path $PSScriptRoot\RestSetAcls\RestSetAcls.psd1
}

function Test-All {
    Test
    Lint
    Test-Manifest
    Test-Format
}

function Build-Docs {
    Import-Module -Name $PSScriptRoot\RestSetAcls\RestSetAcls.psd1 -Force
    New-MarkdownHelp -Module RestSetAcls -OutputFolder $PSScriptRoot\docs -Force
}
