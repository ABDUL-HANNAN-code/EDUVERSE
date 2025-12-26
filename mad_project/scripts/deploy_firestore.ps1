Param(
    [string]$projectId
)

Write-Host "== Deploy Firestore rules & indexes helper =="

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Error "firebase CLI not found. Install it: npm install -g firebase-tools"
    exit 1
}

if (-not $projectId) {
    $projectId = Read-Host "Enter Firebase project id (or press Enter to use active project)"
}

if ($projectId -ne "") {
    Write-Host "Setting project to: $projectId"
    firebase use $projectId
}

Write-Host "Logging in (if not already) — a browser window will open."
firebase login

Write-Host "Deploying Firestore rules..."
firebase deploy --only firestore:rules

Write-Host "Deploying Firestore indexes (may take a few minutes)..."
firebase deploy --only firestore:indexes

Write-Host "Done. Monitor the console for any errors."
