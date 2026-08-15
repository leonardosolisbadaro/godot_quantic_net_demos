param (
    [Alias("m", "map")]
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
        if ($m -ne "") {
            # Se for uma string separada por virgula ou espaco
            $splitItems = $m -split "[, ]+"
            foreach ($sub in $splitItems) {
                if ($sub.Trim() -ne "") {
                    $TargetMaps += $sub.Trim()
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

# 4. Loop de Compilacao
$CurrentIndex = 0
foreach ($mapItem in $TargetMaps) {
    $CurrentIndex++
    $cleanName = [System.IO.Path]::GetFileNameWithoutExtension($mapItem)
    $unrFile = Join-Path $MapsDir "$cleanName.unr"

    Write-Host "[$CurrentIndex/$($TargetMaps.Count)] Processando Chunk: '$cleanName'..." -ForegroundColor Cyan

    if (-not (Test-Path $unrFile)) {
        Write-Host "    [X] Arquivo .unr nao encontrado: $unrFile" -ForegroundColor Red
        $ErrorCount++
        continue
    }

    $chunkTimer = [System.Diagnostics.Stopwatch]::StartNew()
    
    if ($noSplat) {
        python $PythonScript "$unrFile" --output-dir "$TargetOutputDir" --l2-root "$l2Root" --step $step --no-splat
    } else {
        python $PythonScript "$unrFile" --output-dir "$TargetOutputDir" --l2-root "$l2Root" --step $step
    }
    
    $exitCode = $LASTEXITCODE
    $chunkTimer.Stop()
    $chunkSecs = [math]::Round($chunkTimer.Elapsed.TotalSeconds, 2)

    if ($exitCode -eq 0) {
        $SuccessCount++
        Write-Host "    [OK] Chunk '$cleanName' compilado com sucesso em ${chunkSecs}s" -ForegroundColor Green
    } else {
        $ErrorCount++
        Write-Host "    [ERRO] Falha ao compilar o chunk '$cleanName' (Exit Code: $exitCode)" -ForegroundColor Red
    }
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
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
