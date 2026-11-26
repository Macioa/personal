# Watch phone for new Samsung voicemails; pull, transcribe, delete those matching local.env filters.
# Usage: powershell -File watch.ps1 [-Delete]
#   -Delete  actually delete matches (default: log only)
# First run records voicemails already on the phone as processed (read-only) so only new ones are handled.
param([switch]$Delete)
$ErrorActionPreference = "Stop"
$Root  = Resolve-Path "$PSScriptRoot\..\.."
$Out   = Join-Path $Root "temp\voicemail"
$State = Join-Path $Out "processed.txt"
$Log   = Join-Path $Out "log.csv"
$Share = "/sdcard/VisualVoiceMail/share"
New-Item -ItemType Directory -Force $Out | Out-Null
if (-not (Test-Path $State)) { New-Item -ItemType File $State | Out-Null }

# Dump UI, return nodes
function Ui { $x = (adb shell "uiautomator dump /sdcard/u.xml >/dev/null; cat /sdcard/u.xml") -join ''; ([xml]$x).SelectNodes("//node") }
function Tap($n) { $b = $n.bounds -replace '[\[\]]', ' ' -split '[ ,]+' | ? { $_ }; adb shell input tap ([int](($b[0] / 1 + $b[2]) / 2)) ([int](($b[1] / 1 + $b[3]) / 2)); Start-Sleep 2 }
function ById($nodes, $id) { $nodes | ? { $_.'resource-id' -eq "com.samsung.vvm:id/$id" } }

# Voicemail rows on the inbox screen
function Rows {
  foreach ($s in @(ById (Ui) senders)) {
    $row = $s.ParentNode   # climb to the row that holds this sender's own fields
    while ($row -and -not $row.SelectSingleNode(".//node[@resource-id='com.samsung.vvm:id/timeView']")) { $row = $row.ParentNode }
    if (-not $row -or $row.SelectNodes(".//node[@resource-id='com.samsung.vvm:id/senders']").Count -ne 1) { continue }   # row cut off
    $f = { param($id) $row.SelectSingleNode(".//node[@resource-id='com.samsung.vvm:id/$id']").text }
    $d = & $f date; $t = & $f timeView
    if (-not $d -or -not $t) { continue }   # row cut off at screen edge
    [pscustomobject]@{ Node = $s; Sender = $s.text; Key = "$($s.text)|$d|$t"
      Saved = if ((& $f contacttype) -like "Unsaved*") { "0" } else { "1" }; Dur = & $f duration }
  }
}

function Locked { (adb shell dumpsys window) -match "mDreamingLockscreen=true|isKeyguardShowing=true" }

function Process-New {
  adb shell input keyevent KEYCODE_WAKEUP
  if (Locked) { Write-Host "Phone locked; skipping"; return }
  adb shell monkey -p com.samsung.vvm -c android.intent.category.LAUNCHER 1 | Out-Null; Start-Sleep 3
  $skip = @()
  while ($true) {
    adb shell input swipe 540 700 540 2000 200; Start-Sleep 1   # scroll to newest
    $done = @(Get-Content $State) + $skip
    $r = Rows | ? { $done -notcontains $_.Key } | select -First 1
    if (-not $r) { break }
    $before = adb shell ls $Share
    Tap $r.Node                                   # expand row
    $sh = ById (Ui) expanded_share
    if (-not $sh) { Write-Host "No Share button for $($r.Key)"; $skip += $r.Key; continue }
    Tap $sh                                       # export audio to share dir
    adb shell input keyevent BACK; Start-Sleep 1  # close share sheet
    $new = adb shell ls $Share | ? { $before -notcontains $_ } | select -First 1
    if (-not $new) { Write-Host "No export for $($r.Key)"; $skip += $r.Key; continue }
    $local = Join-Path $Out $new
    adb pull "$Share/$new" $local | Out-Null
    adb shell rm "$Share/$new"
    $res = python (Join-Path $PSScriptRoot classify.py) $local $r.Saved | ConvertFrom-Json
    Set-Content -Encoding utf8 ($local -replace '\.amr$', '.txt') $res.transcript
    $action = "keep"
    if ($res.delete) {
      $action = "would-delete:$($res.delete)"
      if ($Delete) {
        Tap (ById (Ui) delete)                    # row is still expanded
        $ok = Ui | ? { $_.clickable -eq "true" -and $_.text -match "^(Delete|Move to trash)$" } | select -First 1
        if ($ok) { Tap $ok }
        $action = "deleted:$($res.delete)"
      }
    }
    [pscustomobject]@{ When = Get-Date -f s; Sender = $r.Sender; Key = $r.Key; Dur = $r.Dur; File = $new; Action = $action; Transcript = $res.transcript } |
      Export-Csv -Append -NoTypeInformation -Encoding utf8 $Log
    Add-Content $State $r.Key
    Write-Host "$($r.Key) -> $action"
  }
}

# Record every voicemail currently listed as processed, without opening any
function Seed {
  adb shell input keyevent KEYCODE_WAKEUP
  if (Locked) { throw "Unlock the phone for the first run" }
  adb shell monkey -p com.samsung.vvm -c android.intent.category.LAUNCHER 1 | Out-Null; Start-Sleep 3
  adb shell input swipe 540 700 540 2000 200; Start-Sleep 1
  $keys = @()
  do {
    $n = $keys.Count
    $keys = @($keys + (Rows).Key | select -Unique)
    adb shell input swipe 540 1800 540 1000 1000; Start-Sleep 1   # slow, half-screen: no fling, rows overlap
  } while ($keys.Count -gt $n)
  Set-Content $State $keys
  Write-Host "Recorded $($keys.Count) existing voicemails; watching for new ones"
}

if (-not (Get-Content $State)) { Seed }
while ($true) {
  adb wait-for-device
  adb logcat -b events -T 1 | % {
    if ($_ -match "notification_enqueue: \[\d+,\d+,com\.samsung\.vvm,.*channel=normal_new") {
      Start-Sleep 20   # let the app finish downloading audio
      Process-New
    }
  }
  Start-Sleep 5
}


