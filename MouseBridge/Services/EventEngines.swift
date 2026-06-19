import AppKit
import CoreGraphics
import Foundation
import os

struct ScrollEventDescriptor: Equatable, Sendable {
    static let minimumPhysicalMouseConfidence = 0.65

    var deltaX: Int64
    var deltaY: Int64
    var pointDeltaX: Int64
    var pointDeltaY: Int64
    var isContinuous: Bool
    var deviceKind: InputDeviceKind
    var classificationConfidence: Double = 1
    var isSyntheticFromThisApp: Bool

    var isPhysicalMouseWheel: Bool {
        !isContinuous
            && deviceKind == .mouse
            && classificationConfidence >= Self.minimumPhysicalMouseConfidence
            && !isSyntheticFromThisApp
    }
}

struct ScrollTransformResult: Equatable, Sendable {
    var shouldHandle: Bool
    var deltaX: Int64
    var deltaY: Int64
    var pointDeltaX: Int64
    var pointDeltaY: Int64
}

struct SmoothScrollRequest: Equatable, Sendable {
    var deltaX: Int64
    var deltaY: Int64
    var location: CGPoint
}

struct InputEventSummary: Equatable, Sendable {
    var localizationKey: String
    var argument: Int?

    static let none = InputEventSummary(localizationKey: "diagnostics.event.none")
    static let trackpadScroll = InputEventSummary(localizationKey: "diagnostics.event.trackpadScroll")
    static let physicalMouseWheel = InputEventSummary(localizationKey: "diagnostics.event.physicalMouseWheel")

    static func mouseButton(_ buttonNumber: Int) -> InputEventSummary {
        InputEventSummary(localizationKey: "diagnostics.event.mouseButton", argument: buttonNumber)
    }

    var localizedDisplay: String {
        let format = NSLocalizedString(localizationKey, comment: "")
        if let argument {
            return String(format: format, argument)
        }
        return format
    }
}

struct InputEventSummaryRateLimiter: Equatable, Sendable {
    var minimumInterval: TimeInterval
    private var lastEmittedAt: TimeInterval?
    private var lastEmittedSummary: InputEventSummary?

    init(minimumInterval: TimeInterval = 0.25) {
        self.minimumInterval = max(0, minimumInterval)
    }

    mutating func shouldEmit(_ summary: InputEventSummary, now: TimeInterval) -> Bool {
        if summary.argument != nil {
            record(summary, now: now)
            return true
        }

        guard let lastEmittedAt, let lastEmittedSummary else {
            record(summary, now: now)
            return true
        }

        if lastEmittedSummary != summary || now - lastEmittedAt >= minimumInterval {
            record(summary, now: now)
            return true
        }

        return false
    }

    private mutating func record(_ summary: InputEventSummary, now: TimeInterval) {
        lastEmittedSummary = summary
        lastEmittedAt = now
    }
}

struct DiagnosticDisplayValue: Equatable, Sendable {
    var rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var isLocalizationKey: Bool {
        rawValue.hasPrefix("diagnostics.")
            || rawValue.hasPrefix("mapping.")
            || rawValue.hasPrefix("permissions.")
            || rawValue.hasPrefix("eventTap.")
            || rawValue.hasPrefix("login.")
    }
}

enum EventTapScrollDecision: Equatable, Sendable {
    case passOriginal
    case replace(ScrollTransformResult)
    case replaceAndSmooth(replacement: ScrollTransformResult, smooth: SmoothScrollRequest)
    case smooth(SmoothScrollRequest)
}

struct ScrollDirectionEngine {
    func transform(_ event: ScrollEventDescriptor, config: RuntimeConfigSnapshot) -> ScrollTransformResult {
        guard config.shouldHandleEvents,
              config.reverseMouseWheelEnabled,
              !event.isSyntheticFromThisApp else {
            return ScrollTransformResult(shouldHandle: false, deltaX: event.deltaX, deltaY: event.deltaY, pointDeltaX: event.pointDeltaX, pointDeltaY: event.pointDeltaY)
        }
        if config.preserveTrackpadDirection && event.deviceKind == .trackpad {
            return ScrollTransformResult(shouldHandle: false, deltaX: event.deltaX, deltaY: event.deltaY, pointDeltaX: event.pointDeltaX, pointDeltaY: event.pointDeltaY)
        }
        if event.deviceKind == .magicMouse && config.magicMouseScrollStrategy == .preserve {
            return ScrollTransformResult(shouldHandle: false, deltaX: event.deltaX, deltaY: event.deltaY, pointDeltaX: event.pointDeltaX, pointDeltaY: event.pointDeltaY)
        }
        let shouldTreatMagicMouseAsWheel = event.deviceKind == .magicMouse && config.magicMouseScrollStrategy == .reverseLikeMouse
        if config.physicalWheelOnly && !event.isPhysicalMouseWheel && !shouldTreatMagicMouseAsWheel {
            return ScrollTransformResult(shouldHandle: false, deltaX: event.deltaX, deltaY: event.deltaY, pointDeltaX: event.pointDeltaX, pointDeltaY: event.pointDeltaY)
        }

        var deltaX = event.deltaX
        var deltaY = event.deltaY
        var pointDeltaX = event.pointDeltaX
        var pointDeltaY = event.pointDeltaY
        if config.reverseVertical {
            deltaY = -deltaY
            pointDeltaY = -pointDeltaY
        }
        if config.reverseHorizontal {
            deltaX = -deltaX
            pointDeltaX = -pointDeltaX
        }
        return ScrollTransformResult(shouldHandle: true, deltaX: deltaX, deltaY: deltaY, pointDeltaX: pointDeltaX, pointDeltaY: pointDeltaY)
    }
}

struct EventTapScrollPipeline: Sendable {
    var syntheticMarker: Int64
    private let scrollEngine = ScrollDirectionEngine()

    func descriptor(from event: CGEvent) -> ScrollEventDescriptor {
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        return ScrollEventDescriptor(
            deltaX: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
            deltaY: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
            pointDeltaX: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2),
            pointDeltaY: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1),
            isContinuous: isContinuous,
            deviceKind: isContinuous ? .trackpad : .mouse,
            classificationConfidence: isContinuous ? 0.95 : 0.9,
            isSyntheticFromThisApp: event.getIntegerValueField(.eventSourceUserData) == syntheticMarker
        )
    }

    func decision(for event: CGEvent, config: RuntimeConfigSnapshot) -> EventTapScrollDecision {
        decision(for: descriptor(from: event), event: event, config: config)
    }

    func decision(for descriptor: ScrollEventDescriptor, event: CGEvent, config: RuntimeConfigSnapshot) -> EventTapScrollDecision {
        guard config.shouldHandleEvents,
              !descriptor.isSyntheticFromThisApp else {
            return .passOriginal
        }

        let result = scrollEngine.transform(descriptor, config: config)
        guard result.shouldHandle else { return .passOriginal }

        if config.smoothScrollingEnabled && config.smoothSteps > 1 && descriptor.isPhysicalMouseWheel {
            let pointY = result.pointDeltaY != 0 ? result.pointDeltaY : result.deltaY * 12
            let pointX = result.pointDeltaX != 0 ? result.pointDeltaX : result.deltaX * 12
            let shouldSmoothHorizontal = config.smoothHorizontalEnabled || pointX == 0
            let smoothDeltaX = shouldSmoothHorizontal ? pointX : 0
            guard smoothDeltaX != 0 || pointY != 0 else { return .replace(result) }
            if !shouldSmoothHorizontal, pointX != 0, pointY != 0 {
                let replacement = ScrollTransformResult(
                    shouldHandle: true,
                    deltaX: result.deltaX,
                    deltaY: 0,
                    pointDeltaX: result.pointDeltaX,
                    pointDeltaY: 0
                )
                return .replaceAndSmooth(
                    replacement: replacement,
                    smooth: SmoothScrollRequest(
                        deltaX: 0,
                        deltaY: pointY,
                        location: event.location
                    )
                )
            }
            return .smooth(
                SmoothScrollRequest(
                    deltaX: smoothDeltaX,
                    deltaY: pointY,
                    location: event.location
                )
            )
        }

        return .replace(result)
    }
}

struct SmoothScrollPlanner {
    func split(deltaX: Int64, deltaY: Int64, steps: Int, speedMultiplier: Double, curve: SmoothCurve = .easeOut, inertiaEnabled: Bool = false) -> [(x: Int32, y: Int32)] {
        let safeSteps = max(1, min(steps, 20))
        let multiplier = max(0.1, min(speedMultiplier, 5.0))
        let totalX = Int64((Double(deltaX) * multiplier).rounded())
        let totalY = Int64((Double(deltaY) * multiplier).rounded())
        guard safeSteps > 1 else { return [(Int32(clamping: totalX), Int32(clamping: totalY))] }

        var result: [(x: Int32, y: Int32)] = []
        var sentX: Int64 = 0
        var sentY: Int64 = 0
        for index in 1...safeSteps {
            let progress = curve.value(at: Double(index) / Double(safeSteps))
            let targetX = Int64((Double(totalX) * progress).rounded())
            let targetY = Int64((Double(totalY) * progress).rounded())
            let stepX = targetX - sentX
            let stepY = targetY - sentY
            sentX = targetX
            sentY = targetY
            if stepX != 0 || stepY != 0 {
                result.append((Int32(clamping: stepX), Int32(clamping: stepY)))
            }
        }
        if inertiaEnabled, let last = result.last {
            appendInertiaTail(from: last, to: &result)
        }
        return result.isEmpty ? [(0, 0)] : result
    }

    private func appendInertiaTail(from lastStep: (x: Int32, y: Int32), to result: inout [(x: Int32, y: Int32)]) {
        let firstTail = (x: lastStep.x / 2, y: lastStep.y / 2)
        let secondTail = (x: firstTail.x / 2, y: firstTail.y / 2)
        if firstTail.x != 0 || firstTail.y != 0 { result.append(firstTail) }
        if secondTail.x != 0 || secondTail.y != 0 { result.append(secondTail) }
    }

    func frameInterval(durationMilliseconds: Int, steps: Int) -> TimeInterval {
        let safeSteps = max(1, min(steps, 20))
        guard safeSteps > 1 else { return 0 }
        let safeDuration = max(40, min(durationMilliseconds, 240))
        return Double(safeDuration) / 1000 / Double(safeSteps)
    }
}

private extension SmoothCurve {
    func value(at progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        switch self {
        case .linear:
            return clamped
        case .easeOut:
            return 1 - pow(1 - clamped, 2)
        }
    }
}

final class SmoothScrollEngine: @unchecked Sendable {
    private let queue = DispatchQueue(label: "cn.phalfstudio.MouseBridge.smooth-scroll", qos: .userInteractive)
    private let marker: Int64
    private let planner = SmoothScrollPlanner()
    private var backpressureBuffer = SmoothScrollBackpressureBuffer()
    private var isDraining = false

    init(marker: Int64) {
        self.marker = marker
    }

    func enqueue(deltaX: Int64, deltaY: Int64, config: RuntimeConfigSnapshot, location: CGPoint) {
        let steps = planner.split(
            deltaX: deltaX,
            deltaY: deltaY,
            steps: config.smoothSteps,
            speedMultiplier: config.smoothSpeedMultiplier,
            curve: config.smoothCurve,
            inertiaEnabled: config.smoothInertiaEnabled
        )
        let interval = planner.frameInterval(durationMilliseconds: config.smoothDurationMilliseconds, steps: config.smoothSteps)
        queue.async {
            let nextSteps = steps.map { SmoothStep(x: $0.x, y: $0.y, location: location, interval: interval) }
            self.backpressureBuffer.append(nextSteps, fallbackLocation: location)
            guard !self.isDraining else { return }
            self.isDraining = true
            self.drainPendingSteps()
        }
    }

    private func drainPendingSteps() {
        let source = CGEventSource(stateID: .combinedSessionState)
        while let step = backpressureBuffer.popFirst() {
            autoreleasepool {
                guard let event = CGEvent(
                    scrollWheelEvent2Source: source,
                    units: .pixel,
                    wheelCount: 2,
                    wheel1: step.y,
                    wheel2: step.x,
                    wheel3: 0
                ) else { return }
                event.location = step.location
                event.setIntegerValueField(.eventSourceUserData, value: marker)
                event.post(tap: .cghidEventTap)
            }
            if step.interval > 0 {
                Thread.sleep(forTimeInterval: step.interval)
            }
        }
        isDraining = false
    }
}

struct ButtonMappingEngine {
    func mapping(for mouseButtonNumber: Int, config: RuntimeConfigSnapshot) -> ButtonMapping? {
        guard config.shouldHandleEvents, config.buttonMappingEnabled else { return nil }
        return config.buttonMappings.first { $0.isEnabled && $0.mouseButtonNumber == mouseButtonNumber }
    }

    func canInsert(_ mapping: ButtonMapping, into mappings: [ButtonMapping]) -> Bool {
        guard mapping.mouseButtonNumber >= 3 else { return false }
        return !mappings.contains { $0.id != mapping.id && $0.mouseButtonNumber == mapping.mouseButtonNumber }
    }
}

struct ButtonMappingConflictWarning {
    static func messageKey(for mapping: ButtonMapping, in mappings: [ButtonMapping]) -> String? {
        ButtonMappingEngine().canInsert(mapping, into: mappings) ? nil : "mapping.duplicateMouseButton"
    }
}

struct ShortcutEventPlanStep: Equatable, Sendable {
    var keyCode: UInt16
    var keyDown: Bool
    var flagsRawValue: UInt64
    var isMainKey: Bool
}

enum EventTapDisableReason: Equatable, Sendable {
    case timeout
    case userInput

    var diagnosticMessageKey: String {
        switch self {
        case .timeout:
            return "diagnostics.log.eventTapDisabledByTimeout"
        case .userInput:
            return "diagnostics.log.eventTapDisabledByUserInput"
        }
    }
}

enum EventTapRecoveryDecision: Equatable, Sendable {
    case reenable(after: TimeInterval)
    case stopWithFailure(message: String)
}

struct EventTapRecoveryPolicy: Equatable, Sendable {
    var maximumConsecutiveDisables = 3
    var timeoutRetryDelay: TimeInterval = 0.25
    var userInputRetryDelay: TimeInterval = 1.0
    private(set) var consecutiveDisables = 0

    mutating func recordSuccessfulStart() {
        consecutiveDisables = 0
    }

    mutating func recordDisabled(reason: EventTapDisableReason) -> EventTapRecoveryDecision {
        consecutiveDisables += 1
        guard consecutiveDisables < maximumConsecutiveDisables else {
            return .stopWithFailure(message: "diagnostics.log.eventTapDisabledRepeatedly")
        }
        switch reason {
        case .timeout:
            return .reenable(after: timeoutRetryDelay)
        case .userInput:
            return .reenable(after: userInputRetryDelay)
        }
    }
}

struct EventTapPerformanceSnapshot: Codable, Equatable, Sendable {
    var eventCount: Int
    var averageCallbackMilliseconds: Double
    var p95CallbackMilliseconds: Double
    var exceedsTarget: Bool

    static let empty = EventTapPerformanceSnapshot(
        eventCount: 0,
        averageCallbackMilliseconds: 0,
        p95CallbackMilliseconds: 0,
        exceedsTarget: false
    )
}

final class EventTapPerformanceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let maxSamples: Int
    private var callbackDurations: [Double] = []
    private var totalEventCount = 0

    init(maxSamples: Int = 500) {
        self.maxSamples = max(1, maxSamples)
    }

    func record(callbackDuration: TimeInterval) {
        let milliseconds = max(0, callbackDuration * 1000)
        lock.lock()
        totalEventCount += 1
        callbackDurations.append(milliseconds)
        if callbackDurations.count > maxSamples {
            callbackDurations.removeFirst(callbackDurations.count - maxSamples)
        }
        lock.unlock()
    }

    func snapshot() -> EventTapPerformanceSnapshot {
        lock.lock()
        let samples = callbackDurations
        let eventCount = totalEventCount
        lock.unlock()

        guard !samples.isEmpty else { return .empty }
        let average = samples.reduce(0, +) / Double(samples.count)
        let sortedSamples = samples.sorted()
        let p95Index = min(sortedSamples.count - 1, max(0, Int(ceil(Double(sortedSamples.count) * 0.95)) - 1))
        let p95 = sortedSamples[p95Index]
        return EventTapPerformanceSnapshot(
            eventCount: eventCount,
            averageCallbackMilliseconds: average,
            p95CallbackMilliseconds: p95,
            exceedsTarget: average > 1 || p95 > 2
        )
    }
}

struct ShortcutEventPlanner {
    private struct ModifierSpec {
        var keyCode: UInt16
        var flag: CGEventFlags
    }

    private let modifierOrder: [ModifierSpec] = [
        ModifierSpec(keyCode: 59, flag: .maskControl),
        ModifierSpec(keyCode: 58, flag: .maskAlternate),
        ModifierSpec(keyCode: 56, flag: .maskShift),
        ModifierSpec(keyCode: 55, flag: .maskCommand)
    ]

    func plan(for shortcut: KeyboardShortcutDefinition) -> [ShortcutEventPlanStep] {
        let requestedFlags = CGEventFlags(rawValue: shortcut.modifiersRawValue)
        var activeFlags: CGEventFlags = []
        var steps: [ShortcutEventPlanStep] = []

        for modifier in modifierOrder where requestedFlags.contains(modifier.flag) {
            activeFlags.insert(modifier.flag)
            steps.append(
                ShortcutEventPlanStep(
                    keyCode: modifier.keyCode,
                    keyDown: true,
                    flagsRawValue: activeFlags.rawValue,
                    isMainKey: false
                )
            )
        }

        steps.append(
            ShortcutEventPlanStep(
                keyCode: shortcut.keyCode,
                keyDown: true,
                flagsRawValue: activeFlags.rawValue,
                isMainKey: true
            )
        )
        steps.append(
            ShortcutEventPlanStep(
                keyCode: shortcut.keyCode,
                keyDown: false,
                flagsRawValue: activeFlags.rawValue,
                isMainKey: true
            )
        )

        for modifier in modifierOrder.reversed() where requestedFlags.contains(modifier.flag) {
            activeFlags.remove(modifier.flag)
            steps.append(
                ShortcutEventPlanStep(
                    keyCode: modifier.keyCode,
                    keyDown: false,
                    flagsRawValue: activeFlags.rawValue,
                    isMainKey: false
                )
            )
        }

        return steps
    }
}

final class KeyboardShortcutInjector: @unchecked Sendable {
    private let marker: Int64
    private let planner = ShortcutEventPlanner()

    init(marker: Int64) {
        self.marker = marker
    }

    func post(_ shortcut: KeyboardShortcutDefinition) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for step in planner.plan(for: shortcut) {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: step.keyCode, keyDown: step.keyDown) else {
                continue
            }
            event.flags = CGEventFlags(rawValue: step.flagsRawValue)
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.post(tap: .cghidEventTap)
        }
    }
}

struct SmoothStep: Equatable, Sendable {
    var x: Int32
    var y: Int32
    var location: CGPoint
    var interval: TimeInterval
}

struct SmoothScrollBackpressureBuffer: Equatable, Sendable {
    private let maxPendingSteps: Int
    private(set) var pendingSteps: [SmoothStep] = []

    init(maxPendingSteps: Int = 200) {
        self.maxPendingSteps = max(1, maxPendingSteps)
    }

    mutating func append(_ nextSteps: [SmoothStep], fallbackLocation: CGPoint) {
        guard !nextSteps.isEmpty else { return }
        if pendingSteps.count + nextSteps.count > maxPendingSteps {
            pendingSteps = [Self.mergedStep(pendingSteps + nextSteps, fallbackLocation: fallbackLocation)]
        } else {
            pendingSteps.append(contentsOf: nextSteps)
        }
    }

    mutating func popFirst() -> SmoothStep? {
        guard !pendingSteps.isEmpty else { return nil }
        return pendingSteps.removeFirst()
    }

    private static func mergedStep(_ steps: [SmoothStep], fallbackLocation: CGPoint) -> SmoothStep {
        let totalX = steps.reduce(Int64(0)) { $0 + Int64($1.x) }
        let totalY = steps.reduce(Int64(0)) { $0 + Int64($1.y) }
        return SmoothStep(
            x: Int32(clamping: totalX),
            y: Int32(clamping: totalY),
            location: steps.last?.location ?? fallbackLocation,
            interval: steps.last?.interval ?? 0
        )
    }
}

final class FrontmostApplicationProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var currentBundleIdentifier: String?
    private var observer: NSObjectProtocol?

    init(workspace: NSWorkspace = .shared) {
        currentBundleIdentifier = workspace.frontmostApplication?.bundleIdentifier
        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.update(bundleIdentifier: application?.bundleIdentifier)
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func bundleIdentifier() -> String? {
        lock.lock()
        let identifier = currentBundleIdentifier
        lock.unlock()
        return identifier
    }

    private func update(bundleIdentifier: String?) {
        lock.lock()
        currentBundleIdentifier = bundleIdentifier
        lock.unlock()
    }
}

enum EventTapError: Error, LocalizedError {
    case cannotCreateTap
    case cannotCreateRunLoopSource

    var diagnosticMessageKey: String {
        switch self {
        case .cannotCreateTap:
            return "diagnostics.error.cannotCreateEventTap"
        case .cannotCreateRunLoopSource:
            return "diagnostics.error.cannotCreateRunLoopSource"
        }
    }

    var errorDescription: String? {
        String(localized: String.LocalizationValue(diagnosticMessageKey))
    }
}

final class EventTapService: @unchecked Sendable {
    static let syntheticMarker: Int64 = 0x53425249444745
    static let eventsOfInterestMask =
        CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
        | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
        | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

    private let configBox = RuntimeConfigBox()
    private let scrollPipeline = EventTapScrollPipeline(syntheticMarker: EventTapService.syntheticMarker)
    private let smoothEngine = SmoothScrollEngine(marker: EventTapService.syntheticMarker)
    private let mappingEngine = ButtonMappingEngine()
    private let shortcutInjector = KeyboardShortcutInjector(marker: EventTapService.syntheticMarker)
    private let frontmostApplicationProvider = FrontmostApplicationProvider()
    private let performanceRecorder = EventTapPerformanceRecorder()
    private let eventSummaryLock = NSLock()
    private let logger = Logger(subsystem: "cn.phalfstudio.MouseBridge", category: "EventTap")
    private var recoveryPolicy = EventTapRecoveryPolicy()
    private var eventSummaryRateLimiter = InputEventSummaryRateLimiter()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var statusHandler: (@Sendable (EventTapRuntimeStatus, String?) -> Void)?
    var eventHandler: (@Sendable (InputEventSummary) -> Void)?

    func start(with config: RuntimeConfigSnapshot) throws {
        configBox.update(config)
        guard config.shouldHandleEvents else {
            stop()
            statusHandler?(config.inactiveEventTapStatus, nil)
            return
        }
        if eventTap != nil {
            statusHandler?(.running, nil)
            return
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventsOfInterestMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            statusHandler?(.failed, EventTapError.cannotCreateTap.diagnosticMessageKey)
            throw EventTapError.cannotCreateTap
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            statusHandler?(.failed, EventTapError.cannotCreateRunLoopSource.diagnosticMessageKey)
            throw EventTapError.cannotCreateRunLoopSource
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        recoveryPolicy.recordSuccessfulStart()
        statusHandler?(.running, nil)
        logger.info("Event tap started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
        statusHandler?(.stopped, nil)
    }

    func updateConfig(_ config: RuntimeConfigSnapshot) {
        configBox.update(config)
        if !config.shouldHandleEvents {
            stop()
            statusHandler?(config.inactiveEventTapStatus, nil)
        } else if eventTap == nil {
            try? start(with: config)
        }
    }

    func performanceSnapshot() -> EventTapPerformanceSnapshot {
        performanceRecorder.snapshot()
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        defer {
            let endedAt = DispatchTime.now().uptimeNanoseconds
            performanceRecorder.record(callbackDuration: Double(endedAt - startedAt) / 1_000_000_000)
        }
        if type == .tapDisabledByTimeout {
            handleTapDisabled(reason: .timeout)
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByUserInput {
            handleTapDisabled(reason: .userInput)
            return Unmanaged.passUnretained(event)
        }

        let config = configBox.snapshot()
        guard config.shouldHandleEvents else { return Unmanaged.passUnretained(event) }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }
        guard config.shouldHandleEvents(for: frontmostApplicationProvider.bundleIdentifier()) else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .scrollWheel:
            return handleScroll(event: event, config: config)
        case .otherMouseDown, .otherMouseUp:
            return handleMouseButton(type: type, event: event, config: config)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleTapDisabled(reason: EventTapDisableReason) {
        let status: EventTapRuntimeStatus
        switch reason {
        case .timeout:
            status = .disabledByTimeout
        case .userInput:
            status = .disabledByUserInput
        }

        switch recoveryPolicy.recordDisabled(reason: reason) {
        case .reenable(let delay):
            statusHandler?(status, reason.diagnosticMessageKey)
            scheduleTapReenable(after: delay)
        case .stopWithFailure(let failureMessage):
            stop()
            statusHandler?(.failed, failureMessage)
        }
    }

    private func scheduleTapReenable(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let eventTap = self.eventTap else { return }
            CGEvent.tapEnable(tap: eventTap, enable: true)
            self.statusHandler?(.running, nil)
        }
    }

    private func handleScroll(event: CGEvent, config: RuntimeConfigSnapshot) -> Unmanaged<CGEvent>? {
        let descriptor = scrollPipeline.descriptor(from: event)
        emitEventSummary(descriptor.isContinuous ? .trackpadScroll : .physicalMouseWheel)
        switch scrollPipeline.decision(for: descriptor, event: event, config: config) {
        case .passOriginal:
            return Unmanaged.passUnretained(event)
        case .smooth(let request):
            smoothEngine.enqueue(
                deltaX: request.deltaX,
                deltaY: request.deltaY,
                config: config,
                location: request.location
            )
            return nil
        case .replace(let result):
            guard let modified = event.copy() else { return Unmanaged.passUnretained(event) }
            applyScroll(result, to: modified)
            return Unmanaged.passRetained(modified)
        case .replaceAndSmooth(let replacement, let request):
            smoothEngine.enqueue(
                deltaX: request.deltaX,
                deltaY: request.deltaY,
                config: config,
                location: request.location
            )
            guard let modified = event.copy() else { return Unmanaged.passUnretained(event) }
            applyScroll(replacement, to: modified)
            return Unmanaged.passRetained(modified)
        }
    }

    private func handleMouseButton(type: CGEventType, event: CGEvent, config: RuntimeConfigSnapshot) -> Unmanaged<CGEvent>? {
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber)) + 1
        emitEventSummary(.mouseButton(buttonNumber))
        guard let mapping = mappingEngine.mapping(for: buttonNumber, config: config) else {
            return Unmanaged.passUnretained(event)
        }
        if type == .otherMouseDown {
            shortcutInjector.post(mapping.shortcut)
        }
        return nil
    }

    private func applyScroll(_ result: ScrollTransformResult, to event: CGEvent) {
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: result.deltaY)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: result.deltaX)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: result.pointDeltaY)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: result.pointDeltaX)
    }

    private func emitEventSummary(_ summary: InputEventSummary) {
        eventSummaryLock.lock()
        let shouldEmit = eventSummaryRateLimiter.shouldEmit(summary, now: ProcessInfo.processInfo.systemUptime)
        eventSummaryLock.unlock()
        if shouldEmit {
            eventHandler?(summary)
        }
    }
}

private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<EventTapService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handle(proxy: proxy, type: type, event: event)
}
