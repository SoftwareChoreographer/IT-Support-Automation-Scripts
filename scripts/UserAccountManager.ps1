<#
.SYNOPSIS
    Professional user account management utility for IT support.
.DESCRIPTION
    Manages user accounts with comprehensive logging and safety features.
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Create", "Disable", "Enable", "ResetPassword", "Delete", "GetInfo", "ListAll")]
    [string]$Action,
    
    [string]$CsvPath,
    [string]$Username,
    [string]$FirstName,
    [string]$LastName, 
    [string]$Department,
    [string]$Email,
    [string]$Password,
    [switch]$WhatIf,
    [switch]$Force
)

# Setup logging and data storage
$logDir = Join-Path $env:USERPROFILE "user_management_logs"
$dataFile = Join-Path $logDir "user_database.json"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir "user_management_${Action}_$timestamp.log"

Start-Transcript -Path $logFile -Append

Write-Host "User Account Management Utility" -ForegroundColor Cyan
Write-Host "=========================================="

# Load existing user database
function Load-UserDatabase {
    if (Test-Path $dataFile) {
        try {
            return Get-Content $dataFile | ConvertFrom-Json
        }
        catch {
            Write-Log -Message "Warning - Could not load user database: $($_.Exception.Message)" -Color "Yellow"
            return @()
        }
    }
    return @()
}

# Save user database
function Save-UserDatabase {
    param($Database)
    try {
        $Database | ConvertTo-Json | Set-Content $dataFile
    }
    catch {
        Write-Log -Message "Error - Could not save user database: $($_.Exception.Message)" -Color "Red"
    }
}

$userDatabase = Load-UserDatabase
$successCount = 0
$totalCount = 0

function Write-Log {
    param($Message, $Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function New-SecurePassword {
    if (-not $Password) {
        $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
        return ($chars.ToCharArray() | Get-Random -Count 12) -join ''
    }
    return $Password
}

function New-UserAccount {
    param($UserData)
    
    $username = $UserData.Username
    if (-not $username) {
        $username = ($UserData.FirstName.Substring(0,1) + $UserData.LastName).ToLower()
    }
    
    # Check if user already exists
    $existingUser = $userDatabase | Where-Object { $_.Username -eq $username }
    if ($existingUser) {
        Write-Log -Message "Error - User already exists: $username" -Color "Red"
        return $false
    }
    
    $password = New-SecurePassword
    
    if ($WhatIf) {
        Write-Log -Message "WHATIF - Would create user: $username" -Color "Yellow"
        Write-Log -Message "WHATIF - Password: $password" -Color "Yellow"
        Write-Log -Message "WHATIF - Department: $($UserData.Department)" -Color "Yellow"
        return $true
    }
    
    try {
        $userObject = [PSCustomObject]@{
            Username = $username
            FirstName = $UserData.FirstName
            LastName = $UserData.LastName
            Department = $UserData.Department
            Email = if ($UserData.Email) { $UserData.Email } else { "$username@company.com" }
            Password = $password
            Enabled = $true
            Created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $userDatabase += $userObject
        Save-UserDatabase -Database $userDatabase
        
        Write-Log -Message "Created user: $username" -Color "Green"
        Write-Log -Message "Name: $($UserData.FirstName) $($UserData.LastName)" -Color "Green"
        Write-Log -Message "Department: $($UserData.Department)" -Color "Green"
        Write-Log -Message "Email: $($userObject.Email)" -Color "Green"
        Write-Log -Message "Password: $password" -Color "Green"
        
        return $true
    }
    catch {
        Write-Log -Message "Error creating user $username - $($_.Exception.Message)" -Color "Red"
        return $false
    }
}

function Invoke-UserAction {
    param($Username, $Action)
    
    if ($WhatIf) {
        Write-Log -Message "WHATIF - Would perform $Action on user: $Username" -Color "Yellow"
        return $true
    }
    
    try {
        $user = $userDatabase | Where-Object { $_.Username -eq $Username }
        
        if (-not $user) {
            Write-Log -Message "User not found: $Username" -Color "Red"
            return $false
        }
        
        switch ($Action) {
            "Disable" {
                $user.Enabled = $false
                Write-Log -Message "Disabled user: $Username" -Color "Green"
            }
            "Enable" {
                $user.Enabled = $true
                Write-Log -Message "Enabled user: $Username" -Color "Green"
            }
            "ResetPassword" {
                $newPassword = New-SecurePassword
                $user.Password = $newPassword
                Write-Log -Message "Reset password for user: $Username" -Color "Green"
                Write-Log -Message "New password: $newPassword" -Color "Green"
            }
            "Delete" {
                $userDatabase = $userDatabase | Where-Object { $_.Username -ne $Username }
                Write-Log -Message "Deleted user: $Username" -Color "Green"
            }
            "GetInfo" {
                Write-Log -Message "User Information for $Username" -Color "Cyan"
                Write-Log -Message "Name: $($user.FirstName) $($user.LastName)" -Color "White"
                Write-Log -Message "Department: $($user.Department)" -Color "White"
                Write-Log -Message "Email: $($user.Email)" -Color "White"
                Write-Log -Message "Enabled: $($user.Enabled)" -Color "White"
                Write-Log -Message "Created: $($user.Created)" -Color "White"
                Write-Log -Message "Password: $($user.Password)" -Color "White"
            }
        }
        
        # Save changes to database
        if ($Action -ne "GetInfo") {
            Save-UserDatabase -Database $userDatabase
        }
        
        return $true
    }
    catch {
        Write-Log -Message "Error performing $Action on $Username - $($_.Exception.Message)" -Color "Red"
        return $false
    }
}

function Show-AllUsers {
    if ($userDatabase.Count -eq 0) {
        Write-Log -Message "No users found in database" -Color "Yellow"
        return
    }
    
    Write-Log -Message "All Users in Database ($($userDatabase.Count) total)" -Color "Cyan"
    Write-Log -Message "==========================================" -Color "Cyan"
    
    foreach ($user in $userDatabase) {
        $status = if ($user.Enabled) { "Enabled" } else { "Disabled" }
        Write-Log -Message "$($user.Username) - $($user.FirstName) $($user.LastName) - $($user.Department) - $status" -Color "White"
    }
}

# Main execution
try {
    if ($Action -eq "ListAll") {
        Show-AllUsers
        $successCount = 1
        $totalCount = 1
    }
    elseif ($CsvPath) {
        if (-not (Test-Path $CsvPath)) {
            Write-Log -Message "Error - CSV file not found: $CsvPath" -Color "Red"
            exit 1
        }
        
        $users = Import-Csv $CsvPath
        $totalCount = $users.Count
        
        Write-Log -Message "Processing $totalCount users from $CsvPath" -Color "Cyan"
        
        foreach ($user in $users) {
            if ($Action -eq "Create") {
                $result = New-UserAccount $user
            }
            else {
                if (-not $user.Username) {
                    Write-Log -Message "Warning - Missing username in CSV row" -Color "Yellow"
                    continue
                }
                $result = Invoke-UserAction $user.Username $Action
            }
            
            if ($result) { $successCount++ }
        }
    }
    else {
        $totalCount = 1
        
        if ($Action -eq "Create") {
            if (-not $FirstName -or -not $LastName) {
                Write-Log -Message "Error - First name and last name are required for Create action" -Color "Red"
                exit 1
            }
            
            $userData = @{
                FirstName = $FirstName
                LastName = $LastName
                Username = $Username
                Department = $Department
                Email = $Email
            }
            
            $result = New-UserAccount $userData
        }
        else {
            if (-not $Username) {
                Write-Log -Message "Error - Username is required for $Action action" -Color "Red"
                exit 1
            }
            
            $result = Invoke-UserAction $Username $Action
        }
        
        if ($result) { $successCount++ }
    }
}
catch {
    Write-Log -Message "Unexpected error - $($_.Exception.Message)" -Color "Red"
}
finally {
    if ($Action -ne "ListAll") {
        Write-Host "`n==========================================" -ForegroundColor Cyan
        Write-Host "OPERATION SUMMARY" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "Action: $Action" -ForegroundColor White
        Write-Host "Processed: $successCount of $totalCount" -ForegroundColor White
        Write-Host "Log file: $logFile" -ForegroundColor White
        
        if ($WhatIf) {
            Write-Host "`nNOTE: This was a dry run - no changes were made" -ForegroundColor Yellow
        }
    }
    
    Stop-Transcript
}