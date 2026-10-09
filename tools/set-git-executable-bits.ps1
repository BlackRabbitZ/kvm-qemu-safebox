# Run locally from a Git clone on Windows to commit correct Unix executable modes.
# GitHub's web uploader does not preserve Unix +x metadata from ZIP archives.
$ErrorActionPreference = 'Stop'
$root = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $root) { throw 'Bitte in einem Git-Checkout ausführen.' }
Push-Location $root
try {
    $patterns = @('safebox','install/*.sh','host/*.sh','network/*.sh','guest/*.sh','tools/*.sh','tools/*.py','tests/*.sh')
    $files = @(& git ls-files --cached -- $patterns | Sort-Object -Unique)
    if ($LASTEXITCODE -ne 0 -or $files.Count -lt 2) { throw 'Dateien im Git-Index nicht gefunden.' }
    foreach ($file in $files) {
        & git update-index --chmod=+x -- $file
        if ($LASTEXITCODE -ne 0) { throw "Git konnte Ausführungsrecht nicht setzen: $file" }
    }
    Write-Host "Git-Ausführungsrechte für $($files.Count) Skripte gesetzt."
    & git diff --cached --summary
    if ($LASTEXITCODE -ne 0) { throw 'Git-Index-Prüfung fehlgeschlagen.' }
    Write-Host 'Als Nächstes: git commit -m "Fix executable file modes"; git push'
} finally {
    Pop-Location
}
