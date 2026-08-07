param (
    [string]$ActiveFile
)

$currentDir = Split-Path $ActiveFile -Parent
$demoRoot = $null

# Varre a árvore de diretórios para cima buscando o project.godot
while ($currentDir -ne $null -and $currentDir -ne "") {
    if (Test-Path (Join-Path $currentDir "project.godot")) {
        $demoRoot = $currentDir
        break
    }
    $currentDir = Split-Path $currentDir -Parent
}

if ($demoRoot) {
    $toggleScript = Join-Path $demoRoot "toggle_demo.ps1"
    if (Test-Path $toggleScript) {
        Write-Host "Contexto Ativo Encontrado: $demoRoot" -ForegroundColor Magenta
        Write-Host "Executando toggle_demo.ps1..." -ForegroundColor Cyan
        & $toggleScript
    } else {
        Write-Host "Arquivo toggle_demo.ps1 não encontrado na raiz desta demo ($demoRoot)." -ForegroundColor Red
    }
} else {
    Write-Host "Nenhum projeto Godot (project.godot) encontrado no caminho: $ActiveFile" -ForegroundColor Yellow
}
