# Watch phone for new texts (Google Messages); act on those matching local.env filters.
# Usage: powershell -File watch.ps1
# Filters (local.env): TEXT_FILTER_PATTERNS_A -> archive. TEXT_FILTER_PATTERNS_B -> reply STOP, then
#   reply matching TEXT_FILTER_PATTERNS_C within TEXT_STOP_WAIT_SECONDS -> archive, else block + report.
# Saved contacts are exempt. First run records the newest existing message ids; only later texts are handled.
$ErrorActionPreference = "Stop"
$Root  = Resolve-Path "$PSScriptRoot\..\.."
$Out   = Join-Path $Root "temp\texts"
$State = Join-Path $Out "last_ids.txt"
$Log   = Join-Path $Out "log.csv"
$Pkg   = "com.google.android.apps.messaging"
New-Item -ItemType Directory -Force $Out | Out-Null

# Value of key from the environment, else from repo-root local.env (read fresh each time)
function Env($k) {
  if ([Environment]::GetEnvironmentVariable($k)) { return [Environment]::GetEnvironmentVariable($k) }
  $l = Get-Content (Join-Path $Root "local.env") | ? { $_ -match "^\s*$k\s*=" } | select -First 1
  if ($l) { ($l -split "=", 2)[1].Trim() }
}
function Match($k, $text) { $rx = Env $k; $rx -and $text -match "(?i)$rx" }
$Dump  = "$(Env PHONE_TMP_DIR)/u.xml"   # UI dump path on the phone (local.env)

# UI helpers
function Ui { $x = (adb shell "uiautomator dump $Dump >/dev/null; cat $Dump") -join ''; ([xml]$x).SelectNodes("//node") }
function Tap($n) { $b = $n.bounds -replace '[\[\]]', ' ' -split '[ ,]+' | ? { $_ }; adb shell input tap ([int](($b[0] / 1 + $b[2]) / 2)) ([int](($b[1] / 1 + $b[3]) / 2)); Start-Sleep 2 }
function ById($nodes, $id) { $nodes | ? { $_.'resource-id' -eq "${Pkg}:id/$id" } }
function Digits($s) { ($s -replace '\D', '') -replace '^1(\d{10})$', '$1' }
function Locked { (adb shell dumpsys window) -match "mDreamingLockscreen=true|isKeyguardShowing=true" }

# Open the sender's thread (works for archived/spam threads too)
function Thread($addr) { adb shell am start -a android.intent.action.SENDTO -d "smsto:$addr" | Out-Null; Start-Sleep 3 }

# Tap an item in the thread's overflow menu (rightmost top-bar button); $false if missing
function Menu($label) {
  $top = (Ui) | ? { $_.clickable -eq "true" -and $_.bounds -match '^\[\d+,(\d+)\]' -and [int]$Matches[1] -lt 300 -and [int]$Matches[1] -gt 50 }
  Tap ($top | sort { [int]($_.bounds -replace '^\[(\d+),.*', '$1') } | select -Last 1)
  $item = (Ui) | ? { $_.text -eq $label } | select -First 1
  if (-not $item) { adb shell input keyevent BACK; return $false }
  Tap $item; $true
}

function Archive($addr) {
  Thread $addr
  if (Menu "Archive") { "archived" } else { adb shell input keyevent BACK; "already-archived" }
}

function BlockReport($addr) {
  Thread $addr
  if (-not (Menu "Block & report spam")) { adb shell input keyevent BACK; return "already-blocked" }
  $n = Ui
  $chk = $n | ? { $_.checkable -eq "true" } | select -First 1   # "Report spam" checkbox
  if ($chk -and $chk.checked -ne "true") { Tap $chk; $n = Ui }
  $ok = $n | ? { $_.text -match "^(Yes|OK|Block)$" } | select -Last 1
  if (-not $ok) { return "block-dialog-not-found" }
  Tap $ok
  "blocked+reported"
}

function SendStop($addr) {
  adb shell am start -a android.intent.action.SENDTO -d "smsto:$addr" --es sms_body STOP | Out-Null; Start-Sleep 3
  $send = (Ui) | ? { $_.'resource-id' -match 'Send$' } | select -First 1
  if (-not $send) { return $false }
  Tap $send
  $true
}

# New inbox SMS/MMS after id; objects with Kind, Id, Addr, Date(ms), Body
function NewSms($after) {
  $raw = (adb shell "content query --uri content://sms/inbox --projection _id:address:date:body --where '_id>$after'") -join "`n"
  foreach ($m in [regex]::Matches($raw, '(?s)Row: \d+ _id=(\d+), address=(.*?), date=(\d+), body=(.*?)(?=\nRow: \d+ _id=|\z)')) {
    [pscustomobject]@{ Kind = "sms"; Id = [long]$m.Groups[1].Value; Addr = $m.Groups[2].Value; Date = [long]$m.Groups[3].Value; Body = $m.Groups[4].Value.Trim() }
  }
}
function NewMms($after) {
  foreach ($l in adb shell "content query --uri content://mms/inbox --projection _id:date --where '_id>$after'") {
    if ($l -notmatch '_id=(\d+), date=(\d+)') { continue }
    $id = $Matches[1]; $date = [long]$Matches[2] * 1000
    $addr = ((adb shell "content query --uri content://mms/$id/addr --projection type:address") | ? { $_ -match 'type=137' }) -replace '.*address=', ''
    $parts = (adb shell "content query --uri content://mms/part --projection ct:text --where mid=$id") -join "`n"
    $body = ([regex]::Matches($parts, '(?s)ct=text/plain, text=(.*?)(?=\nRow: |\z)') | % { $_.Groups[1].Value.Trim() }) -join " "
    [pscustomobject]@{ Kind = "mms"; Id = [long]$id; Addr = "$addr".Trim(); Date = $date; Body = $body }
  }
}
function NewTexts { $s = Get-Content $State; @(NewSms ([long]$s[0])) + @(NewMms ([long]$s[1])) | ? { $_ } | sort Date }
function MarkDone($t) { $s = Get-Content $State; if ($t.Kind -eq "sms") { $s[0] = [math]::Max([long]$s[0], $t.Id) } else { $s[1] = [math]::Max([long]$s[1], $t.Id) }; Set-Content $State $s }
function LogRow($t, $action) {
  [pscustomobject]@{ When = Get-Date -f s; Kind = $t.Kind; Id = $t.Id; From = $t.Addr; Action = $action; Body = $t.Body } |
    Export-Csv -Append -NoTypeInformation -Encoding utf8 $Log
  Write-Host "$($t.Kind) $($t.Id) -> $action"
}

function Process-New {
  foreach ($t in NewTexts) {
    MarkDone $t
    $saved = -not ($t.Addr -match '\d') -or ((adb shell "content query --uri content://com.android.contacts/phone_lookup/$([uri]::EscapeDataString($t.Addr)) --projection _id") -match 'Row:')
    if ($saved) { LogRow $t "keep:contact"; continue }
    if (Match TEXT_FILTER_PATTERNS_A $t.Body) { $act = "a"; $res = $null }
    elseif (Match TEXT_FILTER_PATTERNS_B $t.Body) { $act = "b" }
    else { LogRow $t "keep"; continue }

    adb shell input keyevent KEYCODE_WAKEUP
    if (Locked) { LogRow $t "skipped-locked:$act"; continue }
    if ($act -eq "a") { LogRow $t "a:$(Archive $t.Addr)"; continue }

    if (-not (SendStop $t.Addr)) { LogRow $t "b:stop-not-sent"; continue }
    $sent = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    $wait = [int](Env TEXT_STOP_WAIT_SECONDS); if (-not $wait) { $wait = 5 }
    $reply = $null
    for ($i = 0; $i -lt $wait -and -not $reply; $i++) {
      Start-Sleep 1
      $reply = NewTexts | ? { (Digits $_.Addr) -eq (Digits $t.Addr) -and $_.Date -ge $sent - 2000 } | select -First 1
    }
    if ($reply) { MarkDone $reply; LogRow $reply "reply-to-stop" }
    if ($reply -and (Match TEXT_FILTER_PATTERNS_C $reply.Body)) { LogRow $t "b:stop-confirmed:$(Archive $t.Addr)" }
    else { LogRow $t "b:no-confirm:$(BlockReport $t.Addr)" }
  }
}

# First run: record newest existing ids so existing texts are never touched
if (-not (Test-Path $State) -or -not (Get-Content $State)) {
  $sms = ((adb shell "content query --uri content://sms/inbox --projection _id") | % { if ($_ -match '_id=(\d+)') { [long]$Matches[1] } } | measure -Maximum).Maximum
  $mms = ((adb shell "content query --uri content://mms/inbox --projection _id") | % { if ($_ -match '_id=(\d+)') { [long]$Matches[1] } } | measure -Maximum).Maximum
  Set-Content $State @([long]$sms, [long]$mms)
  Write-Host "Recorded newest existing ids (sms $sms, mms $mms); watching for new texts"
}

while ($true) {
  adb wait-for-device
  Process-New   # catch anything that arrived while disconnected
  adb logcat -b events -T 1 | % {
    if ($_ -match "notification_enqueue: \[\d+,\d+,$([regex]::Escape($Pkg)),\d+,$([regex]::Escape($Pkg)):incoming_message") {
      Start-Sleep 3
      Process-New
    }
  }
  Start-Sleep 5
}
