// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkUnguardedflightEventDecoder`.
protocol ArsdkUnguardedflightEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Unguardedflight_Config` event.
    ///
    /// - Parameter capabilities: event to process
    func onCapabilities(_ capabilities: Arsdk_Unguardedflight_Config)

    /// Processes a `Arsdk_Unguardedflight_Config` event.
    ///
    /// - Parameter currentConfig: event to process
    func onCurrentConfig(_ currentConfig: Arsdk_Unguardedflight_Config)
}

/// Decoder for arsdk.unguardedflight.Event events.
class ArsdkUnguardedflightEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.unguardedflight.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkUnguardedflightEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkUnguardedflightEventDecoderListener) {
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
        guard serviceId == ArsdkUnguardedflightEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Unguardedflight_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkUnguardedflightEventDecoder event \(event)")
            }
            switch event.id {
            case .capabilities(let event):
                listener?.onCapabilities(event)
            case .currentConfig(let event):
                listener?.onCurrentConfig(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Unguardedflight_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Unguardedflight_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .capabilities: return 16
        case .currentConfig: return 17
        }
    }
}

/// Decoder for arsdk.unguardedflight.Command commands.
class ArsdkUnguardedflightCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.unguardedflight.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Unguardedflight_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkUnguardedflightCommandEncoder command \(command)")
        var message = Arsdk_Unguardedflight_Command()
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
extension Arsdk_Unguardedflight_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getConfig: return 16
        case .getCapabilities: return 17
        case .setConfig: return 18
        }
    }
}
extension Arsdk_Unguardedflight_Command {
    static var getConfigFieldNumber: Int32 { 16 }
    static var getCapabilitiesFieldNumber: Int32 { 17 }
    static var setConfigFieldNumber: Int32 { 18 }
}
extension Arsdk_Unguardedflight_Event {
    static var capabilitiesFieldNumber: Int32 { 16 }
    static var currentConfigFieldNumber: Int32 { 17 }
}
extension Arsdk_Unguardedflight_Config {
    static var unguardedFlightElementsFieldNumber: Int32 { 1 }
}
