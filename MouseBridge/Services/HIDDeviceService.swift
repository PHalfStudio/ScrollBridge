import Foundation
import IOKit.hid

struct HIDDeviceClassification: Equatable, Sendable {
    var kind: InputDeviceKind
    var confidence: Double
    var isStandardHID: Bool
}

struct HIDDeviceClassifier {
    func classify(name: String, usagePage: Int?, usage: Int?) -> HIDDeviceClassification {
        let lowerName = name.lowercased()
        if lowerName.contains("magic mouse") {
            return HIDDeviceClassification(kind: .magicMouse, confidence: 0.95, isStandardHID: true)
        }
        if lowerName.contains("trackpad") {
            return HIDDeviceClassification(kind: .trackpad, confidence: 0.95, isStandardHID: true)
        }
        if usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Mouse {
            return HIDDeviceClassification(kind: .mouse, confidence: 0.9, isStandardHID: true)
        }
        if usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Keyboard {
            return HIDDeviceClassification(kind: .keyboard, confidence: 0.9, isStandardHID: true)
        }
        if usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Pointer {
            return HIDDeviceClassification(kind: .mouse, confidence: 0.65, isStandardHID: true)
        }
        return HIDDeviceClassification(kind: .unknown, confidence: 0.2, isStandardHID: false)
    }

    func resolve(
        deviceID: String,
        detected: HIDDeviceClassification,
        overrides: [String: InputDeviceKind]
    ) -> HIDDeviceClassification {
        guard let override = overrides[deviceID] else { return detected }
        return HIDDeviceClassification(kind: override, confidence: 1.0, isStandardHID: detected.isStandardHID)
    }
}

final class HIDDeviceService {
    private let classifier = HIDDeviceClassifier()

    func snapshotDevices(overrides: [String: InputDeviceKind]) -> [DeviceProfile] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, nil)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else { return [] }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return deviceSet.map { device in
            makeProfile(for: device, overrides: overrides)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func makeProfile(for device: IOHIDDevice, overrides: [String: InputDeviceKind]) -> DeviceProfile {
        let name = stringProperty(kIOHIDProductKey as CFString, device: device)
            ?? stringProperty(kIOHIDManufacturerKey as CFString, device: device)
            ?? "Unknown HID Device"
        let vendorID = intProperty(kIOHIDVendorIDKey as CFString, device: device)
        let productID = intProperty(kIOHIDProductIDKey as CFString, device: device)
        let usagePage = intProperty(kIOHIDPrimaryUsagePageKey as CFString, device: device)
        let usage = intProperty(kIOHIDPrimaryUsageKey as CFString, device: device)
        let transport = stringProperty(kIOHIDTransportKey as CFString, device: device) ?? ""
        let id = Self.deviceIdentifier(name: name, vendorID: vendorID, productID: productID)
        let detected = classifier.classify(name: name, usagePage: usagePage, usage: usage)
        let resolved = classifier.resolve(deviceID: id, detected: detected, overrides: overrides)
        return DeviceProfile(
            id: id,
            name: name,
            vendorID: vendorID,
            productID: productID,
            transport: transport,
            usagePage: usagePage,
            usage: usage,
            isStandardHID: resolved.isStandardHID,
            kind: resolved.kind,
            confidence: resolved.confidence
        )
    }

    static func deviceIdentifier(name: String, vendorID: Int?, productID: Int?) -> String {
        "\(vendorID ?? -1):\(productID ?? -1):\(name)"
    }

    private func stringProperty(_ key: CFString, device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, key) as? String
    }

    private func intProperty(_ key: CFString, device: IOHIDDevice) -> Int? {
        if let number = IOHIDDeviceGetProperty(device, key) as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
