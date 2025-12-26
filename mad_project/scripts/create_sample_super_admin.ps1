Param(
    [string]$uid
)

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Error "firebase CLI not found. Install it: npm install -g firebase-tools"
    exit 1
}

if (-not $uid) {
    $uid = Read-Host "Enter UID for super admin to create"
}

if (-not $uid) { Write-Error "UID required"; exit 1 }

Write-Host "This script writes a document to /super_admins/$uid using the Firebase CLI firestore:write helper via REST."
Write-Host "You must be authenticated with 'firebase login' and have the active project set."

# Use the firestore REST API via firebase CLI's access token
$token = (firebase login:ci --no-localhost) 2>$null
if (-not $token) {
    Write-Host "Please create a CI token with: firebase login:ci and paste it here." 
    exit 1
}

Write-Host "Creating super_admins/$uid doc..."
# Using curl to call Firestore REST — user responsible for PROJECT_ID env or configured firebase project
$project = (firebase projects:list --json | ConvertFrom-Json).result[0].projectId
if (-not $project) { Write-Error "Could not determine projectId. Run 'firebase use' or pass project via CLI."; exit 1 }

$url = "https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/super_admins/$uid"

$body = @{
    fields = @{
        uid = @{ stringValue = $uid }
        createdAt = @{ timestampValue = (Get-Date -Format o) }
    }
} | ConvertTo-Json -Depth 6

Write-Host "Calling Firestore REST API to create document (requires valid token)."
curl -X PATCH -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d $body $url

Write-Host "If the call succeeded, you have a super-admin document created."
