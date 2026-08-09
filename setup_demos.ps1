param (
    [Parameter(Mandatory=$false)]
    [string]$n = "",
    [Parameter(Mandatory=$false)]
    [string]$from = ""
)

$ErrorActionPreference = "SilentlyContinue"

# Configure aqui o caminho absoluto para o executável (console) da Godot Engine
$GodotExePath = "C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"

$RootPath = $PSScriptRoot
$RootAddonPath = Join-Path $RootPath "addons\quantic_net\addons\quantic_net"
$DemosPath = Join-Path $RootPath "demos"

# Helper para escrever UTF-8 sem BOM (crucial para o Godot)
function Write-Utf8NoBom {
    param([string]$FilePath, [string]$FileContent)
    [System.IO.File]::WriteAllText($FilePath, $FileContent, (New-Object System.Text.UTF8Encoding $False))
}

# 1. Garante que a pasta demos/ existe
if (-not (Test-Path $DemosPath)) {
    New-Item -ItemType Directory -Path $DemosPath | Out-Null
}

# 2. Se um nome foi passado via CLI, cria a demo base
if ($n -ne "") {
    $NewDemoPath = Join-Path $DemosPath $n
    if (-not (Test-Path $NewDemoPath)) {
        if ($from -ne "") {
            $SourceDemoPath = Join-Path $DemosPath $from
            if (Test-Path $SourceDemoPath) {
                Write-Host "Copiando base da demo '$from' para '$n'..." -ForegroundColor Cyan
                Copy-Item -Path $SourceDemoPath -Destination $NewDemoPath -Recurse
                
                # Limpa arquivos específicos
                $NewTestsPath = Join-Path $NewDemoPath "tests"
                if (Test-Path $NewTestsPath) {
                    Remove-Item -Path "$NewTestsPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                }
                
                $NewGodotCache = Join-Path $NewDemoPath ".godot"
                if (Test-Path $NewGodotCache) {
                    Remove-Item -Path $NewGodotCache -Recurse -Force -ErrorAction SilentlyContinue
                }
                
                # Deslinka o QuanticNet copiado (será recriado no passo 3)
                $CopiedLink = Join-Path $NewDemoPath "addons\quantic_net"
                if (Test-Path $CopiedLink) {
                    cmd /c rmdir "$CopiedLink" | Out-Null
                }
                
                # Atualiza o nome no project.godot
                $CopiedProject = Join-Path $NewDemoPath "project.godot"
                if (Test-Path $CopiedProject) {
                    $projContent = Get-Content $CopiedProject -Raw
                    $projContent = $projContent -replace 'config/name=".*"', "config/name=`"$n`""
                    Write-Utf8NoBom $CopiedProject $projContent
                }
            } else {
                Write-Host "Demo origem '$from' nao encontrada." -ForegroundColor Red
                return
            }
        } else {
            Write-Host "Criando nova demo base em '$n' do zero..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $NewDemoPath | Out-Null
            
            # Scaffold Clean Architecture & TDD
            New-Item -ItemType Directory -Path (Join-Path $NewDemoPath "src\domain") | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $NewDemoPath "src\use_cases") | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $NewDemoPath "src\adapters") | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $NewDemoPath "src\infrastructure") | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $NewDemoPath "tests") | Out-Null

            # --- ARQUIVO: project.godot ---
            $projectGodot = @"
; Engine configuration file.
config_version=5

[application]
config/name="$n"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")

[autoload]
QuanticNet="*res://addons/quantic_net/src/infrastructure/quantic_net_autoload.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/quantic_net/plugin.cfg")
"@
            Write-Utf8NoBom (Join-Path $NewDemoPath "project.godot") $projectGodot

            # --- ARQUIVO: main.tscn ---
            $mainTscn = @'
[gd_scene load_steps=2 format=3 uid="uid://b410e8s210e31"]

[ext_resource type="Script" path="res://main.gd" id="1_main"]

[node name="Main" type="Node3D"]
script = ExtResource("1_main")
'@
            Write-Utf8NoBom (Join-Path $NewDemoPath "main.tscn") $mainTscn

            # --- ARQUIVO: main.gd ---
            $currentDate = Get-Date -Format "yyyy-MM-dd"
            $mainGd = @"
## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada da Demo $n. "...descricao da demo...".
##
## @created $currentDate
## @updated $currentDate
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends Node

func _ready() -> void:
	print(">>> Nova Demo Iniciada <<<")
	var qn = get_node_or_null("/root/QuanticNet")
	if not qn:
		print("ERRO: Autoload QuanticNet nao encontrado.")
		return
		
	var args = OS.get_cmdline_user_args()
	if "--server" in args:
		qn.host(8080, "secret")
		print("Servidor escutando...")
	else:
		qn.join("127.0.0.1", 8080, "secret")
		print("Cliente conectando...")
"@
            Write-Utf8NoBom (Join-Path $NewDemoPath "main.gd") $mainGd

            # --- ARQUIVO: toggle_demo.ps1 ---
            $toggleDemo = @'
$ErrorActionPreference = "SilentlyContinue"
$godotExe = "{{GODOT_EXE}}"
$demoPath = $PSScriptRoot

$demoName = Split-Path $demoPath -Leaf
$godotExeBase = [System.IO.Path]::GetFileNameWithoutExtension($godotExe)
$runningInstances = Get-CimInstance Win32_Process -Filter "Name LIKE '$godotExeBase%'" | Where-Object { 
    $_.CommandLine -match $demoName -and 
    ($_.CommandLine -match "--client" -or $_.CommandLine -match "--server")
}

if ($runningInstances) {
    Write-Host "Encerrando instancias..." -ForegroundColor Yellow
    foreach ($proc in $runningInstances) { Stop-Process -Id $proc.ProcessId -Force }
} else {
    Write-Host "Iniciando Demo (1 Server, 2 Clients)..." -ForegroundColor Cyan
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" --headless -- --server" -WorkingDirectory $demoPath
    
    Write-Host "Aguardando Server inicializar (Race Condition protection)..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" -- --client" -WorkingDirectory $demoPath
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" -- --client --netem" -WorkingDirectory $demoPath
}
'@
            $toggleDemo = $toggleDemo.Replace("{{GODOT_EXE}}", $GodotExePath)
            Write-Utf8NoBom (Join-Path $NewDemoPath "toggle_demo.ps1") $toggleDemo
        }

        # ARQUIVOS COMUNS RECRIADOS PARA AMBAS ABORDAGENS (Clean state)
        
        # --- ARQUIVO: CHANGELOG.md ---
        $changelog = @"
# Changelog

Todas as mudancas notaveis para esta demo serao documentadas neste arquivo.

## [Unreleased]
- Criacao da demo $n.
"@
        Write-Utf8NoBom (Join-Path $NewDemoPath "CHANGELOG.md") $changelog

        # --- ARQUIVO: TODO.md ---
        $todo = @"
# TODO

Roadmap e tarefas especificas para esta implementacao.

## Fase 1
- [ ] Tarefa inicial
"@
        Write-Utf8NoBom (Join-Path $NewDemoPath "TODO.md") $todo

        Write-Host "Arquivos base preparados com sucesso." -ForegroundColor Green
    }
}

# 3. Cria as Junctions e Caches para TODAS as demos contidas em demos/
Get-ChildItem -Path $DemosPath -Directory | ForEach-Object {
    $DemoPath = $_.FullName
    $DemoAddonsDir = Join-Path $DemoPath "addons"
    $DemoPluginLink = Join-Path $DemoAddonsDir "quantic_net"

    if (-not (Test-Path $DemoAddonsDir)) {
        New-Item -ItemType Directory -Path $DemoAddonsDir | Out-Null
    }

    if (Test-Path $DemoPluginLink) {
        Remove-Item -Path $DemoPluginLink -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Linkando QuanticNet para a demo: $($_.Name)" -ForegroundColor Green
    cmd /c mklink /J "$DemoPluginLink" "$RootAddonPath" | Out-Null
    
    # 4. Força o Godot a gerar o cache nativo e registrar a GDExtension
    $godotCache = Join-Path $DemoPath ".godot\extension_list.cfg"
    if (-not (Test-Path $godotCache)) {
        Write-Host "Construindo Cache/GDExtension para a demo: $($_.Name)..." -ForegroundColor Magenta
        
        # Redireciona stdout e stderr para arquivos separados para evitar lock de IO do PowerShell
        $logOut = Join-Path $DemoPath "godot_cache_build.log"
        $logErr = Join-Path $DemoPath "godot_cache_err.log"
        Start-Process -FilePath $GodotExePath -ArgumentList "--path `"$DemoPath`" --headless --editor --quit" -Wait -NoNewWindow -RedirectStandardOutput $logOut -RedirectStandardError $logErr
        
        # Verifica se obteve sucesso na geracao do cache
        if (Test-Path $godotCache) {
            Write-Host "Cache gerado com sucesso para a demo: $($_.Name)" -ForegroundColor Green
            Remove-Item $logOut -Force -ErrorAction SilentlyContinue
            Remove-Item $logErr -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "FALHA ao gerar o cache para a demo: $($_.Name)." -ForegroundColor Red
            Write-Host "Consulte os logs: $logOut e $logErr" -ForegroundColor Red
        }
    }
}
