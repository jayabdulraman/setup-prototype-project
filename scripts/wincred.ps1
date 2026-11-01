# wincred.ps1 — Windows Credential Manager backend for secrets.sh. Not meant to be run by hand.
#
#   wincred.ps1 set <target>   reads the value as hex on stdin
#   wincred.ps1 get <target>   writes the value as hex on stdout; exit 1 if missing
#   wincred.ps1 has <target>   exit 0 if stored, 1 if not
#   wincred.ps1 del <target>
#
# Values travel as hex so nothing is lost between Git Bash and PowerShell. Credential
# Manager holds up to 2560 bytes per entry; larger values (e.g. service-account JSON)
# are encrypted for the current Windows user with DPAPI under %LOCALAPPDATA%.
param(
  [Parameter(Mandatory = $true)][ValidateSet('set', 'get', 'has', 'del')][string]$Op,
  [Parameter(Mandatory = $true)][string]$Target
)
$ErrorActionPreference = 'Stop'

Add-Type -Namespace ProtoCred -Name Native -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL {
  public int Flags;
  public int Type;
  public string TargetName;
  public string Comment;
  public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
  public int CredentialBlobSize;
  public IntPtr CredentialBlob;
  public int Persist;
  public int AttributeCount;
  public IntPtr Attributes;
  public string TargetAlias;
  public string UserName;
}
[DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredWrite(ref CREDENTIAL credential, int flags);
[DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
[DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredDelete(string target, int type, int flags);
[DllImport("advapi32.dll")]
public static extern void CredFree(IntPtr credential);
'@
Add-Type -AssemblyName System.Security

$CRED_TYPE_GENERIC = 1
$CRED_PERSIST_LOCAL_MACHINE = 2
$MAX_BLOB = 2560
$Marshal = [System.Runtime.InteropServices.Marshal]

$safeName = ($Target -replace '[^A-Za-z0-9_.-]', '_') + '.bin'
$BigDir = Join-Path $env:LOCALAPPDATA 'prototype-secrets'
$BigFile = Join-Path $BigDir $safeName

function ConvertFrom-Hex([string]$hex) {
  $hex = $hex.Trim()
  $bytes = New-Object byte[] ($hex.Length / 2)
  for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
  return , $bytes
}
function ConvertTo-Hex([byte[]]$bytes) { return ([BitConverter]::ToString($bytes) -replace '-', '').ToLower() }

function Read-Cred {
  $ptr = [IntPtr]::Zero
  if (-not [ProtoCred.Native]::CredRead($Target, $CRED_TYPE_GENERIC, 0, [ref]$ptr)) { return $null }
  try {
    $cred = $Marshal::PtrToStructure($ptr, [type][ProtoCred.Native+CREDENTIAL])
    $bytes = New-Object byte[] $cred.CredentialBlobSize
    if ($bytes.Length -gt 0) { $Marshal::Copy($cred.CredentialBlob, $bytes, 0, $bytes.Length) }
    return , $bytes
  } finally { [ProtoCred.Native]::CredFree($ptr) }
}

function Write-Cred([byte[]]$bytes) {
  $blob = $Marshal::AllocHGlobal($bytes.Length)
  try {
    $Marshal::Copy($bytes, 0, $blob, $bytes.Length)
    $cred = New-Object ProtoCred.Native+CREDENTIAL
    $cred.Type = $CRED_TYPE_GENERIC
    $cred.TargetName = $Target
    $cred.UserName = $env:USERNAME
    $cred.Comment = 'Managed by the setup-prototype-project skill'
    $cred.CredentialBlobSize = $bytes.Length
    $cred.CredentialBlob = $blob
    $cred.Persist = $CRED_PERSIST_LOCAL_MACHINE
    if (-not [ProtoCred.Native]::CredWrite([ref]$cred, 0)) {
      throw "CredWrite failed (Win32 error $($Marshal::GetLastWin32Error()))"
    }
  } finally { $Marshal::FreeHGlobal($blob) }
}

switch ($Op) {
  'set' {
    $bytes = ConvertFrom-Hex ([Console]::In.ReadToEnd())
    if ($bytes.Length -le $MAX_BLOB) {
      Write-Cred $bytes
      if (Test-Path $BigFile) { Remove-Item $BigFile -Force }
    } else {
      New-Item -ItemType Directory -Force -Path $BigDir | Out-Null
      $protected = [System.Security.Cryptography.ProtectedData]::Protect(
        $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
      [System.IO.File]::WriteAllBytes($BigFile, $protected)
      [void][ProtoCred.Native]::CredDelete($Target, $CRED_TYPE_GENERIC, 0)
    }
  }
  'get' {
    if (Test-Path $BigFile) {
      $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        [System.IO.File]::ReadAllBytes($BigFile), $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    } else {
      $bytes = Read-Cred
      if ($null -eq $bytes) { exit 1 }
    }
    [Console]::Out.Write((ConvertTo-Hex $bytes))
  }
  'has' {
    if ((Test-Path $BigFile) -or ($null -ne (Read-Cred))) { exit 0 } else { exit 1 }
  }
  'del' {
    [void][ProtoCred.Native]::CredDelete($Target, $CRED_TYPE_GENERIC, 0)
    if (Test-Path $BigFile) { Remove-Item $BigFile -Force }
  }
}
exit 0
