// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkCalibrationEventDecoder`.
protocol ArsdkCalibrationEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Calibration_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Calibration_Event.State)
}

/// Decoder for arsdk.calibration.Event events.
class ArsdkCalibrationEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.calibration.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkCalibrationEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkCalibrationEventDecoderListener) {
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
        guard serviceId == ArsdkCalibrationEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Calibration_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkCalibrationEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Calibration_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Calibration_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.calibration.Command commands.
class ArsdkCalibrationCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.calibration.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Calibration_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkCalibrationCommandEncoder command \(command)")
        var message = Arsdk_Calibration_Command()
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
extension Arsdk_Calibration_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .calibrate: return 17
        }
    }
}
extension Arsdk_Calibration_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Calibration_Command.Calibrate {
    static var sensorFieldNumber: Int32 { 1 }
    static var valueFieldNumber: Int32 { 2 }
}
extension Arsdk_Calibration_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var calibrateFieldNumber: Int32 { 17 }
}
extension Arsdk_Calibration_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var calibrationStateListFieldNumber: Int32 { 2 }
}
extension Arsdk_Calibration_Event.Capabilities {
    static var supportedSensorsFieldNumber: Int32 { 1 }
}
extension Arsdk_Calibration_Event.CalibrationStateList {
    static var calibrationStateFieldNumber: Int32 { 1 }
}
extension Arsdk_Calibration_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Calibration_CalibrationState {
    static var sensorFieldNumber: Int32 { 1 }
    static var statusFieldNumber: Int32 { 2 }
    static var isRequiredFieldNumber: Int32 { 3 }
}
