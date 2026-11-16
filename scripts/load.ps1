param(
    [string]$DistDir = "."
)

$ErrorActionPreference = "Stop"

$parts = Get-ChildItem -Path $DistDir -Filter "*.tar.gz.part.*" | Sort-Object Name
if ($parts.Count -eq 0) {
    Write-Error "No *.tar.gz.part.* files found in $DistDir"
    exit 1
}

$sumsFile = Join-Path $DistDir "SHA256SUMS"
if (Test-Path $sumsFile) {
    Write-Host "[1/3] Verifying SHA256 checksums..."
    Get-Content $sumsFile | ForEach-Object {
        if ($_ -match "^([0-9a-fA-F]+)\s+(.+)$") {
            $expected = $matches[1].ToLower()
            $file = Join-Path $DistDir $matches[2].Trim()
            $actual = (Get-FileHash -Path $file -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expected) {
                throw "Checksum mismatch for $file (expected $expected, got $actual)"
            }
            Write-Host "  OK: $($matches[2].Trim())"
        }
    }
}

$merged = Join-Path $DistDir ($parts[0].Name -replace '\.part\.\d+$', '')
Write-Host "[2/3] Merging $($parts.Count) parts into $merged ..."
$outStream = [System.IO.File]::Create($merged)
try {
    foreach ($part in $parts) {
        $inStream = [System.IO.File]::OpenRead($part.FullName)
        try { $inStream.CopyTo($outStream) } finally { $inStream.Dispose() }
    }
} finally {
    $outStream.Dispose()
}

Write-Host "[3/3] Loading Docker image..."
docker load -i $merged
Remove-Item $merged -Force

Write-Host "Done!"
docker images ollama-qwen3-embedding-0.6b
