# Recomprime un MP4 a H.264 con una tasa razonable usando el transcodificador de Windows (sin instalar nada).
#   powershell -File promo\compress.ps1 -Source promo\promo_raw.mp4 -Target promo\promo_20s.mp4 -Mbps 14
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target,
    [int]$Mbps = 14
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.Media.Transcoding.MediaTranscoder, Windows.Media, ContentType = WindowsRuntime]
[void][Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media, ContentType = WindowsRuntime]

$extensions = [System.WindowsRuntimeSystemExtensions].GetMethods()
$asTaskOperation = ($extensions | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskProgress = ($extensions | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0]

function Await($operation, [Type]$resultType) {
    $task = $asTaskOperation.MakeGenericMethod($resultType).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
    $task.Result
}

$sourcePath = (Resolve-Path $Source).Path
$targetDir = Split-Path -Parent ([System.IO.Path]::GetFullPath($Target))
$targetName = Split-Path -Leaf $Target

$sourceFile = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($sourcePath)) ([Windows.Storage.StorageFile])
$folder = Await ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($targetDir)) ([Windows.Storage.StorageFolder])
$targetFile = Await ($folder.CreateFileAsync($targetName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])

$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp4([Windows.Media.MediaProperties.VideoEncodingQuality]::HD1080p)
$profile.Video.Bitrate = [uint32]($Mbps * 1000000)
$profile.Video.FrameRate.Numerator = 60
$profile.Video.FrameRate.Denominator = 1
$profile.Audio = $null   # el montaje no lleva sonido

$transcoder = New-Object Windows.Media.Transcoding.MediaTranscoder
$prepared = Await ($transcoder.PrepareFileTranscodeAsync($sourceFile, $targetFile, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
if (-not $prepared.CanTranscode) { throw "No se puede transcodificar: $($prepared.FailureReason)" }

$task = $asTaskProgress.MakeGenericMethod([double]).Invoke($null, @($prepared.TranscodeAsync()))
$task.Wait(-1) | Out-Null
"Escrito $Target ({0:N1} MB)" -f ((Get-Item ([System.IO.Path]::GetFullPath($Target))).Length / 1MB)
