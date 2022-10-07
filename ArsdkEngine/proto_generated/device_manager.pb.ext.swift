// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkDevicemanagerEventDecoder`.
protocol ArsdkDevicemanagerEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Devicemanager_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Devicemanager_Event.State)

    /// Processes a `Arsdk_Devicemanager_Event.ConnectionFailure` event.
    ///
    /// - Parameter connectionFailure: event to process
    func onConnectionFailure(_ connectionFailure: Arsdk_Devicemanager_Event.ConnectionFailure)

    /// Processes a `Arsdk_Devicemanager_Event.DiscoveredDevices` event.
    ///
    /// - Parameter discoveredDevices: event to process
    func onDiscoveredDevices(_ discoveredDevices: Arsdk_Devicemanager_Event.DiscoveredDevices)
}

/// Decoder for arsdk.devicemanager.Event events.
class ArsdkDevicemanagerEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.devicemanager.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkDevicemanagerEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkDevicemanagerEventDecoderListener) {
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
        guard serviceId == ArsdkDevicemanagerEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Devicemanager_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkDevicemanagerEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .connectionFailure(let event):
                listener?.onConnectionFailure(event)
            case .discoveredDevices(let event):
                listener?.onDiscoveredDevices(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Devicemanager_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Devicemanager_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        case .connectionFailure: return 17
        case .discoveredDevices: return 18
        }
    }
}

/// Decoder for arsdk.devicemanager.Command commands.
class ArsdkDevicemanagerCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.devicemanager.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Devicemanager_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkDevicemanagerCommandEncoder command \(command)")
        var message = Arsdk_Devicemanager_Command()
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
extension Arsdk_Devicemanager_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .connectDevice: return 17
        case .forgetDevice: return 18
        case .discoverDevices: return 19
        }
    }
}
extension Arsdk_Devicemanager_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Devicemanager_Command.ConnectDevice.Wifi {
    static var securityKeyFieldNumber: Int32 { 1 }
}
extension Arsdk_Devicemanager_Command.ConnectDevice.Microhard {
    static var powerFieldNumber: Int32 { 1 }
}
extension Arsdk_Devicemanager_Command.ConnectDevice {
    static var uidFieldNumber: Int32 { 1 }
    static var wifiFieldNumber: Int32 { 2 }
    static var cellularFieldNumber: Int32 { 3 }
    static var microhardFieldNumber: Int32 { 4 }
}
extension Arsdk_Devicemanager_Command.ForgetDevice {
    static var uidFieldNumber: Int32 { 1 }
}
extension Arsdk_Devicemanager_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var connectDeviceFieldNumber: Int32 { 17 }
    static var forgetDeviceFieldNumber: Int32 { 18 }
    static var discoverDevicesFieldNumber: Int32 { 19 }
}
extension Arsdk_Devicemanager_Event.State.KnownDevices {
    static var devicesFieldNumber: Int32 { 2 }
}
extension Arsdk_Devicemanager_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var knownDevicesFieldNumber: Int32 { 3 }
    static var idleFieldNumber: Int32 { 4 }
    static var searchingFieldNumber: Int32 { 5 }
    static var connectingFieldNumber: Int32 { 6 }
    static var connectedFieldNumber: Int32 { 7 }
    static var disconnectingFieldNumber: Int32 { 8 }
}
extension Arsdk_Devicemanager_Event.ConnectionFailure {
    static var deviceFieldNumber: Int32 { 1 }
    static var transportFieldNumber: Int32 { 2 }
    static var reasonFieldNumber: Int32 { 3 }
}
extension Arsdk_Devicemanager_Event.DiscoveredDevices {
    static var devicesFieldNumber: Int32 { 1 }
}
extension Arsdk_Devicemanager_Event {
    static var stateFieldNumber: Int32 { 16 }
    static var connectionFailureFieldNumber: Int32 { 17 }
    static var discoveredDevicesFieldNumber: Int32 { 18 }
}
extension Arsdk_Devicemanager_Capabilities.Microhard {
    static var powerMinFieldNumber: Int32 { 2 }
    static var powerMaxFieldNumber: Int32 { 3 }
}
extension Arsdk_Devicemanager_Capabilities {
    static var discoveryTransportsFieldNumber: Int32 { 1 }
    static var microhardFieldNumber: Int32 { 2 }
}
extension Arsdk_Devicemanager_ConnectionState.Connecting {
    static var deviceFieldNumber: Int32 { 1 }
    static var transportFieldNumber: Int32 { 2 }
}
extension Arsdk_Devicemanager_ConnectionState.Connected {
    static var deviceFieldNumber: Int32 { 1 }
    static var transportFieldNumber: Int32 { 2 }
}
extension Arsdk_Devicemanager_ConnectionState.Disconnecting {
    static var deviceFieldNumber: Int32 { 1 }
    static var transportFieldNumber: Int32 { 2 }
}
extension Arsdk_Devicemanager_DeviceInfo {
    static var uidFieldNumber: Int32 { 1 }
    static var modelFieldNumber: Int32 { 2 }
    static var networkIdFieldNumber: Int32 { 3 }
}
extension Arsdk_Devicemanager_WifiInfo {
    static var securityFieldNumber: Int32 { 1 }
    static var savedKeyFieldNumber: Int32 { 2 }
}
extension Arsdk_Devicemanager_MicrohardInfo {
    static var powerFieldNumber: Int32 { 1 }
    static var channelFieldNumber: Int32 { 2 }
    static var bandwidthFieldNumber: Int32 { 3 }
    static var encryptionAlgorithmFieldNumber: Int32 { 4 }
}
extension Arsdk_Devicemanager_KnownDevice {
    static var infoFieldNumber: Int32 { 1 }
    static var wifiFieldNumber: Int32 { 2 }
    static var cellularFieldNumber: Int32 { 3 }
    static var microhardFieldNumber: Int32 { 4 }
}
extension Arsdk_Devicemanager_DiscoveredDevice.WifiVisibility {
    static var transportInfoFieldNumber: Int32 { 1 }
    static var rssiFieldNumber: Int32 { 2 }
}
extension Arsdk_Devicemanager_DiscoveredDevice.CellularVisibility {
    static var transportInfoFieldNumber: Int32 { 1 }
}
extension Arsdk_Devicemanager_DiscoveredDevice {
    static var infoFieldNumber: Int32 { 1 }
    static var knownFieldNumber: Int32 { 2 }
    static var wifiVisibilityFieldNumber: Int32 { 3 }
    static var cellularVisibilityFieldNumber: Int32 { 4 }
}
