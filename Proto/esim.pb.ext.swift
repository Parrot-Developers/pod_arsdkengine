// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkEsimEventDecoder`.
protocol ArsdkEsimEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Esim_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Esim_Event.State)

    /// Processes a `Arsdk_Esim_Event.HttpRequest` event.
    ///
    /// - Parameter httpRequest: event to process
    func onHttpRequest(_ httpRequest: Arsdk_Esim_Event.HttpRequest)
}

/// Decoder for arsdk.esim.Event events.
class ArsdkEsimEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.esim.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkEsimEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkEsimEventDecoderListener) {
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
        guard serviceId == ArsdkEsimEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Esim_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkEsimEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .httpRequest(let event):
                listener?.onHttpRequest(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Esim_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Esim_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        case .httpRequest: return 20
        }
    }
}

/// Decoder for arsdk.esim.Command commands.
class ArsdkEsimCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.esim.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Esim_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkEsimCommandEncoder command \(command)")
        var message = Arsdk_Esim_Command()
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
extension Arsdk_Esim_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .downloadProfile: return 17
        case .enableProfile: return 18
        case .deleteProfile: return 19
        case .httpResponse: return 20
        }
    }
}
extension Arsdk_Esim_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Esim_Command.DownloadProfile {
    static var activationCodeFieldNumber: Int32 { 1 }
    static var confirmationCodeFieldNumber: Int32 { 2 }
}
extension Arsdk_Esim_Command.EnableProfile {
    static var iccidFieldNumber: Int32 { 1 }
    static var enableFieldNumber: Int32 { 2 }
}
extension Arsdk_Esim_Command.DeleteProfile {
    static var iccidFieldNumber: Int32 { 1 }
}
extension Arsdk_Esim_Command.HttpResponse {
    static var idFieldNumber: Int32 { 1 }
    static var codeFieldNumber: Int32 { 2 }
    static var errorCodeFieldNumber: Int32 { 3 }
    static var messageFieldNumber: Int32 { 4 }
    static var dataFieldNumber: Int32 { 5 }
}
extension Arsdk_Esim_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var downloadProfileFieldNumber: Int32 { 17 }
    static var enableProfileFieldNumber: Int32 { 18 }
    static var deleteProfileFieldNumber: Int32 { 19 }
    static var httpResponseFieldNumber: Int32 { 20 }
}
extension Arsdk_Esim_Event.State {
    static var simStatusValueFieldNumber: Int32 { 2 }
    static var eidFieldNumber: Int32 { 3 }
    static var profileListFieldNumber: Int32 { 4 }
    static var profileOperationStatusFieldNumber: Int32 { 5 }
}
extension Arsdk_Esim_Event.HttpRequest {
    static var idFieldNumber: Int32 { 1 }
    static var urlFieldNumber: Int32 { 2 }
    static var headersFieldNumber: Int32 { 3 }
    static var dataFieldNumber: Int32 { 4 }
}
extension Arsdk_Esim_Event {
    static var stateFieldNumber: Int32 { 16 }
    static var httpRequestFieldNumber: Int32 { 20 }
}
extension Arsdk_Esim_Profile {
    static var iccidFieldNumber: Int32 { 1 }
    static var providerFieldNumber: Int32 { 2 }
    static var enabledFieldNumber: Int32 { 3 }
}
extension Arsdk_Esim_ProfileOperationStatus {
    static var errorCodeFieldNumber: Int32 { 1 }
    static var downloadProfileStatusFieldNumber: Int32 { 2 }
    static var enableProfileStatusFieldNumber: Int32 { 3 }
    static var deleteProfileStatusFieldNumber: Int32 { 4 }
}
extension Arsdk_Esim_DownloadProfileStatus {
    static var profileFieldNumber: Int32 { 1 }
}
extension Arsdk_Esim_EnableProfileStatus {
    static var iccidFieldNumber: Int32 { 1 }
    static var enabledFieldNumber: Int32 { 2 }
}
extension Arsdk_Esim_DeleteProfileStatus {
    static var iccidFieldNumber: Int32 { 1 }
}
extension Arsdk_Esim_ProfileList {
    static var profilesFieldNumber: Int32 { 1 }
}
extension Arsdk_Esim_SimStatusValue {
    static var valueFieldNumber: Int32 { 1 }
}
