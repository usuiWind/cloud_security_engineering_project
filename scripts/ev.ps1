function ev {
  param($m, $n, [Parameter(ValueFromRemainingArguments=$true)]$cmd)
  $d = "evidence/$m"
  New-Item -ItemType Directory -Force $d | Out-Null
  $f = "$d/$n.txt"
  $line = $cmd -join ' '
  $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  $ErrorActionPreference = 'Continue'
  $global:LASTEXITCODE = 0
  # 2>&1 must sit inside the evaluated block, or native stderr (the denial text) is lost.
  # PS 5.1 wraps each stderr line in an ErrorRecord; keep the text, drop its blank-line placeholder.
  $out = Invoke-Expression "& { $line } 2>&1" |
    ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { "$_" } else { $_ } } |
    Where-Object { "$_" -ne 'System.Management.Automation.RemoteException' } | Out-String
  "# $ts  profile=$env:AWS_PROFILE  exit=$LASTEXITCODE`n`$ $line`n$out" | Set-Content -Encoding utf8 $f
  "saved $f"
}
