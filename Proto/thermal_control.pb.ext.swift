// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkThermalcontrolEventDecoder`.
protocol ArsdkThermalcontrolEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Thermalcontrol_Event.Capabilities` event.
    ///
    /// - Parameter defaultCapabilities: event to process
    func onDefaultCapabilities(_ defaultCapabilities: Arsdk_Thermalcontrol_Event.Capabilities)

    /// Processes a `Arsdk_Thermalcontrol_Event.UniformtiyCalibrationState` event.
    ///
    /// - Parameter calibrationState: event to process
    func onCalibrationState(_ calibrationState: Arsdk_Thermalcontrol_Event.UniformtiyCalibrationState)

    /// Processes a `Arsdk_Thermalcontrol_PowerSavingMode` event.
    ///
    /// - Parameter powerSaving: event to process
    func onPowerSaving(_ powerSaving: Arsdk_Thermalcontrol_PowerSavingMode)
}

/// Decoder for arsdk.thermalcontrol.Event events.
class ArsdkThermalcontrolEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.thermalcontrol.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkThermalcontrolEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkThermalcontrolEventDecoderListener) {
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
        guard serviceId == ArsdkThermalcontrolEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Thermalcontrol_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkThermalcontrolEventDecoder event \(event)")
            }
            switch event.id {
            case .defaultCapabilities(let event):
                listener?.onDefaultCapabilities(event)
            case .calibrationState(let event):
                listener?.onCalibrationState(event)
            case .powerSaving(let event):
                listener?.onPowerSaving(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Thermalcontrol_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Thermalcontrol_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .defaultCapabilities: return 16
        case .calibrationState: return 17
        case .powerSaving: return 18
        }
    }
}

/// Decoder for arsdk.thermalcontrol.Command commands.
class ArsdkThermalcontrolCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.thermalcontrol.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Thermalcontrol_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkThermalcontrolCommandEncoder command \(command)")
        var message = Arsdk_Thermalcontrol_Command()
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
extension Arsdk_Thermalcontrol_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .getCapabilities: return 17
        case .startCalibration: return 18
        case .abortCalibration: return 19
        case .userCalibration: return 20
        case .setPowerSaving: return 21
        }
    }
}
extension Arsdk_Thermalcontrol_Command.SetPowerSaving {
    static var modeFieldNumber: Int32 { 1 }
}
extension Arsdk_Thermalcontrol_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var getCapabilitiesFieldNumber: Int32 { 17 }
    static var startCalibrationFieldNumber: Int32 { 18 }
    static var abortCalibrationFieldNumber: Int32 { 19 }
    static var userCalibrationFieldNumber: Int32 { 20 }
    static var setPowerSavingFieldNumber: Int32 { 21 }
}
extension Arsdk_Thermalcontrol_Event.Capabilities {
    static var powersavingModesFieldNumber: Int32 { 1 }
}
extension Arsdk_Thermalcontrol_Event.UniformtiyCalibrationState {
    static var stepFieldNumber: Int32 { 1 }
    static var requireUserActionFieldNumber: Int32 { 2 }
}
extension Arsdk_Thermalcontrol_Event {
    static var defaultCapabilitiesFieldNumber: Int32 { 16 }
    static var calibrationStateFieldNumber: Int32 { 17 }
    static var powerSavingFieldNumber: Int32 { 18 }
}
