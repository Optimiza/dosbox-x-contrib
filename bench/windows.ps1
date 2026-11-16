# The launcher common.sh calls on Windows: boots <Run>\run.conf headless and bounded on one
# DOSBox-X build, reads the emulator's memory from outside, and writes <Run>\report.txt.
#
#   powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File windows.ps1
#       -Build <dosbox-x.exe> -Run <directory holding run.conf> -Output <file the guest leaves there>
#       -Seconds <bound> [-Held <file> -Go <file> -LimitKb <working set limit>] [-UnitTests]
#
# With -Held and -Go, a guest that creates <Run>\<Held> is read at that moment (working set
# and private bytes) and let go by creating <Run>\<Go>: the handshake MEMPROBE waits on.
# With -UnitTests the build runs its own unit tests (-tests) instead of a guest and writes their
# result to <Run>\<Output>.
#
# exit: 0 the emulator exited 0 and the guest left its output | 2 bad usage
#       3 INVALID: the emulator failed, was cut off at the bound or the limit, left no output,
#         or its log names no build
param(
    [string]$Build = "",
    [string]$Run = "",
    [string]$Output = "",
    [int]$Seconds = 0,
    [string]$Held = "",
    [string]$Go = "",
    [long]$LimitKb = 0,
    [switch]$UnitTests,
    [Parameter(ValueFromRemainingArguments = $true)] $Rest
)
$ErrorActionPreference = "Stop"

function Fail([int]$code, [string]$message) {
    [Console]::Error.WriteLine("windows.ps1: $message")
    exit $code
}

# An unforeseen error is no verdict about a build: never exit 1.
trap { Fail 3 "INVALID: $($_.Exception.Message)" }

if ($Rest) { Fail 2 "unknown argument: $Rest" }
if ($Build -eq "" -or $Run -eq "" -or $Output -eq "" -or $Seconds -lt 1) { Fail 2 "-Build, -Run, -Output and -Seconds are required" }
if (($Held -eq "") -ne ($Go -eq "")) { Fail 2 "-Held and -Go go together" }
if (-not (Test-Path -LiteralPath $Build -PathType Leaf)) { Fail 2 "not an executable: $Build" }
$conf = Join-Path $Run "run.conf"
if (-not (Test-Path -LiteralPath $conf -PathType Leaf)) { Fail 2 "no run.conf in $Run" }

$log = Join-Path $Run "dosbox.log"
$outputPath = Join-Path $Run $Output
Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $log, $outputPath

# The dummy video driver: no window opens.
$env:SDL_VIDEODRIVER = "dummy"
$argLine = "-conf `"$conf`" -set `"dosbox quit warning=false`" -nopromptfolder -set `"log logfile=$log`" -set `"sdl videodriver=dummy`""
if ($UnitTests) {
    # waitonerror: without it a Windows build ends its tests waiting for Enter on a console.
    $argLine += " -tests -set `"sdl waitonerror=false`" `"--gtest_output=xml:$outputPath`""
}
$process = Start-Process -FilePath $Build -ArgumentList $argLine -WorkingDirectory $Run -PassThru -WindowStyle Hidden
# Without a handle taken now, the exit code is gone by the time the process has ended.
$null = $process.Handle
Set-Content -Encoding ascii -LiteralPath (Join-Path $Run "emulator.pid") -Value $process.Id

$peakKb = 0; $heldKb = 0; $heldPrivateKb = 0; $samples = 0; $cut = ""
$deadline = (Get-Date).AddSeconds($Seconds)
while (-not $process.HasExited) {
    try {
        if ($Held -ne "" -and $heldKb -eq 0 -and (Test-Path -LiteralPath (Join-Path $Run $Held))) {
            $process.Refresh()
            $heldKb = [int64]($process.WorkingSet64 / 1024)
            $heldPrivateKb = [int64]($process.PrivateMemorySize64 / 1024)
            [IO.File]::Create((Join-Path $Run $Go)).Dispose()
        }
        $process.Refresh()
        $peak = [int64]($process.PeakWorkingSet64 / 1024)
        if ($peak -gt $peakKb) { $peakKb = $peak }
        $samples++
        if ($LimitKb -gt 0 -and $peak -gt $LimitKb) { $cut = "passed the limit of $LimitKb kB of working set (peak $peakKb kB)" }
        elseif ((Get-Date) -gt $deadline) { $cut = "passed the bound of $Seconds s" }
        if ($cut -ne "") { $process.Kill(); break }
    } catch [InvalidOperationException] {
        break
    }
    Start-Sleep -Milliseconds 100
}
$process.WaitForExit()
$exitCode = $process.ExitCode

$version = ""
if (Test-Path -LiteralPath $log) {
    $version = [string](@(Get-Content -LiteralPath $log | Where-Object { $_ -cmatch "^DOSBox-X version" })[0])
}
# A -tests run logs its verdict and nothing else.
if ($UnitTests -and $version -eq "") { $version = "not logged by a -tests run" }
$report = @(
    "windows.ps1: binary: $Build",
    "windows.ps1: version: $version",
    "windows.ps1: exit code: $exitCode",
    "windows.ps1: memory: peak_ws_kb=$peakKb held_ws_kb=$heldKb held_private_kb=$heldPrivateKb samples=$samples"
)
[IO.File]::WriteAllLines((Join-Path $Run "report.txt"), $report, [Text.Encoding]::ASCII)

if ($cut -ne "") { Fail 3 "INVALID: the emulator $cut and was killed" }
if ($exitCode -ne 0) { Fail 3 "INVALID: the emulator exited $exitCode" }
if ($version -eq "") { Fail 3 "INVALID: the emulator's log has no version line" }
if (-not (Test-Path -LiteralPath $outputPath) -or (Get-Item -LiteralPath $outputPath).Length -eq 0) {
    Fail 3 "INVALID: the guest left no $Output"
}
exit 0
