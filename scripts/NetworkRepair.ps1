# NetworkRepair.ps1 - Improved Version
param(
    [switch]$RestartAdapter,
    [string]$AdapterName = "Wi-Fi",
    [switch]$Yes,
    [switch]$RunAsAdmin
)

Write-Host "Starting Network Repair..." -ForegroundColor Cyan

# Check if admin elevation is needed
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Warning: Some operations require Administrator privileges" -ForegroundColor Yellow
    Write-Host "Run with -RunAsAdmin parameter for full functionality" -ForegroundColor Yellow
}

# 1. Reset TCP/IP stack (note: may require admin)
Write-Host "Resetting TCP/IP stack..."
netsh int ip reset

# 2. Flush DNS
Write-Host "Flushing DNS..."
ipconfig /flushdns

# 3. Release & renew IP
Write-Host "Releasing IP..."
ipconfig /release
Write-Host "Renewing IP..."
ipconfig /renew

# 4. Restart adapter (optional)
if ($RestartAdapter) {
    if (-not $Yes) {
        $answer = Read-Host "Restart adapter $AdapterName? (y/n)"
        if ($answer -ne "y") { Write-Host "Skipped adapter restart."; exit }
    }
    Write-Host "Restarting adapter $AdapterName..."
    Disable-NetAdapter -Name $AdapterName -Confirm:$false
    Start-Sleep -Seconds 5
    Enable-NetAdapter -Name $AdapterName -Confirm:$false
}

Write-Host "Network Repair Complete." -ForegroundColor Green

# Show new lease information
Write-Host "`nNew IP Lease Information:" -ForegroundColor Cyan
ipconfig /all | Select-String "Lease Obtained"