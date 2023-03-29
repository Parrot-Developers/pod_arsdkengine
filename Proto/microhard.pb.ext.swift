// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkMicrohardEventDecoder`.
protocol ArsdkMicrohardEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Microhard_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Microhard_Event.State)

    /// Processes a `Arsdk_Microhard_Event.HardwareError` event.
    ///
    /// - Parameter hardwareError: event to process
    func onHardwareError(_ hardwareError: Arsdk_Microhard_Event.HardwareError)

    /// Processes a `Arsdk_Microhard_Event.Pairing` event.
    ///
    /// - Parameter pairing: event to process
    func onPairing(_ pairing: Arsdk_Microhard_Event.Pairing)
}

/// Decoder for arsdk.microhard.Event events.
class ArsdkMicrohardEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.microhard.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkMicrohardEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkMicrohardEventDecoderListener) {
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
        guard serviceId == ArsdkMicrohardEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Microhard_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkMicrohardEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .hardwareError(let event):
                listener?.onHardwareError(event)
            case .pairing(let event):
                listener?.onPairing(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Microhard_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Microhard_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        case .hardwareError: return 18
        case .pairing: return 19
        }
    }
}

/// Decoder for arsdk.microhard.Command commands.
class ArsdkMicrohardCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.microhard.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Microhard_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkMicrohardCommandEncoder command \(command)")
        var message = Arsdk_Microhard_Command()
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
extension Arsdk_Microhard_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .powerOn: return 17
        case .shutdown: return 18
        case .pairDevice: return 19
        }
    }
}
extension Arsdk_Microhard_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Microhard_Command.PairDevice {
    static var networkIdFieldNumber: Int32 { 1 }
    static var encryptionKeyFieldNumber: Int32 { 2 }
    static var pairingParametersFieldNumber: Int32 { 3 }
    static var connectionParametersFieldNumber: Int32 { 4 }
}
extension Arsdk_Microhard_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var powerOnFieldNumber: Int32 { 17 }
    static var shutdownFieldNumber: Int32 { 18 }
    static var pairDeviceFieldNumber: Int32 { 19 }
}
extension Arsdk_Microhard_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var offlineFieldNumber: Int32 { 2 }
    static var bootingFieldNumber: Int32 { 3 }
    static var idleFieldNumber: Int32 { 4 }
    static var pairingFieldNumber: Int32 { 5 }
    static var connectingFieldNumber: Int32 { 6 }
    static var connectedFieldNumber: Int32 { 7 }
}
extension Arsdk_Microhard_Event.HardwareError {
    static var causeFieldNumber: Int32 { 1 }
}
extension Arsdk_Microhard_Event.Pairing {
    static var failureFieldNumber: Int32 { 1 }
    static var successFieldNumber: Int32 { 2 }
    static var networkIdFieldNumber: Int32 { 3 }
}
extension Arsdk_Microhard_Event {
    static var stateFieldNumber: Int32 { 16 }
    static var hardwareErrorFieldNumber: Int32 { 18 }
    static var pairingFieldNumber: Int32 { 19 }
}
extension Arsdk_Microhard_Capabilities {
    static var channelMinFieldNumber: Int32 { 1 }
    static var channelMaxFieldNumber: Int32 { 2 }
    static var powerMinFieldNumber: Int32 { 3 }
    static var powerMaxFieldNumber: Int32 { 4 }
    static var bandwidthsFieldNumber: Int32 { 5 }
    static var encryptionAlgorithmsFieldNumber: Int32 { 6 }
    static var modelFieldNumber: Int32 { 7 }
}
extension Arsdk_Microhard_ConnectionParameters {
    static var channelFieldNumber: Int32 { 1 }
    static var powerFieldNumber: Int32 { 2 }
    static var bandwidthFieldNumber: Int32 { 3 }
}
extension Arsdk_Microhard_State.Pairing {
    static var networkIdFieldNumber: Int32 { 1 }
    static var pairingParametersFieldNumber: Int32 { 2 }
    static var connectionParametersFieldNumber: Int32 { 3 }
}
extension Arsdk_Microhard_State.Connecting {
    static var deviceUidFieldNumber: Int32 { 1 }
}
extension Arsdk_Microhard_State.Connected {
    static var deviceUidFieldNumber: Int32 { 1 }
}
extension Arsdk_Microhard_PairingParameters {
    static var channelFieldNumber: Int32 { 1 }
    static var powerFieldNumber: Int32 { 2 }
    static var bandwidthFieldNumber: Int32 { 3 }
    static var encryptionAlgorithmFieldNumber: Int32 { 4 }
}
extension Arsdk_Microhard_PairingStatus.Failure {
    static var reasonFieldNumber: Int32 { 1 }
}
extension Arsdk_Microhard_PairingStatus.Success {
    static var deviceUidFieldNumber: Int32 { 1 }
}
