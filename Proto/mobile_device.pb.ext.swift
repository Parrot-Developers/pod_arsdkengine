// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkMobiledeviceEventDecoder`.
protocol ArsdkMobiledeviceEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Mobiledevice_Event.Capabilities` event.
    ///
    /// - Parameter capabilities: event to process
    func onCapabilities(_ capabilities: Arsdk_Mobiledevice_Event.Capabilities)
}

/// Decoder for arsdk.mobiledevice.Event events.
class ArsdkMobiledeviceEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.mobiledevice.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkMobiledeviceEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkMobiledeviceEventDecoderListener) {
       self.listener = listener
    }

    /// Decodes an event.
    ///
    /// - Parameter event: event to decode
    func decode(_ event: OpaquePointer) {
       if ArsdkCommand.getFeatureId(event) == kArsdkFeatureGenericUid {
            ArsdkFeatureGeneric.decode(event, callback: self)
        }
    }

    func onCustomEvtNonAck(serviceId: UInt, msgNum: UInt, payload: Data) {
        processEvent(serviceId: serviceId, payload: payload, isNonAck: true)
    }

    func onCustomEvt(serviceId: UInt, msgNum: UInt, payload: Data) {
        processEvent(serviceId: serviceId, payload: payload, isNonAck: false)
    }

    /// Processes a custom event.
    ///
    /// - Parameters:
    ///    - serviceId: service identifier
    ///    - payload: event payload
    private func processEvent(serviceId: UInt, payload: Data, isNonAck: Bool) {
        guard serviceId == ArsdkMobiledeviceEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Mobiledevice_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkMobiledeviceEventDecoder event \(event)")
            }
            switch event.id {
            case .capabilities(let event):
                listener?.onCapabilities(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Mobiledevice_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Mobiledevice_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .capabilities: return 16
        }
    }
}

/// Decoder for arsdk.mobiledevice.Command commands.
class ArsdkMobiledeviceCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.mobiledevice.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Mobiledevice_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkMobiledeviceCommandEncoder command \(command)")
        var message = Arsdk_Mobiledevice_Command()
        message.id = command
        if let payload = try? message.serializedData() {
            return ArsdkFeatureGeneric.customCmdEncoder(serviceId: serviceId,
                                                        msgNum: UInt(command.number),
                                                        payload: payload)
        }
        return nil
    }
}

/// Extension to get command field number.
extension Arsdk_Mobiledevice_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .batteryState: return 1
        case .location: return 2
        case .getCapabilities: return 16
        }
    }
}
extension Arsdk_Mobiledevice_Command.BatteryState {
    static var chargeLevelFieldNumber: Int32 { 1 }
}
extension Arsdk_Mobiledevice_Command.Location {
    static var sourceFieldNumber: Int32 { 1 }
    static var timestampFieldNumber: Int32 { 2 }
    static var numberOfSatellitesFieldNumber: Int32 { 3 }
    static var latitudeFieldNumber: Int32 { 4 }
    static var longitudeFieldNumber: Int32 { 5 }
    static var wgs84AltitudeFieldNumber: Int32 { 6 }
    static var amslAltitudeFieldNumber: Int32 { 7 }
    static var latitudeAccuracyFieldNumber: Int32 { 8 }
    static var longitudeAccuracyFieldNumber: Int32 { 9 }
    static var wgs84AltitudeAccuracyFieldNumber: Int32 { 10 }
    static var amslAltitudeAccuracyFieldNumber: Int32 { 11 }
    static var northVelocityFieldNumber: Int32 { 12 }
    static var eastVelocityFieldNumber: Int32 { 13 }
    static var upVelocityFieldNumber: Int32 { 14 }
    static var velocityAccuracyFieldNumber: Int32 { 15 }
}
extension Arsdk_Mobiledevice_Command {
    static var batteryStateFieldNumber: Int32 { 1 }
    static var locationFieldNumber: Int32 { 2 }
    static var getCapabilitiesFieldNumber: Int32 { 16 }
}
extension Arsdk_Mobiledevice_Event.Capabilities {
    static var supportedFeaturesFieldNumber: Int32 { 1 }
}
extension Arsdk_Mobiledevice_Event {
    static var capabilitiesFieldNumber: Int32 { 16 }
}
