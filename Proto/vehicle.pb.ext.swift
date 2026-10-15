// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkVehicleEventDecoder`.
protocol ArsdkVehicleEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Vehicle_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Vehicle_Event.State)
}

/// Decoder for arsdk.vehicle.Event events.
class ArsdkVehicleEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.vehicle.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkVehicleEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkVehicleEventDecoderListener) {
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
        guard serviceId == ArsdkVehicleEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Vehicle_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkVehicleEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Vehicle_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Vehicle_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.vehicle.Command commands.
class ArsdkVehicleCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.vehicle.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Vehicle_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkVehicleCommandEncoder command \(command)")
        var message = Arsdk_Vehicle_Command()
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
extension Arsdk_Vehicle_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .enable: return 17
        case .enableRelativeGuidance: return 18
        case .enablePreciseCalibration: return 19
        case .wipePreciseCalibration: return 20
        case .setPlateformType: return 21
        }
    }
}
extension Arsdk_Vehicle_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_Command.Enable {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_Command.EnableRelativeGuidance {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_Command.EnablePreciseCalibration {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_Command.SetPlatformType {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var enableFieldNumber: Int32 { 17 }
    static var enableRelativeGuidanceFieldNumber: Int32 { 18 }
    static var enablePreciseCalibrationFieldNumber: Int32 { 19 }
    static var wipePreciseCalibrationFieldNumber: Int32 { 20 }
    static var setPlateformTypeFieldNumber: Int32 { 21 }
}
extension Arsdk_Vehicle_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var isEnabledFieldNumber: Int32 { 2 }
    static var missingRequirementsFieldNumber: Int32 { 3 }
    static var improvementsFieldNumber: Int32 { 4 }
    static var notificationsFieldNumber: Int32 { 5 }
    static var relativeGuidanceFieldNumber: Int32 { 6 }
    static var isPreciseCalibrationEnabledFieldNumber: Int32 { 7 }
    static var platformTypeFieldNumber: Int32 { 8 }
}
extension Arsdk_Vehicle_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Vehicle_Capabilities {
    static var maxHorizontalDistanceFieldNumber: Int32 { 1 }
    static var supportedPlatformTypesFieldNumber: Int32 { 2 }
}
extension Arsdk_Vehicle_MissingRequirements {
    static var requirementsFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_Improvements {
    static var improvementsFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_Notifications {
    static var notificationsFieldNumber: Int32 { 1 }
}
extension Arsdk_Vehicle_RelativeGuidance {
    static var isEnabledFieldNumber: Int32 { 1 }
    static var isModifiableFieldNumber: Int32 { 2 }
}
extension Arsdk_Vehicle_PlatformTypeValue {
    static var valueFieldNumber: Int32 { 1 }
}
