# backup.ps1 - Automated Git Backup for Flutter Project

Write-Host "Starting Flutter project backup..." -ForegroundColor Cyan

# Check if we are in a git repository
if (-not (Test-Path ".git")) {
    Write-Host "Error: Not a Git repository. Please run this script inside your project folder." -ForegroundColor Red
    pause
    exit
}

# 1. Add all changes
Write-Host "Adding files to Git..." -ForegroundColor Yellow
git add .

# 2. Commit with a timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$message = "Automated backup on $timestamp"
Write-Host "Committing changes: $message" -ForegroundColor Yellow
git commit -m $message

# 3. Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push origin master

# 4. Success message
Write-Host "Backup completed successfully!" -ForegroundColor Green
pause