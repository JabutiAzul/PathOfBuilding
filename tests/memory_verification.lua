-- Memory Verification Test Script
-- This script runs the application idle to verify memory leak fixes

-- Load the headless wrapper first to set up globals
package.path = package.path .. ";src/?.lua" .. ";../src/?.lua"
arg = {"test"} -- Set test mode to skip launching
dofile("src/HeadlessWrapper.lua")

file = io.open("memory_verification_log.txt", "w")
io.output(file)
local startTime = GetTime()
local testDuration = 60 * 60 * 60 * 6 -- 6000 seconds in frame count (assuming ~60 FPS)
local frameCount = 0
local memorySamples = {}
local initialMemory = collectgarbage("count")

print("Starting memory verification test...")
print("Initial memory: " .. initialMemory .. " KB")
print("Test will run for " .. (testDuration / 1000) .. " seconds")

-- Simulate OnFrame calls for the test duration
while frameCount < testDuration do
    -- Simulate a frame update
    runCallback("OnFrame")
    frameCount = frameCount + 1

    -- Collect memory sample every 1 second (roughly), but limit to prevent memory growth
    if frameCount % 60 == 0 then  -- Assuming ~60 FPS
        local currentMemory = collectgarbage("count")
        table.insert(memorySamples, currentMemory)

        -- Keep only last 100 samples to prevent unlimited growth
        if #memorySamples > 100 then
            table.remove(memorySamples, 1)
        end

        -- Print progress every 10 seconds
        if #memorySamples % 10 == 0 then
            print(string.format("Progress: %d elapsed, Memory: %d KB",
                frameCount, currentMemory))
        end

        -- Force garbage collection periodically to test cleanup
        if frameCount % 600 == 0 then  -- Every 10 seconds
            collectgarbage("collect")
            print("Forced garbage collection")
        end
    end
end

local endTime = GetTime()
local finalMemory = collectgarbage("count")

print("\nMemory verification test completed:")
print("Duration: " .. ((endTime - startTime) / 1000) .. " seconds")
print("Frames simulated: " .. frameCount)
print("Initial memory: " .. initialMemory .. " KB")
print("Final memory: " .. finalMemory .. " KB")
print("Memory change: " .. (finalMemory - initialMemory) .. " KB")

-- Analyze memory stability
if #memorySamples > 1 then
    local totalSamples = #memorySamples
    local avgMemory = 0
    for _, mem in ipairs(memorySamples) do
        avgMemory = avgMemory + mem
    end
    avgMemory = avgMemory / totalSamples

    local variance = 0
    for _, mem in ipairs(memorySamples) do
        variance = variance + (mem - avgMemory)^2
    end
    variance = variance / totalSamples
    local stdDev = math.sqrt(variance)

    print("Average memory: " .. string.format("%.1f", avgMemory) .. " KB")
    print("Standard deviation: " .. string.format("%.1f", stdDev) .. " KB")

    -- Check for memory growth trend
    local firstHalfAvg = 0
    local secondHalfAvg = 0
    local halfPoint = math.floor(totalSamples / 2)

    for i = 1, halfPoint do
        firstHalfAvg = firstHalfAvg + memorySamples[i]
    end
    firstHalfAvg = firstHalfAvg / halfPoint

    for i = halfPoint + 1, totalSamples do
        secondHalfAvg = secondHalfAvg + memorySamples[i]
    end
    secondHalfAvg = secondHalfAvg / (totalSamples - halfPoint)

    local growthTrend = secondHalfAvg - firstHalfAvg
    print("Memory growth trend: " .. string.format("%.1f", growthTrend) .. " KB")

    -- Determine test result
    local memoryGrowthThreshold = 500 -- 500 KB threshold for significant growth
    local stableThreshold = 100 -- 100 KB standard deviation for stability

    if math.abs(growthTrend) < memoryGrowthThreshold and stdDev < stableThreshold then
        print("\nRESULT: PASS - Memory usage appears stable")
        print("No significant memory leaks detected")
    else
        print("\nRESULT: FAIL - Memory issues detected")
        if math.abs(growthTrend) >= memoryGrowthThreshold then
            print("WARNING: Significant memory growth trend detected")
        end
        if stdDev >= stableThreshold then
            print("WARNING: High memory fluctuation detected")
        end
    end
else
    print("Insufficient samples for analysis")
end

-- Check onFrameFuncs cleanup
print("\nChecking onFrameFuncs cleanup...")
local onFrameFuncsCount = 0
if mainObject and mainObject.main and mainObject.main.onFrameFuncs then
    for _ in pairs(mainObject.main.onFrameFuncs) do
        onFrameFuncsCount = onFrameFuncsCount + 1
    end
end
print("onFrameFuncs count after test: " .. onFrameFuncsCount)

-- Check caches
print("\nChecking cache stability...")
if mainObject and mainObject.main then
    if mainObject.main.modes and mainObject.main.modes.BUILD and
       mainObject.main.modes.BUILD.skillsTab and
       mainObject.main.modes.BUILD.skillsTab.controls and
       mainObject.main.modes.BUILD.skillsTab.controls.gemList then
        local sortCacheCount = 0
        for _, gemControl in pairs(mainObject.main.modes.BUILD.skillsTab.controls.gemList) do
            if gemControl.sortCache then
                sortCacheCount = sortCacheCount + 1
            end
        end
        print("sortCache entries: " .. sortCacheCount)
    end

    local globalCacheCount = 0
    if GlobalCache and GlobalCache.cachedData then
        for mode, modeCache in pairs(GlobalCache.cachedData) do
            for _ in pairs(modeCache) do
                globalCacheCount = globalCacheCount + 1
            end
        end
    end
    print("GlobalCache entries: " .. globalCacheCount)
end

print("\nMemory verification test finished.")
io.close(file)