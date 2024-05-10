function New-File {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$Context,
        [string]$FileShareName,
        [string]$BasePath,
        [string]$FileName,
        [string]$ContentString
    )

    $filePath = $BasePath + "/" + $FileName

    if ($PSCmdlet.ShouldProcess($filePath, "Create file")) {
        # Create file locally
        $localFilePath = Join-Path -Path $env:TEMP -ChildPath $FileName
        New-Item `
            -Path $localFilePath `
            -Value $ContentString `
            -ItemType File `
            -Confirm:$false `
            -Force `
            | Out-Null

        # Upload it
        $ProgressPreference = "SilentlyContinue"
        Set-AzStorageFileContent `
            -Context $Context `
            -ShareName $FileShareName `
            -Path $filePath `
            -Source $localFilePath `
            -WhatIf:$false `
            -Confirm:$false `
            -Verbose:$false `
            -Force | Out-Null
        $ProgressPreference = "Continue";

        # Remove local file
        Remove-Item `
            -Path $localFilePath `
            -Confirm:$false `
            | Out-Null
    }
}

function New-Folder {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$Context,
        [string]$ShareName,
        [string]$Path
    )

    if ($PSCmdlet.ShouldProcess($Path, "Create directory")) {
        New-AzStorageDirectory `
            -Context $Context `
            -ShareName $ShareName `
            -Path $Path `
            | Out-Null
    }
}

function New-ArborescenceInner
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$context,
        [string]$FileShareName,
        [string]$BasePath,
        [int]$NumberDirs,
        [int]$NumberFilesPerDir,
        [int]$Depth,
        [switch]$PassThru
    )

    if ($Depth -eq 0)
    {
        # Create file
        for ($j = 1; $j -le $NumberFilesPerDir; $j++)
        {
            $fileName = "file-$j.txt"

            New-File `
                -Context $context `
                -FileShareName $FileShareName `
                -BasePath $BasePath `
                -FileName $fileName `
                -ContentString "Hello, world!" `
                -WhatIf:$WhatIfPreference `
                -Verbose:$VerbosePreference

            if ($PassThru) {
                Write-Output "$BasePath/$fileName"
            }
        }
    }
    else
    {
        for ($i = 1; $i -le $NumberDirs; $i++)
        {
            # Create dir
            $dirPath = "${BasePath}/dir-$i"

            New-Folder `
                -Context $Context `
                -ShareName $FileShareName `
                -Path $dirPath `
                -WhatIf:$WhatIfPreference `
                -Verbose:$VerbosePreference `
                -ErrorAction SilentlyContinue

            if ($PassThru) {
                Write-Output "$dirPath"
            }

            # Recurse inside dir
            New-ArborescenceInner `
                -Context $Context `
                -FileShareName $FileShareName `
                -BasePath $dirPath `
                -NumberDirs $NumberDirs `
                -NumberFilesPerDir $NumberFilesPerDir `
                -Depth ($Depth - 1) `
                -PassThru:$PassThru `
                -WhatIf:$WhatIfPreference
        }
    }
}

function New-Arborescence
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$context,
        [string]$FileShareName,
        [string]$BasePath,
        [int]$NumberDirs,
        [int]$NumberFilesPerDir,
        [int]$Depth,
        [switch]$PassThru
    )
    $d = $NumberDirs
    $f = $NumberFilesPerDir
    $delta = $Depth

    $files = $f * [Math]::Pow($d, $delta)
    $directories = ($d * ([Math]::Pow($d, $delta) - 1)) / ($d - 1)
    $total = $files + $directories

    if ($WhatIfPreference) {
        $ProgressPreference = "SilentlyContinue"
    }

    $i = 0

    New-ArborescenceInner `
        -Context $Context `
        -FileShareName $FileShareName `
        -BasePath $BasePath `
        -NumberDirs $NumberDirs `
        -NumberFilesPerDir $NumberFilesPerDir `
        -Depth $Depth `
        -WhatIf:$WhatIfPreference `
        -Verbose:$VerbosePreference `
        -PassThru
    | ForEach-Object {
        $i++
        Write-Progress `
            -Activity "Creating arborescence" `
            -Status "Creating $_" `
            -PercentComplete (($i / $total) * 100)
        
        if ($PassThru) {
            Write-Output $_
        }
    }
    Write-Verbose "Created $i items out of an expected $total items"
}
