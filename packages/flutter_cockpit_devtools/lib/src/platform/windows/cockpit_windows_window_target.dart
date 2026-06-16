import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef CockpitWindowsShellRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

typedef CockpitWindowsWindowResolver =
    Future<CockpitWindowsWindowTarget> Function({
      required String appId,
      required int? processId,
      required String powershellExecutable,
      required CockpitWindowsShellRunner processRunner,
      required Duration timeout,
      required Duration activationSettleDelay,
    });

final class CockpitWindowsWindowTarget {
  const CockpitWindowsWindowTarget({
    required this.title,
    required this.handle,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String title;
  final int handle;
  final int left;
  final int top;
  final int width;
  final int height;
}

Future<CockpitWindowsWindowTarget> cockpitResolveWindowsWindowTarget({
  required String appId,
  required int? processId,
  required String powershellExecutable,
  required CockpitWindowsShellRunner processRunner,
  required Duration timeout,
  required Duration activationSettleDelay,
}) async {
  final result = await processRunner(powershellExecutable, <String>[
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    _windowTargetScript,
    appId,
    processId?.toString() ?? '',
    activationSettleDelay.inMilliseconds.toString(),
  ]).timeout(timeout);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to resolve the active Windows window for $appId: '
      '${result.stderr ?? result.stdout}',
    );
  }

  final stdout = '${result.stdout}'.trim();
  if (stdout.isEmpty) {
    throw StateError(
      'Unable to resolve the active Windows window for $appId: empty response.',
    );
  }

  final decoded = jsonDecode(stdout);
  if (decoded is! Map<Object?, Object?>) {
    throw StateError(
      'Unable to resolve the active Windows window for $appId: invalid payload.',
    );
  }

  final title = '${decoded['title'] ?? ''}'.trim();
  if (title.isEmpty) {
    throw StateError(
      'Unable to resolve the active Windows window for $appId: missing title.',
    );
  }

  return CockpitWindowsWindowTarget(
    title: title,
    handle: _readInt(decoded, 'handle'),
    left: _readInt(decoded, 'left'),
    top: _readInt(decoded, 'top'),
    width: _readInt(decoded, 'width'),
    height: _readInt(decoded, 'height'),
  );
}

int _readInt(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw StateError('Invalid Windows window payload for $key: $value');
}

const String _windowTargetScript = r'''
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class CockpitWindowInterop {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
$appId = $args[0]
$targetProcessIdArg = $args[1]
$settleMs = [int]$args[2]
if ([string]::IsNullOrWhiteSpace($targetProcessIdArg)) {
  $process = Get-Process -Name $appId -ErrorAction Stop |
    Where-Object {
      $_.MainWindowHandle -ne 0 -and
      -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle)
    } |
    Sort-Object -Property Id -Descending |
    Select-Object -First 1
} else {
  $targetProcessId = [int]$targetProcessIdArg
  $process = Get-Process -Id $targetProcessId -ErrorAction Stop |
    Where-Object {
      $_.MainWindowHandle -ne 0 -and
      -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle)
    } |
    Select-Object -First 1
}
if ($null -eq $process) {
  if ([string]::IsNullOrWhiteSpace($targetProcessIdArg)) {
    throw "No visible main window was found for process $appId."
  }
  throw "No visible main window was found for process id $targetProcessIdArg."
}
$windowHandle = [IntPtr]$process.MainWindowHandle
try {
  [Microsoft.VisualBasic.Interaction]::AppActivate($process.Id) | Out-Null
} catch {}
[void][CockpitWindowInterop]::ShowWindowAsync($windowHandle, 9)
[void][CockpitWindowInterop]::SetForegroundWindow($windowHandle)
if ($settleMs -gt 0) {
  Start-Sleep -Milliseconds $settleMs
}
$rect = New-Object CockpitWindowInterop+RECT
if (-not [CockpitWindowInterop]::GetWindowRect($windowHandle, [ref]$rect)) {
  throw "GetWindowRect failed for process $appId."
}
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
  throw "Resolved invalid bounds for process ${appId}: $($rect.Left),$($rect.Top),$width,$height"
}
[pscustomobject]@{
  title = $process.MainWindowTitle
  handle = $windowHandle.ToInt64()
  left = $rect.Left
  top = $rect.Top
  width = $width
  height = $height
} | ConvertTo-Json -Compress
''';
