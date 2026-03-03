# PowerShell script to test trace service

# Login and get token
$loginResponse = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/auth/login" -Method Post -ContentType "application/json" -Body '{"email":"subimv17@gmail.com","password":"subi@2006"}'

# Clean token (remove spaces)
$token = $loginResponse.access_token -replace " ", ""
$workspaceId = "af3b2d41-fd7c-460b-945c-17093c109c31"

Write-Host "=== Testing Trace Service ===" -ForegroundColor Cyan

# Test 1: Get traces (should be empty initially)
Write-Host "`n1. Getting traces..." -ForegroundColor Yellow
$traces = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/workspaces/$workspaceId/traces" -Method Get -Headers @{"Authorization"="Bearer $token"}
Write-Host "Total traces: $($traces.total)"
$traces.traces | ConvertTo-Json -Depth 5

# Test 2: Create a collection
Write-Host "`n2. Creating collection..." -ForegroundColor Yellow
$collection = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/workspaces/$workspaceId/collections" -Method Post -Headers @{"Authorization"="Bearer $token"} -ContentType "application/json" -Body '{"name":"Test Collection","description":"For tracing test"}'
Write-Host "Collection created: $($collection.id)"

# Test 3: Create an API request
Write-Host "`n3. Creating API request..." -ForegroundColor Yellow
$request = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/workspaces/$workspaceId/collections/$($collection.id)/requests" -Method Post -Headers @{"Authorization"="Bearer $token"} -ContentType "application/json" -Body '{"name":"GitHub API Test","method":"GET","url":"https://api.github.com/users/octocat"}'
Write-Host "Request created: $($request.id)"

# Test 4: Execute the request (this should generate traces)
Write-Host "`n4. Executing request to generate traces..." -ForegroundColor Yellow
$execute = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/workspaces/$workspaceId/requests/$($request.id)/execute" -Method Post -Headers @{"Authorization"="Bearer $token"}
Write-Host "Execution result: $($execute | ConvertTo-Json)"

# Test 5: Get traces again (should now have traces)
Write-Host "`n5. Getting traces after execution..." -ForegroundColor Yellow
$tracesAfter = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/workspaces/$workspaceId/traces" -Method Get -Headers @{"Authorization"="Bearer $token"}
Write-Host "Total traces: $($tracesAfter.total)"
if ($tracesAfter.traces -is [Array]) {
    $tracesAfter.traces | ForEach-Object { Write-Host $_.id }
} else {
    Write-Host "Traces: $($tracesAfter.traces | ConvertTo-Json -Compress)"
}

# Test 6: Get trace details - using the trace_id from execution response
$traceIdFromExecution = "9d5e8d5b-5c94-442b-a6ad-29e555529287f"
Write-Host "`n6. Getting trace details for: $traceIdFromExecution" -ForegroundColor Yellow
try {
    $traceDetails = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/workspaces/$workspaceId/traces/$traceIdFromExecution" -Method Get -Headers @{"Authorization"="Bearer $token"}
    Write-Host "Trace ID: $($traceDetails.trace_id)"
    Write-Host "Spans count: $($traceDetails.spans.Count)"
    $traceDetails.spans | ForEach-Object { 
        Write-Host "  - Span: $($_.operation_name) | Service: $($_.service_name) | Duration: $($_.duration_ms)ms" 
    }
} catch {
    Write-Host "Error getting trace: $_"
}

# Test 7: Get critical path
if ($tracesAfter.traces.Count -gt 0) {
    Write-Host "`n7. Getting critical path..." -ForegroundColor Yellow
    $criticalPath = Invoke-RestMethod -Uri "http://localhost:8081/api/v1/workspaces/$workspaceId/traces/$firstTraceId/critical-path" -Method Get -Headers @{"Authorization"="Bearer $token"}
    $criticalPath | ConvertTo-Json -Depth 5
}

Write-Host "`n=== Trace Service Test Complete ===" -ForegroundColor Cyan
