#Requires -Version 5.0
 
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host " Dang yeu cau quyen Administrator, vui long bam 'Yes'..."
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}
 
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Lotus Fortress - Windows Installer"
 
Clear-Host
Write-Host ""
Write-Host " ================================================================"
Write-Host "   Lotus Fortress - Windows Installer"
Write-Host "   (c) FredCentre Software"
Write-Host " ================================================================"
Write-Host ""

$MOD_DIR = Split-Path -Parent $PSCommandPath

$requiredFiles = @(
    "tf\resource\tf_english.txt",
    "hl2\resource\chat_english.txt",
    "hl2\resource\gameui_english.txt"
)
 
$missingFiles = $false
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $MOD_DIR $file
    if (-not (Test-Path $fullPath)) {
        Write-Host " [LOI] Thieu file: $file"
        $missingFiles = $true
    }
}
 
if ($missingFiles) {
    Write-Host ""
    Write-Host " [LOI] Mot so file mod bi thieu. Hay kiem tra lai thu muc."
    Write-Host " Script phai nam cung cap voi cac thu muc tf\ va hl2\."
    Write-Host ""
    pause
    exit 1
}
 
Write-Host " [OK] Da xac nhan day du file mod."
Write-Host ""

$TF2_PATH = $null
 
Write-Host " Dang tim kiem TF2 tren may tinh..."
Write-Host ""

$steamPath = $null
$regPaths = @(
    "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
    "HKLM:\SOFTWARE\Valve\Steam"
)
foreach ($reg in $regPaths) {
    try {
        $val = Get-ItemPropertyValue -Path $reg -Name "InstallPath" -ErrorAction Stop
        if (Test-Path $val) { $steamPath = $val; break }
    } catch {}
}

if ($steamPath) {
    $candidate = Join-Path $steamPath "steamapps\common\Team Fortress 2"
    if (Test-Path (Join-Path $candidate "tf_win64.exe")) {
        $TF2_PATH = $candidate
    }
}

if (-not $TF2_PATH -and $steamPath) {
    $vdfPath = Join-Path $steamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $vdfPath) {
        $vdfContent = Get-Content $vdfPath -Raw -ErrorAction SilentlyContinue
        $libMatches = [regex]::Matches($vdfContent, '"path"\s+"([^"]+)"')
        foreach ($m in $libMatches) {
            $libPath = $m.Groups[1].Value -replace '\\\\', '\'
            $candidate = Join-Path $libPath "steamapps\common\Team Fortress 2"
            if (Test-Path (Join-Path $candidate "tf_win64.exe")) {
                $TF2_PATH = $candidate
                break
            }
        }
    }
}

if ($TF2_PATH) {
    Write-Host " [TIM THAY] TF2 duoc cai dat tai:"
    Write-Host ""
    Write-Host "   $TF2_PATH"
    Write-Host ""
    $confirm = Read-Host "  Duong dan nay co chinh xac khong? (Y/N)"
    if ($confirm -notmatch "^[Yy]$") { $TF2_PATH = $null }
}

if (-not $TF2_PATH) {
    Write-Host ""
    Write-Host " Vui long nhap thu cong duong dan cai dat TF2:"
    Write-Host " (Vi du: C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2)"
    Write-Host ""
    $input = Read-Host "  Duong dan"
    $input = $input.Trim('"')
 
    if (-not (Test-Path (Join-Path $input "tf_win64.exe"))) {
        Write-Host ""
        Write-Host " [LOI] Khong tim thay TF2 tai duong dan vua nhap."
        Write-Host " Hay kiem tra lai (phai chua file tf_win64.exe)."
        Write-Host ""
        pause
        exit 1
    }
    $TF2_PATH = $input
    Write-Host ""
    Write-Host " [OK] Da xac nhan TF2 tai: $TF2_PATH"
}

Write-Host ""
Write-Host " ================================================================"
Write-Host "   CHUAN BI CAI DAT"
Write-Host "   Nguon : $MOD_DIR"
Write-Host "   Dich  : $TF2_PATH"
Write-Host " ================================================================"
Write-Host ""
$start = Read-Host "  Tiep tuc cai dat? (Y/N)"
if ($start -notmatch "^[Yy]$") {
    Write-Host ""
    Write-Host " Da huy cai dat."
    pause
    exit 0
}

Write-Host ""
Write-Host " Dang tao ban sao luu file goc..."
 
$BACKUP_DIR = Join-Path $TF2_PATH "Lotus_Backup"
 
function Backup-File($src, $dst) {
    $dstDir = Split-Path $dst -Parent
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force -ErrorAction SilentlyContinue
        if ($?) { Write-Host " [BACKUP] $(Split-Path $src -Leaf)" }
        else     { Write-Host " [WARN]   Khong the tao backup: $(Split-Path $src -Leaf)" }
    } else {
        Write-Host " [SKIP]   File goc khong ton tai: $(Split-Path $src -Leaf) (se tao moi)"
    }
}
 
Backup-File (Join-Path $TF2_PATH "tf\resource\tf_english.txt")     (Join-Path $BACKUP_DIR "tf\resource\tf_english.txt")
Backup-File (Join-Path $TF2_PATH "hl2\resource\chat_english.txt")   (Join-Path $BACKUP_DIR "hl2\resource\chat_english.txt")
Backup-File (Join-Path $TF2_PATH "hl2\resource\gameui_english.txt") (Join-Path $BACKUP_DIR "hl2\resource\gameui_english.txt")

Write-Host ""
Write-Host " Dang cai dat file ban dich..."
Write-Host ""
 
$installError = $false
 
function Install-File($src, $dst, $label) {
    $dstDir = Split-Path $dst -Parent
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item -Path $src -Destination $dst -Force -ErrorAction SilentlyContinue
    if ($?) { Write-Host " [OK]     Da cai dat: $label" }
    else {
        Write-Host " [LOI]    Khong the ghi: $label"
        $script:installError = $true
    }
}
 
Install-File (Join-Path $MOD_DIR "tf\resource\tf_english.txt")     (Join-Path $TF2_PATH "tf\resource\tf_english.txt")     "tf/resource/tf_english.txt"
Install-File (Join-Path $MOD_DIR "hl2\resource\chat_english.txt")   (Join-Path $TF2_PATH "hl2\resource\chat_english.txt")   "hl2/resource/chat_english.txt"
Install-File (Join-Path $MOD_DIR "hl2\resource\gameui_english.txt") (Join-Path $TF2_PATH "hl2\resource\gameui_english.txt") "hl2/resource/gameui_english.txt"

Write-Host ""
if (-not $installError) {
    Write-Host " ================================================================"
    Write-Host "   CAI DAT THANH CONG!"
    Write-Host ""
    Write-Host "   Ban sao luu file goc da duoc luu tai:"
    Write-Host "   $BACKUP_DIR"
    Write-Host ""
    Write-Host "   Vui long khoi dong lai TF2 de ap dung thay doi."
    Write-Host "   Cam on ban da su dung Lotus Fortress."
    Write-Host " ================================================================"
} else {
    Write-Host " ================================================================"
    Write-Host "   CAI DAT CO LOI! Mot so file co the chua duoc thay the."
    Write-Host "   Hay chay lai script voi quyen Administrator."
    Write-Host " ================================================================"
}
 
Write-Host ""
pause
exit ([int]$installError)