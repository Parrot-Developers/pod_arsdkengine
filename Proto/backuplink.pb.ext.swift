// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkBackuplinkEventDecoder`.
protocol ArsdkBackuplinkEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Backuplink_Event.Telemetry` event.
    ///
    /// - Parameter telemetry: event to process
    func onTelemetry(_ telemetry: Arsdk_Backuplink_Event.Telemetry)

    /// Processes a `SwiftProtobuf.Google_Protobuf_Empty` event.
    ///
    /// - Parameter mainRadioDisconnecting: event to process
    func onMainRadioDisconnecting(_ mainRadioDisconnecting: SwiftProtobuf.Google_Protobuf_Empty)
}

/// Decoder for arsdk.backuplink.Event events.
class ArsdkBackuplinkEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.backuplink.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkBackuplinkEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkBackuplinkEventDecoderListener) {
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
        guard serviceId == ArsdkBackuplinkEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Backuplink_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkBackuplinkEventDecoder event \(event)")
            }
            switch event.id {
            case .telemetry(let event):
                listener?.onTelemetry(event)
            case .mainRadioDisconnecting(let event):
                listener?.onMainRadioDisconnecting(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Backuplink_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Backuplink_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .telemetry: return 1
        case .mainRadioDisconnecting: return 16
        }
    }
}
extension Arsdk_Backuplink_Event.Telemetry {
    static var flyingStateFieldNumber: Int32 { 1 }
    static var batteryChargeFieldNumber: Int32 { 2 }
    static var speedFieldNumber: Int32 { 3 }
    static var headingFieldNumber: Int32 { 4 }
    static var altitudeAtoFieldNumber: Int32 { 5 }
    static var latitudeFieldNumber: Int32 { 6 }
    static var longitudeFieldNumber: Int32 { 7 }
    static var locationUsesGnssFieldNumber: Int32 { 8 }
    static var locationIsReliableFieldNumber: Int32 { 9 }
    static var locationUsesMagnetometerFieldNumber: Int32 { 10 }
}
extension Arsdk_Backuplink_Event {
    static var telemetryFieldNumber: Int32 { 1 }
    static var mainRadioDisconnectingFieldNumber: Int32 { 16 }
}
extension Arsdk_Backuplink_Band {
    static var minFrequencyFieldNumber: Int32 { 1 }
    static var maxFrequencyFieldNumber: Int32 { 2 }
}
extension Arsdk_Backuplink_Bands {
    static var bandsFieldNumber: Int32 { 1 }
}
extension Arsdk_Backuplink_LinkInfo {
    static var stateFieldNumber: Int32 { 1 }
    static var rxActiveFieldNumber: Int32 { 2 }
    static var txActiveFieldNumber: Int32 { 3 }
}
extension Arsdk_Backuplink_Frequencies {
    static var frequenciesFieldNumber: Int32 { 1 }
}
