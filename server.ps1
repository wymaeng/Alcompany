# AI 회사 포털 서버 (Windows 기본 PowerShell만 사용)
# 실행: 이 폴더에서  powershell -ExecutionPolicy Bypass -File server.ps1
# 접속: http://localhost:8080
param([int]$Port = 8080)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "포털이 켜졌습니다: http://localhost:$Port  (끄려면 Ctrl+C)"
Start-Process "http://localhost:$Port/"

$types = @{
  ".html" = "text/html; charset=utf-8"; ".json" = "application/json; charset=utf-8"
  ".md" = "text/plain; charset=utf-8"; ".txt" = "text/plain; charset=utf-8"
  ".css" = "text/css; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"
  ".png" = "image/png"; ".jpg" = "image/jpeg"; ".svg" = "image/svg+xml"; ".pdf" = "application/pdf"
}

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $res = $ctx.Response
    try {
      $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
      if ($rel -eq '') { $rel = 'index.html' }
      # __latest/<폴더> : 그 폴더에서 가장 최근에 바뀐 파일로 이동
      if ($rel -like '__latest/*') {
        $dir = [IO.Path]::GetFullPath((Join-Path $root $rel.Substring(9)))
        $newest = if ($dir.StartsWith($root) -and (Test-Path $dir -PathType Container)) {
          Get-ChildItem $dir -File | Where-Object { $_.Name -notlike '.*' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        if ($newest) {
          $parts = $newest.FullName.Substring($root.Length + 1) -split '[\\/]'
          $res.Redirect("/" + (($parts | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'))
        } else {
          $res.StatusCode = 404
        }
        continue
      }
      $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
      if ($path.StartsWith($root) -and (Test-Path $path -PathType Leaf)) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $ext = [IO.Path]::GetExtension($path).ToLower()
        $res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
        $res.Headers.Add("Cache-Control", "no-store")
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
      } else {
        $res.StatusCode = 404
      }
    } catch {
      $res.StatusCode = 500
    } finally {
      $res.Close()
    }
  }
} finally {
  $listener.Stop()
}
