'*************************************************************
'** Draw2d Performance Benchmark Tool
'*************************************************************

sub main()
  repeat = 10000
  m.drawFpsTarget = 30

  m.testBitmap = CreateObject("roBitmap", "pkg:/images/roku-logo-transparent.png")
  m.screenW = 1280
  m.screenH = 720
  m.maxTestTimeMs = 30000
  fontRegistry = CreateObject("roFontRegistry")
  m.defaultFont = fontRegistry.GetDefaultFont()
  m.smallFontSize = fontRegistry.GetDefaultFontSize() / 3
  m.smallFont = fontRegistry.GetDefaultFont(m.smallFontSize, false, false)
  m.screen = CreateObject("roScreen", true, m.screenW, m.screenH)
  m.screen.setAlphaEnable(true)
  m.functionPerfCount = 50
  m.suite = ""
  doFunctionSpeedTests = true
  doDrawTests = true
  doRegionCreationTests = true
  doCompositingTests = true

  m.fullResult = []
  m.fullResultText = []

  printHeaderDetails()

  if doFunctionSpeedTests
    m.suite = "FunctionSpeed"
    runBenchmark("RecursionFunction", recursionFunction, repeat)
    runBenchmark("RecursionSub", recursionSub, repeat)
    runBenchmark("Loop", loop, repeat)
    runBenchmark("LoopFuncCall", loopFuncCall, repeat)
    runBenchmark("LoopFuncCallNoReturn", loopFuncCallNoReturn, repeat)
    runBenchmark("LoopSubCall", loopSubCall, repeat)
    runBenchmark("ClassCreate", classCreate, repeat)
  end if
  if doDrawTests
    m.suite = "Draw"
    repeatsForThisTest = repeat * 10 ' these are fast
    runBenchmark("DrawLine", drawLine, repeatsForThisTest)
    runBenchmark("DrawRect", drawRect, repeatsForThisTest)
    runBenchmark("DrawPoint", drawPoint, repeatsForThisTest)
    m.screen.setAlphaEnable(false)
    runBenchmark("DrawObject (no-Alpha)", drawObject, repeatsForThisTest)
    m.screen.setAlphaEnable(true)
    runBenchmark("DrawObject (with-Alpha)", drawObject, repeatsForThisTest)
    runBenchmark("DrawRotatedObject", drawRotatedObject, repeatsForThisTest)
    runBenchmark("DrawScaledObject", drawScaledObject, repeatsForThisTest)
  end if
  if doRegionCreationTests
    m.suite = "RegionCreation"
    runBenchmark("CreateTempBitmap", createTempBitmap, repeat)
    runBenchmark("ReuseBitmap", reuseBitmap, repeat)
    runBenchmark("CreateTempBitmapAndRegion", createTempBitmapAndRegion, repeat)
    runBenchmark("ReuseBitmapAndRegion", reuseBitmapAndRegion, repeat)
  end if
  if doCompositingTests
    m.suite = "Compositing"
    runBenchmark("CompositorWrap (HD)", testCompositorWrapHd, repeat)
    runBenchmark("CompositorWrap (FHD)", testCompositorWrapFhd, repeat)
    runBenchmark("CompositorWrap (4k)", testCompositorWrap4k, repeat)
    runBenchmark("CompositorSprites", testCompositorSprites, repeat)
    runBenchmark("ManualSprites", testManualSprites, repeat)
  end if

  calculateScore()

  showResultsOnScreen()

  sleep(2000)
end sub

sub printHeaderDetails()
  appInfo = CreateObject("roAppInfo")
  deviceInfo = CreateObject("roDeviceInfo")


  m.fullResultText.push("Roku Draw2d Performance Benchmark Tool - v" + appInfo.GetVersion())
  if deviceInfo.hasFeature("simulation_engine")
    simulatorInfo = deviceInfo.getFriendlyName() + " - Platform: " + GetSimulatorPlatform(deviceInfo) + " - Roku OS: " + GetOSVersion(deviceInfo)
    if deviceInfo.GetModelDetails().serialNumber <> invalid
      simulatorInfo += "Serial Number: " + deviceInfo.GetModelDetails().serialNumber
    end if
    m.fullResultText.push(simulatorInfo)
  else
    m.fullResultText.push(deviceInfo.GetModelDisplayName() + " (" + deviceInfo.GetModelDetails().modelNumber + ") " + deviceInfo.GetModelType() + " - Roku OS: " + GetOSVersion(deviceInfo))
  end if
  m.fullResultText.push("Screen Size: " + m.screenW.toStr() + "x" + m.screenH.toStr() + ", Framerate Target: " + m.drawFpsTarget.toStr() + "fps, Max Test Time (ms): " + m.maxTestTimeMs.toStr())
  m.fullResultText.push(getCSVHeaderLine())

  for each line in m.fullResultText
    ? line
  end for
end sub

function GetOSVersion(di) as string
  OSVersion = di.GetOSVersion()
  return OSVersion.major + "." + OSVersion.minor + "." + OSVersion.revision + "." + OSVersion.build
end function

function GetSimulatorPlatform(di) as string
  platformInfo = ""
  if di.hasFeature("platform_browser")
    if di.hasFeature("platform_chromium")
      platformInfo = "Chromium"
    else if di.hasFeature("platform_firefox")
      platformInfo = "Firefox"
    else if di.hasFeature("platform_safari")
      platformInfo = "Safari"
    end if
  else
    platformInfo = "NodeJS"
  end if

  if di.hasFeature("platform_electron")
    platformInfo = " (Electron)"
  end if

  if di.hasFeature("platform_windows")
    platformInfo += " Windows"
  else if di.hasFeature("platform_macos")
    platformInfo += " macOS"
  else if di.hasFeature("platform_linux")
    platformInfo += " Linux"
  else if di.hasFeature("platform_chromeos")
    platformInfo += " ChromeOS"
  else if di.hasFeature("platform_android")
    platformInfo += " Android"
  else if di.hasFeature("platform_ios")
    platformInfo += " iOS"
  end if
  return platformInfo
end function

sub runBenchmark(benchmarkName, testFunction, repeat, dynamicallyScale = true)
  i = 0
  msPerSwapTarget = cint(1000 / m.drawFpsTarget)
  frameCount = 0
  totalSwapTime = 0
  m.screen.clear(255)
  frameTimer = CreateObject("roTimeSpan")
  totalTimer = CreateObject("roTimeSpan")
  opsPerSwap = 100
  firstFrame = true
  opsSinceSwap = 0
  testData = {}
  timeForFrame = 0
  totalLastFrameTime = 0
  totalTime = 0
  testNotSupported = false
  while (i < repeat and totalTime < m.maxTestTimeMs)
    testResult = testFunction(i, testData)
    if testResult <> invalid and not testResult
      testNotSupported = true
      exit while
    end if

    timeForFrame = frameTimer.totalMilliseconds()
    if timeForFrame > msPerSwapTarget or (dynamicallyScale and not firstFrame and opsSinceSwap >= opsPerSwap)

      frameTimer.mark()
      if opsPerSwap < opsSinceSwap and firstFrame
        opsPerSwap = opsSinceSwap
      end if
      firstFrame = false
      drawTextWithBackground(opsSinceSwap.toStr(), m.screenW - 300, m.screenH - 100, 250)
      drawTextWithBackground(m.suite + ":" + benchmarkName, 50, 50, m.screenW - 100)
      m.screen.swapBuffers()
      m.screen.clear(255)
      frameCount++
      swapTime = frameTimer.totalMilliseconds()
      if dynamicallyScale
        totalLastFrameTime = timeForFrame + swapTime
        opsPerSwap = intScaleIfNeeded(opsPerSwap, totalLastFrameTime, msPerSwapTarget)
      end if
      totalSwapTime += swapTime
      frameTimer.mark()
      opsSinceSwap = 0

      totalTime = totalTimer.totalMilliseconds()
    end if
    i += 1
    opsSinceSwap += 1
  end while
  if opsPerSwap < 0
    opsPerSwap = opsSinceSwap
  end if
  if frameCount = 0
    m.screen.swapBuffers()
    frameCount = 1
  end if
  totalTime = totalTimer.totalMilliseconds()
  m.screen.swapBuffers()
  benchmarkResult = buildBenchmarkResult(benchmarkName, not testNotSupported, totalTime, frameCount, i, totalSwapTime, opsPerSwap)
  resultCsvLine = getCSVResultLine(benchmarkResult)
  ? resultCsvLine
  m.fullResult.push(benchmarkResult)
  m.fullResultText.push(resultCsvLine)
end sub


sub calculateScore()
  totalScore = 0
  totalTime = 0
  totalOpsPerFrame = 0
  totalOpsPerSecond = 0
  totalOpsToReachTarget = 0
  maxOpsPerFrame = 0
  maxOpsPerSecond = 0
  maxOpsToReachTarget = 0
  validResults = 0
  for each result in m.fullResult
    if result.didRun
      validResults += 1
      totalTime += result.totalTime
      totalOpsPerFrame += result.opsPerFrame
      if result.opsPerFrame > maxOpsPerFrame
        maxOpsPerFrame = result.opsPerFrame
      end if
      totalOpsPerSecond += result.opsPerSecond
      if result.opsPerSecond > maxOpsPerSecond
        maxOpsPerSecond = result.opsPerSecond
      end if
      totalOpsToReachTarget += result.avgOpsToReachTarget
      if result.avgOpsToReachTarget > maxOpsToReachTarget
        maxOpsToReachTarget = result.avgOpsToReachTarget
      end if
    end if
  end for
  if validResults > 0
    avgOpsPerFrame = totalOpsPerFrame / validResults
    avgOpsPerSecond = totalOpsPerSecond / validResults
    avgOpsToReachTarget = totalOpsToReachTarget / validResults
    totalScore = ((avgOpsPerFrame / maxOpsPerFrame) * (avgOpsPerSecond / maxOpsPerSecond) * (avgOpsToReachTarget / maxOpsToReachTarget)) ^ (1 / 3)
    totalScore = totalScore * validResults
    totalScore = totalScore / m.fullResult.count()
  end if
  totalScoreLine = "Total Score: " + totalScore.toStr()
  ? totalScoreLine
  m.fullResultText.push(totalScoreLine)
  totalTimeLine = "Total Time: " + Int(totalTime/1000).toStr() + " seconds"
  ? totalTimeLine
  m.fullResultText.push(totalTimeLine)
end sub


sub showResultsOnScreen()
  offset = 50
  drawTextLinesWithBackground(m.fullResultText, offset, offset, m.screenW - offset * 2, m.smallFontSize, m.smallFont)
  m.screen.swapBuffers()
end sub