$port = 3000
$root = Join-Path (Split-Path $PSScriptRoot -Parent) "public"

# MIME types
$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
$listener.Start()
Write-Host "=========================================="
Write-Host "  见微 · 人生观察者"
Write-Host "  http://localhost:$port"
Write-Host "  Ctrl+C 停止服务器"
Write-Host "=========================================="

while ($true) {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    
    # Read request line
    $request = $reader.ReadLine()
    if (-not $request) { $client.Close(); continue }
    
    # Read headers
    while ($reader.ReadLine() -ne "") { }
    
    # Parse path
    $path = "/index.html"  # default
    if ($request -match "GET\s+(/\S*)") {
        $path = $matches[1]
    }
    
    $filePath = Join-Path $root ($path -replace "/", "\")
    if (-not (Test-Path $filePath)) { $filePath = Join-Path $root "index.html" }
    
    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
    $contentType = "text/html; charset=utf-8"
    if ($mime.ContainsKey($ext)) { $contentType = $mime[$ext] }
    
    $body = [System.IO.File]::ReadAllBytes($filePath)
    
    $header = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    $stream.Write($body, 0, $body.Length)
    $stream.Close()
    $client.Close()
}

