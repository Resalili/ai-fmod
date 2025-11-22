Param(
    [string]$m,
    [switch]$p,
    [switch]$g,
    [switch]$h
)

$MODS_DIR = "mods"
$DIST_DIR = "dist"
$IGNORE = @(".git", ".gitkeep", ".DS_Store", "Thumbs.db")

function Show-Help {
    Write-Host "Usage: build.ps1 [-m MOD] [-p] [-g] [-h]"
    Write-Host ""
    Write-Host "  -m <MOD>   Build only specific mod"
    Write-Host "  -p         Increase PATCH version"
    Write-Host "  -g         Use version from git tag"
    Write-Host "  -h         Show help"
    exit 0
}

if ($h) { Show-Help }

if (!(Test-Path $DIST_DIR)) { New-Item -ItemType Directory $DIST_DIR | Out-Null }

function Get-GitVersion {
    $tag = git describe --tags --abbrev=0 2>$null
    if (!$tag) { return "" }
    return $tag.TrimStart("v")
}

function Inc-Patch($v) {
    $parts = $v.Split(".")
    $parts[2] = [int]$parts[2] + 1
    return "$($parts[0]).$($parts[1]).$($parts[2])"
}

function Build-Mod($dir) {
    $infoPath = Join-Path $dir "info.json"
    $json = Get-Content $infoPath | ConvertFrom-Json

    $name = $json.name
    $version = $json.version

    if ($g) {
        $tag = Get-GitVersion
        if (!$tag) { Write-Host "ERROR: No git tags found!" -ForegroundColor Red; exit 1 }
        $version = $tag
    } elseif ($p) {
        $version = Inc-Patch $version
        $json.version = $version
        $json | ConvertTo-Json -Depth 5 | Set-Content $infoPath
    }

    $zip = Join-Path $DIST_DIR "${name}_${version}.zip"
    Write-Host "Building $name ($version) -> $zip"

    if (Test-Path $zip) { Remove-Item $zip -Force }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zipStream = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
    Get-ChildItem $dir -Recurse | Where-Object {
        $_.PSIsContainer -eq $false -and ($IGNORE -notcontains $_.Name)
    } | ForEach-Object {
        $entry = $_.FullName.Substring($dir.Length + 1)
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipStream, $_.FullName, $entry) | Out-Null
    }
    $zipStream.Dispose()
}

# select mods
if ($m) {
    Get-ChildItem $MODS_DIR | Where-Object {
        Test-Path "$($_.FullName)\info.json"
    } | ForEach-Object {
        $info = Get-Content "$($_.FullName)\info.json" | ConvertFrom-Json
        if ($info.name -eq $m) { Build-Mod $_.FullName }
    }
}
else {
    Get-ChildItem $MODS_DIR | Where-Object {
        Test-Path "$($_.FullName)\info.json"
    } | ForEach-Object {
        Build-Mod $_.FullName
    }
}
