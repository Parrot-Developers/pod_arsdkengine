// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkNavigationEventDecoder`.
protocol ArsdkNavigationEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Navigation_Event.Location` event.
    ///
    /// - Parameter location: event to process
    func onLocation(_ location: Arsdk_Navigation_Event.Location)

    /// Processes a `Arsdk_Navigation_Event.RawGnssLocation` event.
    ///
    /// - Parameter rawGnssLocation: event to process
    func onRawGnssLocation(_ rawGnssLocation: Arsdk_Navigation_Event.RawGnssLocation)

    /// Processes a `Arsdk_Navigation_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Navigation_Event.State)
}

/// Decoder for arsdk.navigation.Event events.
class ArsdkNavigationEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.navigation.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkNavigationEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkNavigationEventDecoderListener) {
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
        guard serviceId == ArsdkNavigationEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Navigation_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkNavigationEventDecoder event \(event)")
            }
            switch event.id {
            case .location(let event):
                listener?.onLocation(event)
            case .rawGnssLocation(let event):
                listener?.onRawGnssLocation(event)
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Navigation_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Navigation_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .location: return 1
        case .rawGnssLocation: return 2
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.navigation.Command commands.
class ArsdkNavigationCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.navigation.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Navigation_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkNavigationCommandEncoder command \(command)")
        var message = Arsdk_Navigation_Command()
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
extension Arsdk_Navigation_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setGlobalPose: return 17
        case .configure: return 18
        }
    }
}
extension Arsdk_Navigation_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_Command.SetGlobalPose {
    static var latitudeFieldNumber: Int32 { 1 }
    static var longitudeFieldNumber: Int32 { 2 }
    static var headingFieldNumber: Int32 { 3 }
}
extension Arsdk_Navigation_Command.Configure {
    static var configFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setGlobalPoseFieldNumber: Int32 { 17 }
    static var configureFieldNumber: Int32 { 18 }
}
extension Arsdk_Navigation_Event.Location.Gnss {
    static var numberOfSatellitesFieldNumber: Int32 { 1 }
    static var isFixedFieldNumber: Int32 { 2 }
}
extension Arsdk_Navigation_Event.Location {
    static var latitudeFieldNumber: Int32 { 1 }
    static var longitudeFieldNumber: Int32 { 2 }
    static var altitudeWgs84FieldNumber: Int32 { 3 }
    static var altitudeAmslFieldNumber: Int32 { 4 }
    static var headingFieldNumber: Int32 { 5 }
    static var horizontalAccuracyFieldNumber: Int32 { 6 }
    static var verticalAccuracyFieldNumber: Int32 { 7 }
    static var headingAccuracyFieldNumber: Int32 { 8 }
    static var gnssFieldNumber: Int32 { 9 }
    static var reliabilityFieldNumber: Int32 { 10 }
    static var locationUsesMagnetometerFieldNumber: Int32 { 11 }
    static var altitudeAtoFieldNumber: Int32 { 12 }
    static var altitudeAglFieldNumber: Int32 { 13 }
}
extension Arsdk_Navigation_Event.RawGnssLocation {
    static var latitudeFieldNumber: Int32 { 1 }
    static var longitudeFieldNumber: Int32 { 2 }
    static var altitudeAmslFieldNumber: Int32 { 3 }
}
extension Arsdk_Navigation_Event.State {
    static var availableFramesFieldNumber: Int32 { 1 }
    static var defaultCapabilitiesFieldNumber: Int32 { 2 }
    static var configFieldNumber: Int32 { 3 }
    static var raisedAlarmsFieldNumber: Int32 { 4 }
    static var gnssSourceFieldNumber: Int32 { 5 }
    static var firstFixFieldNumber: Int32 { 6 }
}
extension Arsdk_Navigation_Event {
    static var locationFieldNumber: Int32 { 1 }
    static var rawGnssLocationFieldNumber: Int32 { 2 }
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Navigation_Alarms {
    static var alarmsFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_Alarm {
    static var typeFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_Capabilities {
    static var sourcesFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_Config {
    static var sourcesFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_Frames {
    static var framesFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_GnssSourceValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Navigation_FirstFix {
    static var latitudeFieldNumber: Int32 { 1 }
    static var longitudeFieldNumber: Int32 { 2 }
    static var altitudeFieldNumber: Int32 { 3 }
}
extension Arsdk_Navigation_Source {
    static var gpsFieldNumber: Int32 { 1 }
    static var glonassFieldNumber: Int32 { 2 }
    static var galileoFieldNumber: Int32 { 3 }
    static var beidouFieldNumber: Int32 { 4 }
    static var rtkFieldNumber: Int32 { 5 }
    static var visionMapFieldNumber: Int32 { 6 }
    static var odometryFieldNumber: Int32 { 7 }
    static var barometerFieldNumber: Int32 { 8 }
    static var magnetometerFieldNumber: Int32 { 9 }
}
