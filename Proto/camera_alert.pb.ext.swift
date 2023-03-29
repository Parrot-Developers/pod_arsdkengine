// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkCameraAlertEventDecoder`.
protocol ArsdkCameraAlertEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Camera_Alert_Event.TooDark` event.
    ///
    /// - Parameter tooDark: event to process
    func onTooDark(_ tooDark: Arsdk_Camera_Alert_Event.TooDark)

    /// Processes a `Arsdk_Camera_Alert_Event.SensorFailure` event.
    ///
    /// - Parameter sensorFailure: event to process
    func onSensorFailure(_ sensorFailure: Arsdk_Camera_Alert_Event.SensorFailure)
}

/// Decoder for arsdk.camera.alert.Event events.
class ArsdkCameraAlertEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.camera.alert.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkCameraAlertEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkCameraAlertEventDecoderListener) {
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

    func onCustomEvt(serviceId: UInt, msgNum: UInt, payload: Data!) {
        processEvent(serviceId: serviceId, payload: payload, isNonAck: false)
    }

    /// Processes a custom event.
    ///
    /// - Parameters:
    ///    - serviceId: service identifier
    ///    - payload: event payload
    private func processEvent(serviceId: UInt, payload: Data, isNonAck: Bool) {
        guard serviceId == ArsdkCameraAlertEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Camera_Alert_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkCameraAlertEventDecoder event \(event)")
            }
            switch event.id {
            case .tooDark(let event):
                listener?.onTooDark(event)
            case .sensorFailure(let event):
                listener?.onSensorFailure(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Camera_Alert_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Camera_Alert_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .tooDark: return 16
        case .sensorFailure: return 17
        }
    }
}

/// Decoder for arsdk.camera.alert.Command commands.
class ArsdkCameraAlertCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.camera.alert.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Camera_Alert_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkCameraAlertCommandEncoder command \(command)")
        var message = Arsdk_Camera_Alert_Command()
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
extension Arsdk_Camera_Alert_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getAlerts: return 16
        }
    }
}
extension Arsdk_Camera_Alert_Command {
    static var getAlertsFieldNumber: Int32 { 16 }
}
extension Arsdk_Camera_Alert_Event.TooDark {
    static var stateFieldNumber: Int32 { 1 }
    static var cameraFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Alert_Event.SensorFailure {
    static var stateFieldNumber: Int32 { 1 }
    static var cameraFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Alert_Event {
    static var tooDarkFieldNumber: Int32 { 16 }
    static var sensorFailureFieldNumber: Int32 { 17 }
}
