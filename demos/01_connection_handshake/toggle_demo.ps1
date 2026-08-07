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
    
    Write-Host "Aguardando Server inicializar e gerar DTLS certs..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" -- --client" -WorkingDirectory $demoPath
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoPath`" -- --client" -WorkingDirectory $demoPath
}
