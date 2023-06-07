// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkConnectivityEventDecoder`.
protocol ArsdkConnectivityEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Connectivity_Event.RadioList` event.
    ///
    /// - Parameter radioList: event to process
    func onRadioList(_ radioList: Arsdk_Connectivity_Event.RadioList)

    /// Processes a `Arsdk_Connectivity_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Connectivity_Event.State)

    /// Processes a `Arsdk_Connectivity_Event.CommandResponse` event.
    ///
    /// - Parameter commandResponse: event to process
    func onCommandResponse(_ commandResponse: Arsdk_Connectivity_Event.CommandResponse)

    /// Processes a `Arsdk_Connectivity_Event.Connection` event.
    ///
    /// - Parameter connection: event to process
    func onConnection(_ connection: Arsdk_Connectivity_Event.Connection)

    /// Processes a `Arsdk_Connectivity_Event.ScanResult` event.
    ///
    /// - Parameter scanResult: event to process
    func onScanResult(_ scanResult: Arsdk_Connectivity_Event.ScanResult)
}

/// Decoder for arsdk.connectivity.Event events.
class ArsdkConnectivityEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.connectivity.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkConnectivityEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkConnectivityEventDecoderListener) {
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
        guard serviceId == ArsdkConnectivityEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Connectivity_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkConnectivityEventDecoder event \(event)")
            }
            switch event.id {
            case .radioList(let event):
                listener?.onRadioList(event)
            case .state(let event):
                listener?.onState(event)
            case .commandResponse(let event):
                listener?.onCommandResponse(event)
            case .connection(let event):
                listener?.onConnection(event)
            case .scanResult(let event):
                listener?.onScanResult(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Connectivity_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Connectivity_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .radioList: return 16
        case .state: return 17
        case .commandResponse: return 18
        case .connection: return 19
        case .scanResult: return 20
        }
    }
}

/// Decoder for arsdk.connectivity.Command commands.
class ArsdkConnectivityCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.connectivity.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Connectivity_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkConnectivityCommandEncoder command \(command)")
        var message = Arsdk_Connectivity_Command()
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
extension Arsdk_Connectivity_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .listRadios: return 16
        case .getState: return 17
        case .setMode: return 18
        case .scan: return 19
        case .configure: return 20
        }
    }
}
extension Arsdk_Connectivity_Command.ListRadios {
    static var typeFilterFieldNumber: Int32 { 1 }
}
extension Arsdk_Connectivity_Command.GetState {
    static var radioIdFieldNumber: Int32 { 1 }
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_Command.SetMode {
    static var radioIdFieldNumber: Int32 { 1 }
    static var modeFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_Command.Scan {
    static var radioIdFieldNumber: Int32 { 1 }
}
extension Arsdk_Connectivity_Command.Configure {
    static var radioIdFieldNumber: Int32 { 1 }
    static var accessPointConfigFieldNumber: Int32 { 2 }
    static var stationConfigFieldNumber: Int32 { 3 }
}
extension Arsdk_Connectivity_Command {
    static var listRadiosFieldNumber: Int32 { 16 }
    static var getStateFieldNumber: Int32 { 17 }
    static var setModeFieldNumber: Int32 { 18 }
    static var scanFieldNumber: Int32 { 19 }
    static var configureFieldNumber: Int32 { 20 }
}
extension Arsdk_Connectivity_Event.RadioList {
    static var radiosFieldNumber: Int32 { 1 }
}
extension Arsdk_Connectivity_Event.State {
    static var radioIdFieldNumber: Int32 { 1 }
    static var defaultCapabilitiesFieldNumber: Int32 { 2 }
    static var accessPointConfigFieldNumber: Int32 { 3 }
    static var stationConfigFieldNumber: Int32 { 4 }
    static var idleFieldNumber: Int32 { 5 }
    static var accessPointFieldNumber: Int32 { 6 }
    static var stationFieldNumber: Int32 { 7 }
    static var channelFieldNumber: Int32 { 8 }
    static var authorizedChannelsFieldNumber: Int32 { 9 }
    static var rssiFieldNumber: Int32 { 10 }
}
extension Arsdk_Connectivity_Event.CommandResponse {
    static var radioIdFieldNumber: Int32 { 1 }
    static var statusFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_Event.Connection {
    static var radioIdFieldNumber: Int32 { 1 }
    static var statusFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_Event.ScanResult {
    static var radioIdFieldNumber: Int32 { 1 }
    static var networksFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_Event {
    static var radioListFieldNumber: Int32 { 16 }
    static var stateFieldNumber: Int32 { 17 }
    static var commandResponseFieldNumber: Int32 { 18 }
    static var connectionFieldNumber: Int32 { 19 }
    static var scanResultFieldNumber: Int32 { 20 }
}
extension Arsdk_Connectivity_Capabilities {
    static var supportedModesFieldNumber: Int32 { 2 }
    static var supportedEncryptionTypesFieldNumber: Int32 { 3 }
    static var supportedCountriesFieldNumber: Int32 { 4 }
}
extension Arsdk_Connectivity_AccessPointConfig {
    static var securityFieldNumber: Int32 { 1 }
    static var ssidFieldNumber: Int32 { 2 }
    static var hiddenFieldNumber: Int32 { 3 }
    static var hwAddrFieldNumber: Int32 { 4 }
    static var countryFieldNumber: Int32 { 5 }
    static var environmentFieldNumber: Int32 { 6 }
    static var manualChannelFieldNumber: Int32 { 7 }
    static var automaticChannelFieldNumber: Int32 { 8 }
}
extension Arsdk_Connectivity_StationConfig {
    static var securityFieldNumber: Int32 { 1 }
    static var ssidFieldNumber: Int32 { 2 }
    static var hiddenFieldNumber: Int32 { 3 }
    static var hwAddrFieldNumber: Int32 { 4 }
    static var countryFieldNumber: Int32 { 5 }
    static var environmentFieldNumber: Int32 { 6 }
}
extension Arsdk_Connectivity_AccessPointState {
    static var systemStateFieldNumber: Int32 { 1 }
}
extension Arsdk_Connectivity_StationState {
    static var systemStateFieldNumber: Int32 { 1 }
    static var connectionStateFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_Channel {
    static var wifiChannelFieldNumber: Int32 { 1 }
}
extension Arsdk_Connectivity_WifiChannel {
    static var bandFieldNumber: Int32 { 1 }
    static var channelFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_AuthorizedChannels {
    static var channelFieldNumber: Int32 { 1 }
}
extension Arsdk_Connectivity_AuthorizedChannel {
    static var channelFieldNumber: Int32 { 1 }
    static var environmentFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_NetworkSecurityMode {
    static var encryptionFieldNumber: Int32 { 1 }
    static var passphraseFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_Network {
    static var channelFieldNumber: Int32 { 1 }
    static var encryptionFieldNumber: Int32 { 2 }
    static var ssidFieldNumber: Int32 { 3 }
    static var bieFieldNumber: Int32 { 4 }
}
extension Arsdk_Connectivity_Bie {
    static var ouiFieldNumber: Int32 { 1 }
    static var dataFieldNumber: Int32 { 2 }
}
extension Arsdk_Connectivity_EnvironmentValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Connectivity_AutomaticChannelSelection {
    static var allowedBandsFieldNumber: Int32 { 1 }
}
