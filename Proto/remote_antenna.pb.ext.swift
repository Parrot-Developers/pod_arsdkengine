// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkRemoteantennaEventDecoder`.
protocol ArsdkRemoteantennaEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Remoteantenna_Event.Heading` event.
    ///
    /// - Parameter heading: event to process
    func onHeading(_ heading: Arsdk_Remoteantenna_Event.Heading)

    /// Processes a `Arsdk_Remoteantenna_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Remoteantenna_Event.State)

    /// Processes a `Arsdk_Remoteantenna_Event.DiscoveredCloudAntennas` event.
    ///
    /// - Parameter discoveredCloudAntennas: event to process
    func onDiscoveredCloudAntennas(_ discoveredCloudAntennas: Arsdk_Remoteantenna_Event.DiscoveredCloudAntennas)
}

/// Decoder for arsdk.remoteantenna.Event events.
class ArsdkRemoteantennaEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.remoteantenna.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkRemoteantennaEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkRemoteantennaEventDecoderListener) {
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
        guard serviceId == ArsdkRemoteantennaEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Remoteantenna_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkRemoteantennaEventDecoder event \(event)")
            }
            switch event.id {
            case .heading(let event):
                listener?.onHeading(event)
            case .state(let event):
                listener?.onState(event)
            case .discoveredCloudAntennas(let event):
                listener?.onDiscoveredCloudAntennas(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Remoteantenna_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Remoteantenna_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .heading: return 1
        case .state: return 16
        case .discoveredCloudAntennas: return 17
        }
    }
}

/// Decoder for arsdk.remoteantenna.Command commands.
class ArsdkRemoteantennaCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.remoteantenna.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Remoteantenna_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkRemoteantennaCommandEncoder command \(command)")
        var message = Arsdk_Remoteantenna_Command()
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
extension Arsdk_Remoteantenna_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .enable: return 17
        case .disable: return 18
        case .powerOnAntenna: return 19
        case .shutDownAntenna: return 20
        case .cloudConnect: return 21
        case .cloudDisconnect: return 22
        case .setAntennaCoordinates: return 23
        case .unstickMotorizedSupport: return 24
        }
    }
}
extension Arsdk_Remoteantenna_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_Command.CloudConnect {
    static var serialFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_Command.UnstickMotorizedSupport {
    static var movementFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var enableFieldNumber: Int32 { 17 }
    static var disableFieldNumber: Int32 { 18 }
    static var powerOnAntennaFieldNumber: Int32 { 19 }
    static var shutDownAntennaFieldNumber: Int32 { 20 }
    static var cloudConnectFieldNumber: Int32 { 21 }
    static var cloudDisconnectFieldNumber: Int32 { 22 }
    static var setAntennaCoordinatesFieldNumber: Int32 { 23 }
    static var unstickMotorizedSupportFieldNumber: Int32 { 24 }
}
extension Arsdk_Remoteantenna_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var enabledFieldNumber: Int32 { 2 }
    static var antennaStatusFieldNumber: Int32 { 3 }
    static var antennaBatteryLevelFieldNumber: Int32 { 4 }
    static var chargingStateFieldNumber: Int32 { 5 }
    static var chargerPluggedFieldNumber: Int32 { 6 }
    static var availableBandwidthFieldNumber: Int32 { 7 }
    static var deviceInfoFieldNumber: Int32 { 8 }
    static var useCloudAntennaFieldNumber: Int32 { 9 }
    static var antennaCoordinatesFieldNumber: Int32 { 10 }
    static var disconnectedFieldNumber: Int32 { 11 }
    static var connectedFieldNumber: Int32 { 12 }
}
extension Arsdk_Remoteantenna_Event.DiscoveredCloudAntennas {
    static var antennasFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_Event.Heading {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_Event {
    static var headingFieldNumber: Int32 { 1 }
    static var stateFieldNumber: Int32 { 16 }
    static var discoveredCloudAntennasFieldNumber: Int32 { 17 }
}
extension Arsdk_Remoteantenna_GpsCoordinates {
    static var latitudeFieldNumber: Int32 { 1 }
    static var longitudeFieldNumber: Int32 { 2 }
}
extension Arsdk_Remoteantenna_Capabilities {
    static var cloudAntennaFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_BatteryStateValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_AntennaStatusValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_DeviceInfo {
    static var modelFieldNumber: Int32 { 1 }
    static var firmwareVersionFieldNumber: Int32 { 2 }
    static var serialFieldNumber: Int32 { 3 }
    static var needsGpsCoordinatesFieldNumber: Int32 { 4 }
    static var productVariantFieldNumber: Int32 { 5 }
}
extension Arsdk_Remoteantenna_CloudAntenna {
    static var infoFieldNumber: Int32 { 1 }
}
extension Arsdk_Remoteantenna_MotorizedSupportConnected {
    static var serialFieldNumber: Int32 { 1 }
    static var alarmsFieldNumber: Int32 { 2 }
}
