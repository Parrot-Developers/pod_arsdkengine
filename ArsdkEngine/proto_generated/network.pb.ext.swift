// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkNetworkEventDecoder`.
protocol ArsdkNetworkEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Network_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Network_Event.State)
}

/// Decoder for arsdk.network.Event events.
class ArsdkNetworkEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.network.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkNetworkEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkNetworkEventDecoderListener) {
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
        guard serviceId == ArsdkNetworkEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Network_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkNetworkEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Network_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Network_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 19
        }
    }
}

/// Decoder for arsdk.network.Command commands.
class ArsdkNetworkCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.network.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Network_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkNetworkCommandEncoder command \(command)")
        var message = Arsdk_Network_Command()
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
extension Arsdk_Network_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setRoutingPolicy: return 17
        case .setCellularMaxBitrate: return 18
        case .setDirectConnection: return 19
        }
    }
}
extension Arsdk_Network_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Network_Command.SetRoutingPolicy {
    static var policyFieldNumber: Int32 { 1 }
}
extension Arsdk_Network_Command.SetCellularMaxBitrate {
    static var maxBitrateFieldNumber: Int32 { 1 }
}
extension Arsdk_Network_Command.SetDirectConnection {
    static var modeFieldNumber: Int32 { 1 }
}
extension Arsdk_Network_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setRoutingPolicyFieldNumber: Int32 { 17 }
    static var setCellularMaxBitrateFieldNumber: Int32 { 18 }
    static var setDirectConnectionFieldNumber: Int32 { 19 }
}
extension Arsdk_Network_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var routingInfoFieldNumber: Int32 { 2 }
    static var globalLinkQualityFieldNumber: Int32 { 3 }
    static var linksStatusFieldNumber: Int32 { 4 }
    static var cellularMaxBitrateFieldNumber: Int32 { 5 }
    static var directConnectionModeFieldNumber: Int32 { 6 }
}
extension Arsdk_Network_Event {
    static var stateFieldNumber: Int32 { 19 }
}
extension Arsdk_Network_Capabilities {
    static var cellularMinBitrateFieldNumber: Int32 { 1 }
    static var cellularMaxBitrateFieldNumber: Int32 { 2 }
    static var supportedDirectConnectionModesFieldNumber: Int32 { 3 }
}
extension Arsdk_Network_RoutingInfo {
    static var policyFieldNumber: Int32 { 1 }
    static var currentLinkFieldNumber: Int32 { 2 }
}
extension Arsdk_Network_GlobalLinkQuality {
    static var qualityFieldNumber: Int32 { 1 }
}
extension Arsdk_Network_LinksStatus.LinkInfo {
    static var typeFieldNumber: Int32 { 1 }
    static var statusFieldNumber: Int32 { 2 }
    static var qualityFieldNumber: Int32 { 3 }
    static var errorFieldNumber: Int32 { 4 }
    static var cellularStatusFieldNumber: Int32 { 5 }
}
extension Arsdk_Network_LinksStatus {
    static var linksFieldNumber: Int32 { 1 }
}
extension Arsdk_Network_CellularMaxBitrate {
    static var maxBitrateFieldNumber: Int32 { 1 }
}
