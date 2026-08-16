param (
    [Alias("m", "map", "c", "chunk", "chunks")]
    [Parameter(Position=0, Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$maps = @(),

    [Parameter(Mandatory=$false)]
    [switch]$all,

    [Parameter(Mandatory=$false)]
    [string]$l2Root = "C:\Users\LEONARDO\Documents\Lineage II",

    [Parameter(Mandatory=$false)]
    [string]$outputDir = "",

    [Parameter(Mandatory=$false)]
    [int]$step = 1,

    [Parameter(Mandatory=$false)]
    [switch]$noSplat
)

$ErrorActionPreference = "Continue"

# 1. Configuracao de Caminhos
$ScriptRoot = $PSScriptRoot
$PythonScript = Join-Path $ScriptRoot "tools\l2_build_chunk.py"

if (-not (Test-Path $PythonScript)) {
    Write-Host "[ERRO] Compilador Python nao encontrado em: $PythonScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $l2Root)) {
    Write-Host "[ERRO] Diretorio raiz do Lineage II nao encontrado em: $l2Root" -ForegroundColor Red
    exit 1
}

$MapsDir = Join-Path $l2Root "maps"
if (-not (Test-Path $MapsDir)) {
    Write-Host "[ERRO] Pasta 'maps' nao encontrada no Lineage II: $MapsDir" -ForegroundColor Red
    exit 1
}

if ($outputDir -eq "") {
    $TargetOutputDir = Join-Path $ScriptRoot "assets\maps"
} else {
    $TargetOutputDir = $outputDir
}

if (-not (Test-Path $TargetOutputDir)) {
    New-Item -ItemType Directory -Path $TargetOutputDir -Force | Out-Null
}

# 2. Resolucao da Lista de Mapas Alvo
$TargetMaps = @()

if ($maps.Count -gt 0) {
    foreach ($m in $maps) {
        if ($m -ne "" -and -not $m.StartsWith("-")) {
            # Se for uma string separada por virgula ou espaco
            $splitItems = $m -split "[, ]+"
            foreach ($sub in $splitItems) {
                $trimmed = $sub.Trim()
                if ($trimmed -ne "" -and -not $trimmed.StartsWith("-")) {
                    $TargetMaps += $trimmed
                }
            }
        }
    }
}

if ($all) {
    Write-Host "[*] Escaneando todos os arquivos .unr em $MapsDir..." -ForegroundColor Cyan
    $unrFiles = Get-ChildItem -Path $MapsDir -Filter "*.unr" | Select-Object -ExpandProperty BaseName
    $TargetMaps += $unrFiles
}

# Remove duplicatas
$TargetMaps = $TargetMaps | Select-Object -Unique

if ($TargetMaps.Count -eq 0) {
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host " [!] NENHUM MAPA ESPECIFICADO PARA COMPILACAO" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host " Uso:" -ForegroundColor White
    Write-Host "   .\build_maps.ps1 -maps 16_24" -ForegroundColor Gray
    Write-Host "   .\build_maps.ps1 -maps 16_25, 17_24, 17_25" -ForegroundColor Gray
    Write-Host "   .\build_maps.ps1 16_25 17_24 17_25" -ForegroundColor Gray
    Write-Host "   .\build_maps.ps1 -all" -ForegroundColor Gray
    Write-Host "================================================================================" -ForegroundColor Yellow
    exit 0
}

# 3. Painel de Execucao em Lote
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Magenta
Write-Host " [*] GODOTAGE II - ORQUESTRADOR DE BUILD DE CHUNKS" -ForegroundColor Magenta
Write-Host " [*] Total de Mapas a Processar : $($TargetMaps.Count)" -ForegroundColor Magenta
Write-Host " [*] Destino dos Artefatos       : $TargetOutputDir" -ForegroundColor Magenta
Write-Host "================================================================================" -ForegroundColor Magenta
Write-Host ""

$SuccessCount = 0
$ErrorCount = 0
$TotalTimer = [System.Diagnostics.Stopwatch]::StartNew()

# 4. Compilacao Unificada em Lote (2-Pass Seamless Alignment)
$unrFiles = @()
foreach ($mapItem in $TargetMaps) {
    $cleanName = [System.IO.Path]::GetFileNameWithoutExtension($mapItem)
    $unrFile = Join-Path $MapsDir "$cleanName.unr"
    if (Test-Path $unrFile) {
        $unrFiles += $unrFile
    } else {
        Write-Host "    [X] Arquivo .unr nao encontrado: $unrFile" -ForegroundColor Red
        $ErrorCount++
    }
}

if ($unrFiles.Count -gt 0) {
    $cmdArgs = @($unrFiles) + @("--output-dir", "$TargetOutputDir", "--l2-root", "$l2Root", "--step", "$step")
    if ($noSplat) {
        $cmdArgs += "--no-splat"
    }

    python $PythonScript @cmdArgs
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        $SuccessCount = $unrFiles.Count
    } else {
        $ErrorCount += $unrFiles.Count
    }
}

$TotalTimer.Stop()
$totalSecs = [math]::Round($TotalTimer.Elapsed.TotalSeconds, 2)

# 5. Relatorio Final de Compilacao
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host " [*] RESUMO DO PROCESSO DE BUILD" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host " -> Total de Chunks : $($TargetMaps.Count)" -ForegroundColor White
Write-Host " -> Sucessos        : $SuccessCount" -ForegroundColor Green
Write-Host " -> Falhas          : $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { "Red" } else { "Gray" })
Write-Host " -> Tempo Total     : ${totalSecs}s" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
