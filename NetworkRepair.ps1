# NetworkRepair.ps1
# Automated network troubleshooting script for common connectivity issues
# Author: IT Support Team
# Version: 1.0

param(
    [switch]$Verbose,
    [string]$LogPath = ".\logs\network_repair.log"
)

# Create logs directory if it doesn't exist
$LogDir = Split-Path $LogPath -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Function to write logs and display messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        default { Write-Host $LogMessage -ForegroundColor White }
    }
    
    # Write to log file
    Add-Content -Path $LogPath -Value $LogMessage
}

# Function to test network connectivity
function Test-NetworkConnectivity {
    $TestSites = @("8.8.8.8", "google.com", "microsoft.com")
    $SuccessCount = 0
    
    Write-Log "Testing network connectivity..."
    
    foreach ($Site in $TestSites) {
        try {
            $Result = Test-Connection -ComputerName $Site -Count 1 -Quiet
            if ($Result) {
                Write-Log "✅ Successfully pinged $Site" "SUCCESS"
                $SuccessCount++
            } else {
                Write-Log "❌ Failed to ping $Site" "WARNING"
            }
        }
        catch {
            Write-Log "❌ Error pinging $Site`: $($_.Exception.Message)" "ERROR"
        }
    }
    
    return $SuccessCount -gt 0
}

# Function to get current IP configuration
function Get-CurrentIPConfig {
    Write-Log "Current IP Configuration:"
    $IPConfig = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}
    
    foreach ($IP in $IPConfig) {
        Write-Log "Interface: $($IP.InterfaceAlias) - IP: $($IP.IPAddress)"
    }
    return $IPConfig
}

# Main script execution
try {
    Write-Log "=== Network Repair Script Started ===" "INFO"
    Write-Log "Computer: $env:COMPUTERNAME, User: $env:USERNAME"
    
    # Step 1: Get initial network state
    Write-Log "`n--- STEP 1: Initial Network Assessment ---"
    $InitialConnectivity = Test-NetworkConnectivity
    Get-CurrentIPConfig
    
    if ($InitialConnectivity) {
        Write-Log "Network appears to be working. Running diagnostics only..." "SUCCESS"
    } else {
        Write-Log "Network issues detected. Beginning repair process..." "WARNING"
        
        # Step 2: Flush DNS Cache
        Write-Log "`n--- STEP 2: Flushing DNS Cache ---"
        try {
            Clear-DnsClientCache
            Write-Log "✅ DNS cache flushed successfully" "SUCCESS"
        }
        catch {
            Write-Log "❌ Failed to flush DNS cache: $($_.Exception.Message)" "ERROR"
        }
        
        # Step 3: Reset TCP/IP Stack
        Write-Log "`n--- STEP 3: Resetting TCP/IP Stack ---"
        try {
            # Reset Winsock catalog
            & netsh winsock reset | Out-Null
            Write-Log "✅ Winsock catalog reset" "SUCCESS"
            
            # Reset TCP/IP stack
            & netsh int ip reset | Out-Null
            Write-Log "✅ TCP/IP stack reset" "SUCCESS"
        }
        catch {
            Write-Log "❌ Failed to reset TCP/IP: $($_.Exception.Message)" "ERROR"
        }
        
        # Step 4: Renew IP Address
        Write-Log "`n--- STEP 4: Renewing IP Address ---"
        try {
            # Release current IP
            & ipconfig /release | Out-Null
            Write-Log "✅ IP address released" "SUCCESS"
            
            # Renew IP address
            & ipconfig /renew | Out-Null
            Write-Log "✅ IP address renewed" "SUCCESS"
        }
        catch {
            Write-Log "❌ Failed to renew IP: $($_.Exception.Message)" "ERROR"
        }
        
        # Step 5: Test connectivity again
        Write-Log "`n--- STEP 5: Testing Connectivity After Repair ---"
        Start-Sleep -Seconds 3  # Wait for network to stabilize
        
        $FinalConnectivity = Test-NetworkConnectivity
        Get-CurrentIPConfig
        
        if ($FinalConnectivity) {
            Write-Log "`n🎉 Network repair completed successfully!" "SUCCESS"
            Write-Log "The user should now be able to access the internet." "SUCCESS"
        } else {
            Write-Log "`n⚠️  Network issues persist after repair attempt." "WARNING"
            Write-Log "Recommended next steps:" "WARNING"
            Write-Log "1. Check physical network connections" "WARNING"
            Write-Log "2. Verify network adapter drivers" "WARNING"
            Write-Log "3. Contact network administrator" "WARNING"
        }
    }
    
    # Generate summary report
    Write-Log "`n--- REPAIR SUMMARY ---"
    Write-Log "Script execution completed at $(Get-Date)"
    Write-Log "Log file saved to: $LogPath"
    
    if (!$InitialConnectivity -and $FinalConnectivity) {
        Write-Log "STATUS: Network successfully repaired ✅" "SUCCESS"
    } elseif ($InitialConnectivity) {
        Write-Log "STATUS: No repair needed - network was working ℹ️" "INFO"
    } else {
        Write-Log "STATUS: Repair attempted but issues remain ⚠️" "WARNING"
    }
}
catch {
    Write-Log "Critical error in script execution: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "=== Network Repair Script Completed ===" "INFO"

# Prompt to restart if TCP/IP was reset (optional)
if (!$InitialConnectivity) {
    $Restart = Read-Host "`nA system restart is recommended for TCP/IP changes to take full effect. Restart now? (y/N)"
    if ($Restart -eq 'y' -or $Restart -eq 'Y') {
        Write-Log "System restart initiated by user" "INFO"
        Restart-Computer -Force
    }
}