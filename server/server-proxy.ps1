$port = 3000
$root = Join-Path (Split-Path $PSScriptRoot -Parent) "public"
$mime = @{".html"="text/html; charset=utf-8";".css"="text/css; charset=utf-8";".js"="application/javascript; charset=utf-8";".json"="application/json";".png"="image/png";".jpg"="image/jpeg";".svg"="image/svg+xml"}

# Enable TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

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
    $request = $reader.ReadLine()
    if (-not $request) { $client.Close(); continue }
    
    $contentLength = 0
    $authHeader = ""
    while ($true) {
        $line = $reader.ReadLine()
        if ($line -eq "" -or $line -eq $null) { break }
        if ($line -match "^Content-Length:\s+(\d+)") { $contentLength = [int]$matches[1] }
        if ($line -match "^Authorization:\s*Bearer\s+(.+)") { $authHeader = $matches[1] }
        if ($line -match "^X-Api-Key:\s*(.+)") { if (-not $authHeader) { $authHeader = $matches[1] } }
    }
    
    $body = ""
    if ($contentLength -gt 0) {
        $buffer = New-Object char[] $contentLength
        $reader.Read($buffer, 0, $contentLength) | Out-Null
        $body = -join $buffer
    }
    
    # CORS preflight
    if ($request -match "OPTIONS") {
        $cors = "HTTP/1.1 204 No Content`r`nAccess-Control-Allow-Origin: *`r`nAccess-Control-Allow-Methods: GET, POST, OPTIONS`r`nAccess-Control-Allow-Headers: Content-Type, Authorization, X-Api-Key`r`nConnection: close`r`n`r`n"
        $stream.Write([Text.Encoding]::ASCII.GetBytes($cors), 0, $cors.Length)
        $stream.Close(); $client.Close()
        continue
    }
    
    if ($request -match "(GET|POST)\s+(/\S*)") {
        $path = $matches[2]
        
        # Proxy to DeepSeek
        if ($path -eq "/api/proxy") {
            if (-not $authHeader) {
                $err = '{ "error": { "message": "请先在设置中填入 DeepSeek API Key" } }'
                $errBytes = [Text.Encoding]::UTF8.GetBytes($err)
                $hdr = "HTTP/1.1 401 Unauthorized`r`nContent-Type: application/json; charset=utf-8`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($errBytes.Length)`r`nConnection: close`r`n`r`n"
                $stream.Write([Text.Encoding]::ASCII.GetBytes($hdr), 0, $hdr.Length)
                $stream.Write($errBytes, 0, $errBytes.Length)
                $stream.Close(); $client.Close()
                continue
            }
            
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("Content-Type", "application/json")
                $wc.Headers.Add("Authorization", "Bearer $authHeader")
                $wc.Encoding = [Text.Encoding]::UTF8
                $resp = $wc.UploadString("https://api.deepseek.com/v1/chat/completions", "POST", $body)
                $respBytes = [Text.Encoding]::UTF8.GetBytes($resp)
                $hdr = "HTTP/1.1 200 OK`r`nContent-Type: application/json; charset=utf-8`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($respBytes.Length)`r`nConnection: close`r`n`r`n"
                $stream.Write([Text.Encoding]::ASCII.GetBytes($hdr), 0, $hdr.Length)
                $stream.Write($respBytes, 0, $respBytes.Length)
            } catch {
                $err = "{ `"error`": { `"message`": `"DeepSeek 请求失败`" } }"
                $errBytes = [Text.Encoding]::UTF8.GetBytes($err)
                $hdr = "HTTP/1.1 502 Bad Gateway`r`nContent-Type: application/json; charset=utf-8`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($errBytes.Length)`r`nConnection: close`r`n`r`n"
                $stream.Write([Text.Encoding]::ASCII.GetBytes($hdr), 0, $hdr.Length)
                $stream.Write($errBytes, 0, $errBytes.Length)
            }
            $stream.Close(); $client.Close()
            continue
        }
        
        $cleanPath = ($path -replace "/", "\").TrimEnd("\")
        if ($cleanPath -eq "") { $cleanPath = "\index.html" }
        $filePath = Join-Path $root $cleanPath
        if (-not (Test-Path $filePath)) { $filePath = Join-Path $root "index.html" }
        
        $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
        $ct = "text/html; charset=utf-8"
        if ($mime.ContainsKey($ext)) { $ct = $mime[$ext] }
        
        $fbody = [System.IO.File]::ReadAllBytes($filePath)
        $hdr = "HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($fbody.Length)`r`nConnection: close`r`n`r`n"
        $stream.Write([Text.Encoding]::ASCII.GetBytes($hdr), 0, $hdr.Length)
        $stream.Write($fbody, 0, $fbody.Length)
    }
    
    $stream.Close()
    $client.Close()
}