# setup_demos.ps1
$ErrorActionPreference = "SilentlyContinue"

$RootPath = $PSScriptRoot
$RootAddonPath = Join-Path $RootPath "addons\quantic_net\addons\quantic_net"
$DemosPath = Join-Path $RootPath "demos"
$DemoFooPath = Join-Path $DemosPath "demo_foo"

# Helper para escrever UTF-8 sem BOM (crucial para o Godot)
function Write-Utf8NoBom {
    param([string]$FilePath, [string]$FileContent)
    [System.IO.File]::WriteAllText($FilePath, $FileContent, (New-Object System.Text.UTF8Encoding $False))
}

# 1. Garante que a pasta demos/ existe
if (-not (Test-Path $DemosPath)) {
    New-Item -ItemType Directory -Path $DemosPath | Out-Null
}

# 2. Se não existir, cria a demo genérica (que será renomeada pelo usuário)
if (-not (Test-Path $DemoFooPath)) {
    Write-Host "Criando nova demo base em 'demo_foo'..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $DemoFooPath | Out-Null

    # --- ARQUIVO: project.godot ---
    $projectGodot = @'
; Engine configuration file.
config_version=5

[application]
config/name="Nova Demo"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")

[autoload]
QuanticNet="*res://addons/quantic_net/src/infrastructure/quantic_net_autoload.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/quantic_net/plugin.cfg")
'@
    Write-Utf8NoBom (Join-Path $DemoFooPath "project.godot") $projectGodot

    # --- ARQUIVO: main.tscn ---
    $mainTscn = @'
[gd_scene load_steps=2 format=3 uid="uid://b410e8s210e31"]

[ext_resource type="Script" path="res://main.gd" id="1_main"]

[node name="Main" type="Node"]
script = ExtResource("1_main")
'@
    Write-Utf8NoBom (Join-Path $DemoFooPath "main.tscn") $mainTscn

    # --- ARQUIVO: main.gd ---
    $mainGd = @'
extends Node

func _ready() -> void:
	print(">>> Nova Demo Iniciada <<<")
	var qn = get_node_or_null("/root/QuanticNet")
	if not qn:
		print("ERRO: Autoload QuanticNet nao encontrado.")
		return
		
	var args = OS.get_cmdline_args()
	if "--server" in args:
		qn.host(8080, "secret")
		print("Servidor escutando...")
	elif "--client" in args:
		qn.join("127.0.0.1", 8080, "secret")
		print("Cliente conectando...")
'@
    Write-Utf8NoBom (Join-Path $DemoFooPath "main.gd") $mainGd

    # --- ARQUIVO: toggle_demo.ps1 ---
    $toggleDemo = @'
$ErrorActionPreference = "SilentlyContinue"
$godotExe = "C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$demoPath = $PSScriptRoot

$demoName = Split-Path $demoPath -Leaf
$runningInstances = Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v4.7.1-stable_win64%'" | Where-Object { 
    $_.CommandLine -match $demoName -and 
    ($_.CommandLine -match "--client" -or $_.CommandLine -match "--server")
}

if ($runningInstances) {
    Write-Host "Encerrando instancias..." -ForegroundColor Yellow
    foreach ($proc in $runningInstances) { Stop-Process -Id $proc.ProcessId -Force }
} else {
    Write-Host "Iniciando Demo (1 Server, 2 Clients)..." -ForegroundColor Cyan
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" -- --server" -WorkingDirectory $demoPath
    
    Write-Host "Aguardando Server inicializar (Race Condition protection)..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" -- --client" -WorkingDirectory $demoPath
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" -- --client" -WorkingDirectory $demoPath
}
'@
    Write-Utf8NoBom (Join-Path $DemoFooPath "toggle_demo.ps1") $toggleDemo

    # --- ARQUIVO: CHANGELOG.md ---
    $changelog = @'
# Changelog

Todas as mudancas notaveis para esta demo serao documentadas neste arquivo.

## [Unreleased]
- Criacao base da demo.
'@
    Write-Utf8NoBom (Join-Path $DemoFooPath "CHANGELOG.md") $changelog

    # --- ARQUIVO: TODO.md ---
    $todo = @'
# TODO

Roadmap e tarefas especificas para esta implementacao.

## Fase 1
- [ ] Tarefa inicial
'@
    Write-Utf8NoBom (Join-Path $DemoFooPath "TODO.md") $todo

    Write-Host "Arquivos base copiados com sucesso." -ForegroundColor Green
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
        cmd /c rmdir "$DemoPluginLink" | Out-Null
    }
    Write-Host "Linkando QuanticNet para a demo: $($_.Name)" -ForegroundColor Green
    cmd /c mklink /J "$DemoPluginLink" "$RootAddonPath" | Out-Null
    
    # 4. Força o Godot a gerar o cache nativo e registrar a GDExtension
    $godotExe = "C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
    $godotCache = Join-Path $DemoPath ".godot\extension_list.cfg"
    if (-not (Test-Path $godotCache)) {
        Write-Host "Construindo Cache/GDExtension para a demo: $($_.Name)..." -ForegroundColor Magenta
        Start-Process -FilePath $godotExe -ArgumentList "--path `"$DemoPath`" --headless --editor --quit" -Wait -NoNewWindow
    }
}
