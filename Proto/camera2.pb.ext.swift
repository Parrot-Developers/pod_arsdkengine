// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkCameraEventDecoder`.
protocol ArsdkCameraEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Camera_Event.Exposure` event.
    ///
    /// - Parameter cameraExposure: event to process
    func onCameraExposure(_ cameraExposure: Arsdk_Camera_Event.Exposure)

    /// Processes a `Arsdk_Camera_Event.ZoomLevel` event.
    ///
    /// - Parameter zoomLevel: event to process
    func onZoomLevel(_ zoomLevel: Arsdk_Camera_Event.ZoomLevel)

    /// Processes a `Arsdk_Camera_Event.NextPhotoInterval` event.
    ///
    /// - Parameter nextPhotoInterval: event to process
    func onNextPhotoInterval(_ nextPhotoInterval: Arsdk_Camera_Event.NextPhotoInterval)

    /// Processes a `Arsdk_Camera_Event.CameraList` event.
    ///
    /// - Parameter cameraList: event to process
    func onCameraList(_ cameraList: Arsdk_Camera_Event.CameraList)

    /// Processes a `Arsdk_Camera_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Camera_Event.State)

    /// Processes a `Arsdk_Camera_Event.Photo` event.
    ///
    /// - Parameter photo: event to process
    func onPhoto(_ photo: Arsdk_Camera_Event.Photo)

    /// Processes a `Arsdk_Camera_Event.Recording` event.
    ///
    /// - Parameter recording: event to process
    func onRecording(_ recording: Arsdk_Camera_Event.Recording)
}

/// Decoder for arsdk.camera.Event events.
class ArsdkCameraEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.camera.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkCameraEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkCameraEventDecoderListener) {
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
        guard serviceId == ArsdkCameraEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Camera_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkCameraEventDecoder event \(event)")
            }
            switch event.id {
            case .cameraExposure(let event):
                listener?.onCameraExposure(event)
            case .zoomLevel(let event):
                listener?.onZoomLevel(event)
            case .nextPhotoInterval(let event):
                listener?.onNextPhotoInterval(event)
            case .cameraList(let event):
                listener?.onCameraList(event)
            case .state(let event):
                listener?.onState(event)
            case .photo(let event):
                listener?.onPhoto(event)
            case .recording(let event):
                listener?.onRecording(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Camera_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Camera_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .cameraExposure: return 1
        case .zoomLevel: return 2
        case .nextPhotoInterval: return 3
        case .cameraList: return 16
        case .state: return 17
        case .photo: return 18
        case .recording: return 19
        }
    }
}

/// Decoder for arsdk.camera.Command commands.
class ArsdkCameraCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.camera.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Camera_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkCameraCommandEncoder command \(command)")
        var message = Arsdk_Camera_Command()
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
extension Arsdk_Camera_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .setZoomTarget: return 1
        case .listCameras: return 16
        case .getState: return 17
        case .configure: return 18
        case .startPhoto: return 19
        case .stopPhoto: return 20
        case .startRecording: return 21
        case .stopRecording: return 22
        case .lockExposure: return 23
        case .lockWhiteBalance: return 24
        case .setMediaMetadata: return 25
        case .resetZoom: return 26
        }
    }
}
extension Arsdk_Camera_Command.ListCameras {
    static var modelFilterFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Command.GetState {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Command.Configure {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var configFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Command.SetZoomTarget {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var controlModeFieldNumber: Int32 { 2 }
    static var targetFieldNumber: Int32 { 3 }
}
extension Arsdk_Camera_Command.ResetZoom {
    static var cameraIdFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Command.StartPhoto {
    static var cameraIdFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Command.StopPhoto {
    static var cameraIdFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Command.StartRecording {
    static var cameraIdFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Command.StopRecording {
    static var cameraIdFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Command.LockExposure {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var modeFieldNumber: Int32 { 2 }
    static var roiFieldNumber: Int32 { 3 }
}
extension Arsdk_Camera_Command.LockWhiteBalance {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var modeFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Command.SetMediaMetadata {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var metadataFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Command {
    static var setZoomTargetFieldNumber: Int32 { 1 }
    static var listCamerasFieldNumber: Int32 { 16 }
    static var getStateFieldNumber: Int32 { 17 }
    static var configureFieldNumber: Int32 { 18 }
    static var startPhotoFieldNumber: Int32 { 19 }
    static var stopPhotoFieldNumber: Int32 { 20 }
    static var startRecordingFieldNumber: Int32 { 21 }
    static var stopRecordingFieldNumber: Int32 { 22 }
    static var lockExposureFieldNumber: Int32 { 23 }
    static var lockWhiteBalanceFieldNumber: Int32 { 24 }
    static var setMediaMetadataFieldNumber: Int32 { 25 }
    static var resetZoomFieldNumber: Int32 { 26 }
}
extension Arsdk_Camera_Event.CameraList {
    static var camerasFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Event.State.Photo {
    static var stateFieldNumber: Int32 { 1 }
    static var photoCountFieldNumber: Int32 { 3 }
    static var storageFieldNumber: Int32 { 4 }
    static var durationFieldNumber: Int32 { 5 }
}
extension Arsdk_Camera_Event.State.Recording {
    static var stateFieldNumber: Int32 { 1 }
    static var videoBitrateFieldNumber: Int32 { 3 }
    static var storageFieldNumber: Int32 { 4 }
    static var durationFieldNumber: Int32 { 5 }
}
extension Arsdk_Camera_Event.State.WhiteBalanceLock {
    static var supportedModesFieldNumber: Int32 { 1 }
    static var modeFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Event.State.ExposureLock {
    static var supportedModesFieldNumber: Int32 { 1 }
    static var modeFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Event.State.Zoom {
    static var zoomLevelMaxFieldNumber: Int32 { 1 }
    static var zoomHighQualityLevelMaxFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Event.State {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var selectedFieldsFieldNumber: Int32 { 2 }
    static var activeFieldNumber: Int32 { 3 }
    static var defaultCapabilitiesFieldNumber: Int32 { 4 }
    static var currentCapabilitiesFieldNumber: Int32 { 5 }
    static var configFieldNumber: Int32 { 6 }
    static var photoFieldNumber: Int32 { 7 }
    static var recordingFieldNumber: Int32 { 8 }
    static var whiteBalanceLockFieldNumber: Int32 { 9 }
    static var exposureLockFieldNumber: Int32 { 10 }
    static var zoomFieldNumber: Int32 { 11 }
    static var mediaMetadataFieldNumber: Int32 { 12 }
    var cameraIdSelected: Bool {
        get {
            return selectedFields[1] != nil
        }
        set {
            if newValue && selectedFields[1] == nil {
                selectedFields[1] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[1] != nil {
                selectedFields.removeValue(forKey: 1)
            }
        }
    }
    var selectedFieldsSelected: Bool {
        get {
            return selectedFields[2] != nil
        }
        set {
            if newValue && selectedFields[2] == nil {
                selectedFields[2] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[2] != nil {
                selectedFields.removeValue(forKey: 2)
            }
        }
    }
    var activeSelected: Bool {
        get {
            return selectedFields[3] != nil
        }
        set {
            if newValue && selectedFields[3] == nil {
                selectedFields[3] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[3] != nil {
                selectedFields.removeValue(forKey: 3)
            }
        }
    }
    var defaultCapabilitiesSelected: Bool {
        get {
            return selectedFields[4] != nil
        }
        set {
            if newValue && selectedFields[4] == nil {
                selectedFields[4] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[4] != nil {
                selectedFields.removeValue(forKey: 4)
            }
        }
    }
    var currentCapabilitiesSelected: Bool {
        get {
            return selectedFields[5] != nil
        }
        set {
            if newValue && selectedFields[5] == nil {
                selectedFields[5] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[5] != nil {
                selectedFields.removeValue(forKey: 5)
            }
        }
    }
    var configSelected: Bool {
        get {
            return selectedFields[6] != nil
        }
        set {
            if newValue && selectedFields[6] == nil {
                selectedFields[6] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[6] != nil {
                selectedFields.removeValue(forKey: 6)
            }
        }
    }
    var photoSelected: Bool {
        get {
            return selectedFields[7] != nil
        }
        set {
            if newValue && selectedFields[7] == nil {
                selectedFields[7] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[7] != nil {
                selectedFields.removeValue(forKey: 7)
            }
        }
    }
    var recordingSelected: Bool {
        get {
            return selectedFields[8] != nil
        }
        set {
            if newValue && selectedFields[8] == nil {
                selectedFields[8] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[8] != nil {
                selectedFields.removeValue(forKey: 8)
            }
        }
    }
    var whiteBalanceLockSelected: Bool {
        get {
            return selectedFields[9] != nil
        }
        set {
            if newValue && selectedFields[9] == nil {
                selectedFields[9] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[9] != nil {
                selectedFields.removeValue(forKey: 9)
            }
        }
    }
    var exposureLockSelected: Bool {
        get {
            return selectedFields[10] != nil
        }
        set {
            if newValue && selectedFields[10] == nil {
                selectedFields[10] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[10] != nil {
                selectedFields.removeValue(forKey: 10)
            }
        }
    }
    var zoomSelected: Bool {
        get {
            return selectedFields[11] != nil
        }
        set {
            if newValue && selectedFields[11] == nil {
                selectedFields[11] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[11] != nil {
                selectedFields.removeValue(forKey: 11)
            }
        }
    }
    var mediaMetadataSelected: Bool {
        get {
            return selectedFields[12] != nil
        }
        set {
            if newValue && selectedFields[12] == nil {
                selectedFields[12] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[12] != nil {
                selectedFields.removeValue(forKey: 12)
            }
        }
    }
}
extension Arsdk_Camera_Event.Exposure {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var shutterSpeedFieldNumber: Int32 { 2 }
    static var isoSensitivityFieldNumber: Int32 { 3 }
    static var exposureLockRegionFieldNumber: Int32 { 4 }
}
extension Arsdk_Camera_Event.ZoomLevel {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var levelFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_Event.NextPhotoInterval {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var modeFieldNumber: Int32 { 2 }
    static var intervalFieldNumber: Int32 { 3 }
}
extension Arsdk_Camera_Event.Photo {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var typeFieldNumber: Int32 { 2 }
    static var mediaIdFieldNumber: Int32 { 3 }
    static var stopReasonFieldNumber: Int32 { 4 }
    static var resourceIdFieldNumber: Int32 { 5 }
}
extension Arsdk_Camera_Event.Recording {
    static var cameraIdFieldNumber: Int32 { 1 }
    static var typeFieldNumber: Int32 { 2 }
    static var mediaIdFieldNumber: Int32 { 3 }
    static var stopReasonFieldNumber: Int32 { 4 }
}
extension Arsdk_Camera_Event {
    static var cameraExposureFieldNumber: Int32 { 1 }
    static var zoomLevelFieldNumber: Int32 { 2 }
    static var nextPhotoIntervalFieldNumber: Int32 { 3 }
    static var cameraListFieldNumber: Int32 { 16 }
    static var stateFieldNumber: Int32 { 17 }
    static var photoFieldNumber: Int32 { 18 }
    static var recordingFieldNumber: Int32 { 19 }
}
extension Arsdk_Camera_Capabilities.Rule {
    static var indexFieldNumber: Int32 { 1 }
    static var selectedFieldsFieldNumber: Int32 { 2 }
    static var cameraModesFieldNumber: Int32 { 3 }
    static var photoModesFieldNumber: Int32 { 4 }
    static var photoDynamicRangesFieldNumber: Int32 { 5 }
    static var photoResolutionsFieldNumber: Int32 { 6 }
    static var photoFormatsFieldNumber: Int32 { 7 }
    static var photoFileFormatsFieldNumber: Int32 { 8 }
    static var photoBurstValuesFieldNumber: Int32 { 9 }
    static var photoBracketingPresetsFieldNumber: Int32 { 10 }
    static var photoTimeLapseIntervalRangeFieldNumber: Int32 { 11 }
    static var photoGpsLapseIntervalRangeFieldNumber: Int32 { 12 }
    static var photoStreamingModesFieldNumber: Int32 { 13 }
    static var videoRecordingModesFieldNumber: Int32 { 14 }
    static var videoRecordingDynamicRangesFieldNumber: Int32 { 15 }
    static var videoRecordingCodecsFieldNumber: Int32 { 16 }
    static var videoRecordingResolutionsFieldNumber: Int32 { 17 }
    static var videoRecordingFrameratesFieldNumber: Int32 { 18 }
    static var audioRecordingModesFieldNumber: Int32 { 20 }
    static var exposureModesFieldNumber: Int32 { 23 }
    static var exposureManualShutterSpeedsFieldNumber: Int32 { 24 }
    static var exposureManualIsoSensitivitiesFieldNumber: Int32 { 25 }
    static var exposureMaximumIsoSensitivitiesFieldNumber: Int32 { 26 }
    static var whiteBalanceModesFieldNumber: Int32 { 27 }
    static var whiteBalanceTemperaturesFieldNumber: Int32 { 28 }
    static var evCompensationsFieldNumber: Int32 { 29 }
    static var imageStylesFieldNumber: Int32 { 30 }
    static var imageContrastRangeFieldNumber: Int32 { 31 }
    static var imageSaturationRangeFieldNumber: Int32 { 32 }
    static var imageSharpnessRangeFieldNumber: Int32 { 33 }
    static var zoomMaxSpeedRangeFieldNumber: Int32 { 34 }
    static var zoomVelocityControlQualityModesFieldNumber: Int32 { 35 }
    static var autoRecordModesFieldNumber: Int32 { 36 }
    static var alignmentOffsetPitchRangeFieldNumber: Int32 { 37 }
    static var alignmentOffsetRollRangeFieldNumber: Int32 { 38 }
    static var alignmentOffsetYawRangeFieldNumber: Int32 { 39 }
    static var photoSignaturesFieldNumber: Int32 { 40 }
    static var exposureMeteringsFieldNumber: Int32 { 41 }
    static var storagePoliciesFieldNumber: Int32 { 42 }
    static var videoRecordingBitratesFieldNumber: Int32 { 43 }
    var indexSelected: Bool {
        get {
            return selectedFields[1] != nil
        }
        set {
            if newValue && selectedFields[1] == nil {
                selectedFields[1] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[1] != nil {
                selectedFields.removeValue(forKey: 1)
            }
        }
    }
    var selectedFieldsSelected: Bool {
        get {
            return selectedFields[2] != nil
        }
        set {
            if newValue && selectedFields[2] == nil {
                selectedFields[2] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[2] != nil {
                selectedFields.removeValue(forKey: 2)
            }
        }
    }
    var cameraModesSelected: Bool {
        get {
            return selectedFields[3] != nil
        }
        set {
            if newValue && selectedFields[3] == nil {
                selectedFields[3] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[3] != nil {
                selectedFields.removeValue(forKey: 3)
            }
        }
    }
    var photoModesSelected: Bool {
        get {
            return selectedFields[4] != nil
        }
        set {
            if newValue && selectedFields[4] == nil {
                selectedFields[4] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[4] != nil {
                selectedFields.removeValue(forKey: 4)
            }
        }
    }
    var photoDynamicRangesSelected: Bool {
        get {
            return selectedFields[5] != nil
        }
        set {
            if newValue && selectedFields[5] == nil {
                selectedFields[5] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[5] != nil {
                selectedFields.removeValue(forKey: 5)
            }
        }
    }
    var photoResolutionsSelected: Bool {
        get {
            return selectedFields[6] != nil
        }
        set {
            if newValue && selectedFields[6] == nil {
                selectedFields[6] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[6] != nil {
                selectedFields.removeValue(forKey: 6)
            }
        }
    }
    var photoFormatsSelected: Bool {
        get {
            return selectedFields[7] != nil
        }
        set {
            if newValue && selectedFields[7] == nil {
                selectedFields[7] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[7] != nil {
                selectedFields.removeValue(forKey: 7)
            }
        }
    }
    var photoFileFormatsSelected: Bool {
        get {
            return selectedFields[8] != nil
        }
        set {
            if newValue && selectedFields[8] == nil {
                selectedFields[8] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[8] != nil {
                selectedFields.removeValue(forKey: 8)
            }
        }
    }
    var photoBurstValuesSelected: Bool {
        get {
            return selectedFields[9] != nil
        }
        set {
            if newValue && selectedFields[9] == nil {
                selectedFields[9] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[9] != nil {
                selectedFields.removeValue(forKey: 9)
            }
        }
    }
    var photoBracketingPresetsSelected: Bool {
        get {
            return selectedFields[10] != nil
        }
        set {
            if newValue && selectedFields[10] == nil {
                selectedFields[10] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[10] != nil {
                selectedFields.removeValue(forKey: 10)
            }
        }
    }
    var photoTimeLapseIntervalRangeSelected: Bool {
        get {
            return selectedFields[11] != nil
        }
        set {
            if newValue && selectedFields[11] == nil {
                selectedFields[11] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[11] != nil {
                selectedFields.removeValue(forKey: 11)
            }
        }
    }
    var photoGpsLapseIntervalRangeSelected: Bool {
        get {
            return selectedFields[12] != nil
        }
        set {
            if newValue && selectedFields[12] == nil {
                selectedFields[12] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[12] != nil {
                selectedFields.removeValue(forKey: 12)
            }
        }
    }
    var photoStreamingModesSelected: Bool {
        get {
            return selectedFields[13] != nil
        }
        set {
            if newValue && selectedFields[13] == nil {
                selectedFields[13] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[13] != nil {
                selectedFields.removeValue(forKey: 13)
            }
        }
    }
    var videoRecordingModesSelected: Bool {
        get {
            return selectedFields[14] != nil
        }
        set {
            if newValue && selectedFields[14] == nil {
                selectedFields[14] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[14] != nil {
                selectedFields.removeValue(forKey: 14)
            }
        }
    }
    var videoRecordingDynamicRangesSelected: Bool {
        get {
            return selectedFields[15] != nil
        }
        set {
            if newValue && selectedFields[15] == nil {
                selectedFields[15] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[15] != nil {
                selectedFields.removeValue(forKey: 15)
            }
        }
    }
    var videoRecordingCodecsSelected: Bool {
        get {
            return selectedFields[16] != nil
        }
        set {
            if newValue && selectedFields[16] == nil {
                selectedFields[16] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[16] != nil {
                selectedFields.removeValue(forKey: 16)
            }
        }
    }
    var videoRecordingResolutionsSelected: Bool {
        get {
            return selectedFields[17] != nil
        }
        set {
            if newValue && selectedFields[17] == nil {
                selectedFields[17] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[17] != nil {
                selectedFields.removeValue(forKey: 17)
            }
        }
    }
    var videoRecordingFrameratesSelected: Bool {
        get {
            return selectedFields[18] != nil
        }
        set {
            if newValue && selectedFields[18] == nil {
                selectedFields[18] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[18] != nil {
                selectedFields.removeValue(forKey: 18)
            }
        }
    }
    var audioRecordingModesSelected: Bool {
        get {
            return selectedFields[20] != nil
        }
        set {
            if newValue && selectedFields[20] == nil {
                selectedFields[20] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[20] != nil {
                selectedFields.removeValue(forKey: 20)
            }
        }
    }
    var exposureModesSelected: Bool {
        get {
            return selectedFields[23] != nil
        }
        set {
            if newValue && selectedFields[23] == nil {
                selectedFields[23] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[23] != nil {
                selectedFields.removeValue(forKey: 23)
            }
        }
    }
    var exposureManualShutterSpeedsSelected: Bool {
        get {
            return selectedFields[24] != nil
        }
        set {
            if newValue && selectedFields[24] == nil {
                selectedFields[24] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[24] != nil {
                selectedFields.removeValue(forKey: 24)
            }
        }
    }
    var exposureManualIsoSensitivitiesSelected: Bool {
        get {
            return selectedFields[25] != nil
        }
        set {
            if newValue && selectedFields[25] == nil {
                selectedFields[25] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[25] != nil {
                selectedFields.removeValue(forKey: 25)
            }
        }
    }
    var exposureMaximumIsoSensitivitiesSelected: Bool {
        get {
            return selectedFields[26] != nil
        }
        set {
            if newValue && selectedFields[26] == nil {
                selectedFields[26] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[26] != nil {
                selectedFields.removeValue(forKey: 26)
            }
        }
    }
    var whiteBalanceModesSelected: Bool {
        get {
            return selectedFields[27] != nil
        }
        set {
            if newValue && selectedFields[27] == nil {
                selectedFields[27] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[27] != nil {
                selectedFields.removeValue(forKey: 27)
            }
        }
    }
    var whiteBalanceTemperaturesSelected: Bool {
        get {
            return selectedFields[28] != nil
        }
        set {
            if newValue && selectedFields[28] == nil {
                selectedFields[28] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[28] != nil {
                selectedFields.removeValue(forKey: 28)
            }
        }
    }
    var evCompensationsSelected: Bool {
        get {
            return selectedFields[29] != nil
        }
        set {
            if newValue && selectedFields[29] == nil {
                selectedFields[29] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[29] != nil {
                selectedFields.removeValue(forKey: 29)
            }
        }
    }
    var imageStylesSelected: Bool {
        get {
            return selectedFields[30] != nil
        }
        set {
            if newValue && selectedFields[30] == nil {
                selectedFields[30] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[30] != nil {
                selectedFields.removeValue(forKey: 30)
            }
        }
    }
    var imageContrastRangeSelected: Bool {
        get {
            return selectedFields[31] != nil
        }
        set {
            if newValue && selectedFields[31] == nil {
                selectedFields[31] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[31] != nil {
                selectedFields.removeValue(forKey: 31)
            }
        }
    }
    var imageSaturationRangeSelected: Bool {
        get {
            return selectedFields[32] != nil
        }
        set {
            if newValue && selectedFields[32] == nil {
                selectedFields[32] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[32] != nil {
                selectedFields.removeValue(forKey: 32)
            }
        }
    }
    var imageSharpnessRangeSelected: Bool {
        get {
            return selectedFields[33] != nil
        }
        set {
            if newValue && selectedFields[33] == nil {
                selectedFields[33] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[33] != nil {
                selectedFields.removeValue(forKey: 33)
            }
        }
    }
    var zoomMaxSpeedRangeSelected: Bool {
        get {
            return selectedFields[34] != nil
        }
        set {
            if newValue && selectedFields[34] == nil {
                selectedFields[34] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[34] != nil {
                selectedFields.removeValue(forKey: 34)
            }
        }
    }
    var zoomVelocityControlQualityModesSelected: Bool {
        get {
            return selectedFields[35] != nil
        }
        set {
            if newValue && selectedFields[35] == nil {
                selectedFields[35] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[35] != nil {
                selectedFields.removeValue(forKey: 35)
            }
        }
    }
    var autoRecordModesSelected: Bool {
        get {
            return selectedFields[36] != nil
        }
        set {
            if newValue && selectedFields[36] == nil {
                selectedFields[36] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[36] != nil {
                selectedFields.removeValue(forKey: 36)
            }
        }
    }
    var alignmentOffsetPitchRangeSelected: Bool {
        get {
            return selectedFields[37] != nil
        }
        set {
            if newValue && selectedFields[37] == nil {
                selectedFields[37] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[37] != nil {
                selectedFields.removeValue(forKey: 37)
            }
        }
    }
    var alignmentOffsetRollRangeSelected: Bool {
        get {
            return selectedFields[38] != nil
        }
        set {
            if newValue && selectedFields[38] == nil {
                selectedFields[38] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[38] != nil {
                selectedFields.removeValue(forKey: 38)
            }
        }
    }
    var alignmentOffsetYawRangeSelected: Bool {
        get {
            return selectedFields[39] != nil
        }
        set {
            if newValue && selectedFields[39] == nil {
                selectedFields[39] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[39] != nil {
                selectedFields.removeValue(forKey: 39)
            }
        }
    }
    var photoSignaturesSelected: Bool {
        get {
            return selectedFields[40] != nil
        }
        set {
            if newValue && selectedFields[40] == nil {
                selectedFields[40] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[40] != nil {
                selectedFields.removeValue(forKey: 40)
            }
        }
    }
    var exposureMeteringsSelected: Bool {
        get {
            return selectedFields[41] != nil
        }
        set {
            if newValue && selectedFields[41] == nil {
                selectedFields[41] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[41] != nil {
                selectedFields.removeValue(forKey: 41)
            }
        }
    }
    var storagePoliciesSelected: Bool {
        get {
            return selectedFields[42] != nil
        }
        set {
            if newValue && selectedFields[42] == nil {
                selectedFields[42] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[42] != nil {
                selectedFields.removeValue(forKey: 42)
            }
        }
    }
    var videoRecordingBitratesSelected: Bool {
        get {
            return selectedFields[43] != nil
        }
        set {
            if newValue && selectedFields[43] == nil {
                selectedFields[43] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[43] != nil {
                selectedFields.removeValue(forKey: 43)
            }
        }
    }
}
extension Arsdk_Camera_Capabilities {
    static var rulesFieldNumber: Int32 { 1 }
}
extension Arsdk_Camera_Config {
    static var selectedFieldsFieldNumber: Int32 { 1 }
    static var cameraModeFieldNumber: Int32 { 2 }
    static var photoModeFieldNumber: Int32 { 3 }
    static var photoDynamicRangeFieldNumber: Int32 { 4 }
    static var photoResolutionFieldNumber: Int32 { 5 }
    static var photoFormatFieldNumber: Int32 { 6 }
    static var photoFileFormatFieldNumber: Int32 { 7 }
    static var photoBurstValueFieldNumber: Int32 { 8 }
    static var photoBracketingPresetFieldNumber: Int32 { 9 }
    static var photoTimeLapseIntervalFieldNumber: Int32 { 10 }
    static var photoGpsLapseIntervalFieldNumber: Int32 { 11 }
    static var photoStreamingModeFieldNumber: Int32 { 12 }
    static var videoRecordingModeFieldNumber: Int32 { 13 }
    static var videoRecordingDynamicRangeFieldNumber: Int32 { 14 }
    static var videoRecordingCodecFieldNumber: Int32 { 15 }
    static var videoRecordingResolutionFieldNumber: Int32 { 16 }
    static var videoRecordingFramerateFieldNumber: Int32 { 17 }
    static var audioRecordingModeFieldNumber: Int32 { 19 }
    static var exposureModeFieldNumber: Int32 { 22 }
    static var exposureManualShutterSpeedFieldNumber: Int32 { 23 }
    static var exposureManualIsoSensitivityFieldNumber: Int32 { 24 }
    static var exposureMaximumIsoSensitivityFieldNumber: Int32 { 25 }
    static var whiteBalanceModeFieldNumber: Int32 { 26 }
    static var whiteBalanceTemperatureFieldNumber: Int32 { 27 }
    static var evCompensationFieldNumber: Int32 { 28 }
    static var imageStyleFieldNumber: Int32 { 29 }
    static var imageContrastFieldNumber: Int32 { 30 }
    static var imageSaturationFieldNumber: Int32 { 31 }
    static var imageSharpnessFieldNumber: Int32 { 32 }
    static var zoomMaxSpeedFieldNumber: Int32 { 33 }
    static var zoomVelocityControlQualityModeFieldNumber: Int32 { 34 }
    static var autoRecordModeFieldNumber: Int32 { 35 }
    static var alignmentOffsetPitchFieldNumber: Int32 { 36 }
    static var alignmentOffsetRollFieldNumber: Int32 { 37 }
    static var alignmentOffsetYawFieldNumber: Int32 { 38 }
    static var photoSignatureFieldNumber: Int32 { 39 }
    static var exposureMeteringFieldNumber: Int32 { 40 }
    static var storagePolicyFieldNumber: Int32 { 41 }
    static var videoRecordingBitrateFieldNumber: Int32 { 42 }
    var selectedFieldsSelected: Bool {
        get {
            return selectedFields[1] != nil
        }
        set {
            if newValue && selectedFields[1] == nil {
                selectedFields[1] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[1] != nil {
                selectedFields.removeValue(forKey: 1)
            }
        }
    }
    var cameraModeSelected: Bool {
        get {
            return selectedFields[2] != nil
        }
        set {
            if newValue && selectedFields[2] == nil {
                selectedFields[2] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[2] != nil {
                selectedFields.removeValue(forKey: 2)
            }
        }
    }
    var photoModeSelected: Bool {
        get {
            return selectedFields[3] != nil
        }
        set {
            if newValue && selectedFields[3] == nil {
                selectedFields[3] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[3] != nil {
                selectedFields.removeValue(forKey: 3)
            }
        }
    }
    var photoDynamicRangeSelected: Bool {
        get {
            return selectedFields[4] != nil
        }
        set {
            if newValue && selectedFields[4] == nil {
                selectedFields[4] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[4] != nil {
                selectedFields.removeValue(forKey: 4)
            }
        }
    }
    var photoResolutionSelected: Bool {
        get {
            return selectedFields[5] != nil
        }
        set {
            if newValue && selectedFields[5] == nil {
                selectedFields[5] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[5] != nil {
                selectedFields.removeValue(forKey: 5)
            }
        }
    }
    var photoFormatSelected: Bool {
        get {
            return selectedFields[6] != nil
        }
        set {
            if newValue && selectedFields[6] == nil {
                selectedFields[6] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[6] != nil {
                selectedFields.removeValue(forKey: 6)
            }
        }
    }
    var photoFileFormatSelected: Bool {
        get {
            return selectedFields[7] != nil
        }
        set {
            if newValue && selectedFields[7] == nil {
                selectedFields[7] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[7] != nil {
                selectedFields.removeValue(forKey: 7)
            }
        }
    }
    var photoBurstValueSelected: Bool {
        get {
            return selectedFields[8] != nil
        }
        set {
            if newValue && selectedFields[8] == nil {
                selectedFields[8] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[8] != nil {
                selectedFields.removeValue(forKey: 8)
            }
        }
    }
    var photoBracketingPresetSelected: Bool {
        get {
            return selectedFields[9] != nil
        }
        set {
            if newValue && selectedFields[9] == nil {
                selectedFields[9] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[9] != nil {
                selectedFields.removeValue(forKey: 9)
            }
        }
    }
    var photoTimeLapseIntervalSelected: Bool {
        get {
            return selectedFields[10] != nil
        }
        set {
            if newValue && selectedFields[10] == nil {
                selectedFields[10] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[10] != nil {
                selectedFields.removeValue(forKey: 10)
            }
        }
    }
    var photoGpsLapseIntervalSelected: Bool {
        get {
            return selectedFields[11] != nil
        }
        set {
            if newValue && selectedFields[11] == nil {
                selectedFields[11] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[11] != nil {
                selectedFields.removeValue(forKey: 11)
            }
        }
    }
    var photoStreamingModeSelected: Bool {
        get {
            return selectedFields[12] != nil
        }
        set {
            if newValue && selectedFields[12] == nil {
                selectedFields[12] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[12] != nil {
                selectedFields.removeValue(forKey: 12)
            }
        }
    }
    var videoRecordingModeSelected: Bool {
        get {
            return selectedFields[13] != nil
        }
        set {
            if newValue && selectedFields[13] == nil {
                selectedFields[13] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[13] != nil {
                selectedFields.removeValue(forKey: 13)
            }
        }
    }
    var videoRecordingDynamicRangeSelected: Bool {
        get {
            return selectedFields[14] != nil
        }
        set {
            if newValue && selectedFields[14] == nil {
                selectedFields[14] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[14] != nil {
                selectedFields.removeValue(forKey: 14)
            }
        }
    }
    var videoRecordingCodecSelected: Bool {
        get {
            return selectedFields[15] != nil
        }
        set {
            if newValue && selectedFields[15] == nil {
                selectedFields[15] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[15] != nil {
                selectedFields.removeValue(forKey: 15)
            }
        }
    }
    var videoRecordingResolutionSelected: Bool {
        get {
            return selectedFields[16] != nil
        }
        set {
            if newValue && selectedFields[16] == nil {
                selectedFields[16] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[16] != nil {
                selectedFields.removeValue(forKey: 16)
            }
        }
    }
    var videoRecordingFramerateSelected: Bool {
        get {
            return selectedFields[17] != nil
        }
        set {
            if newValue && selectedFields[17] == nil {
                selectedFields[17] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[17] != nil {
                selectedFields.removeValue(forKey: 17)
            }
        }
    }
    var audioRecordingModeSelected: Bool {
        get {
            return selectedFields[19] != nil
        }
        set {
            if newValue && selectedFields[19] == nil {
                selectedFields[19] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[19] != nil {
                selectedFields.removeValue(forKey: 19)
            }
        }
    }
    var exposureModeSelected: Bool {
        get {
            return selectedFields[22] != nil
        }
        set {
            if newValue && selectedFields[22] == nil {
                selectedFields[22] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[22] != nil {
                selectedFields.removeValue(forKey: 22)
            }
        }
    }
    var exposureManualShutterSpeedSelected: Bool {
        get {
            return selectedFields[23] != nil
        }
        set {
            if newValue && selectedFields[23] == nil {
                selectedFields[23] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[23] != nil {
                selectedFields.removeValue(forKey: 23)
            }
        }
    }
    var exposureManualIsoSensitivitySelected: Bool {
        get {
            return selectedFields[24] != nil
        }
        set {
            if newValue && selectedFields[24] == nil {
                selectedFields[24] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[24] != nil {
                selectedFields.removeValue(forKey: 24)
            }
        }
    }
    var exposureMaximumIsoSensitivitySelected: Bool {
        get {
            return selectedFields[25] != nil
        }
        set {
            if newValue && selectedFields[25] == nil {
                selectedFields[25] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[25] != nil {
                selectedFields.removeValue(forKey: 25)
            }
        }
    }
    var whiteBalanceModeSelected: Bool {
        get {
            return selectedFields[26] != nil
        }
        set {
            if newValue && selectedFields[26] == nil {
                selectedFields[26] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[26] != nil {
                selectedFields.removeValue(forKey: 26)
            }
        }
    }
    var whiteBalanceTemperatureSelected: Bool {
        get {
            return selectedFields[27] != nil
        }
        set {
            if newValue && selectedFields[27] == nil {
                selectedFields[27] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[27] != nil {
                selectedFields.removeValue(forKey: 27)
            }
        }
    }
    var evCompensationSelected: Bool {
        get {
            return selectedFields[28] != nil
        }
        set {
            if newValue && selectedFields[28] == nil {
                selectedFields[28] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[28] != nil {
                selectedFields.removeValue(forKey: 28)
            }
        }
    }
    var imageStyleSelected: Bool {
        get {
            return selectedFields[29] != nil
        }
        set {
            if newValue && selectedFields[29] == nil {
                selectedFields[29] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[29] != nil {
                selectedFields.removeValue(forKey: 29)
            }
        }
    }
    var imageContrastSelected: Bool {
        get {
            return selectedFields[30] != nil
        }
        set {
            if newValue && selectedFields[30] == nil {
                selectedFields[30] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[30] != nil {
                selectedFields.removeValue(forKey: 30)
            }
        }
    }
    var imageSaturationSelected: Bool {
        get {
            return selectedFields[31] != nil
        }
        set {
            if newValue && selectedFields[31] == nil {
                selectedFields[31] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[31] != nil {
                selectedFields.removeValue(forKey: 31)
            }
        }
    }
    var imageSharpnessSelected: Bool {
        get {
            return selectedFields[32] != nil
        }
        set {
            if newValue && selectedFields[32] == nil {
                selectedFields[32] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[32] != nil {
                selectedFields.removeValue(forKey: 32)
            }
        }
    }
    var zoomMaxSpeedSelected: Bool {
        get {
            return selectedFields[33] != nil
        }
        set {
            if newValue && selectedFields[33] == nil {
                selectedFields[33] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[33] != nil {
                selectedFields.removeValue(forKey: 33)
            }
        }
    }
    var zoomVelocityControlQualityModeSelected: Bool {
        get {
            return selectedFields[34] != nil
        }
        set {
            if newValue && selectedFields[34] == nil {
                selectedFields[34] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[34] != nil {
                selectedFields.removeValue(forKey: 34)
            }
        }
    }
    var autoRecordModeSelected: Bool {
        get {
            return selectedFields[35] != nil
        }
        set {
            if newValue && selectedFields[35] == nil {
                selectedFields[35] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[35] != nil {
                selectedFields.removeValue(forKey: 35)
            }
        }
    }
    var alignmentOffsetPitchSelected: Bool {
        get {
            return selectedFields[36] != nil
        }
        set {
            if newValue && selectedFields[36] == nil {
                selectedFields[36] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[36] != nil {
                selectedFields.removeValue(forKey: 36)
            }
        }
    }
    var alignmentOffsetRollSelected: Bool {
        get {
            return selectedFields[37] != nil
        }
        set {
            if newValue && selectedFields[37] == nil {
                selectedFields[37] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[37] != nil {
                selectedFields.removeValue(forKey: 37)
            }
        }
    }
    var alignmentOffsetYawSelected: Bool {
        get {
            return selectedFields[38] != nil
        }
        set {
            if newValue && selectedFields[38] == nil {
                selectedFields[38] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[38] != nil {
                selectedFields.removeValue(forKey: 38)
            }
        }
    }
    var photoSignatureSelected: Bool {
        get {
            return selectedFields[39] != nil
        }
        set {
            if newValue && selectedFields[39] == nil {
                selectedFields[39] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[39] != nil {
                selectedFields.removeValue(forKey: 39)
            }
        }
    }
    var exposureMeteringSelected: Bool {
        get {
            return selectedFields[40] != nil
        }
        set {
            if newValue && selectedFields[40] == nil {
                selectedFields[40] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[40] != nil {
                selectedFields.removeValue(forKey: 40)
            }
        }
    }
    var storagePolicySelected: Bool {
        get {
            return selectedFields[41] != nil
        }
        set {
            if newValue && selectedFields[41] == nil {
                selectedFields[41] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[41] != nil {
                selectedFields.removeValue(forKey: 41)
            }
        }
    }
    var videoRecordingBitrateSelected: Bool {
        get {
            return selectedFields[42] != nil
        }
        set {
            if newValue && selectedFields[42] == nil {
                selectedFields[42] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[42] != nil {
                selectedFields.removeValue(forKey: 42)
            }
        }
    }
}
extension Arsdk_Camera_DoubleRange {
    static var minFieldNumber: Int32 { 1 }
    static var maxFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_ExposureRoi.Center {
    static var xFieldNumber: Int32 { 1 }
    static var yFieldNumber: Int32 { 2 }
}
extension Arsdk_Camera_ExposureRoi {
    static var centerFieldNumber: Int32 { 1 }
    static var widthFieldNumber: Int32 { 2 }
    static var heightFieldNumber: Int32 { 3 }
}
extension Arsdk_Camera_MediaMetadata {
    static var selectedFieldsFieldNumber: Int32 { 1 }
    static var copyrightFieldNumber: Int32 { 2 }
    static var customIdFieldNumber: Int32 { 3 }
    static var customTitleFieldNumber: Int32 { 4 }
    var selectedFieldsSelected: Bool {
        get {
            return selectedFields[1] != nil
        }
        set {
            if newValue && selectedFields[1] == nil {
                selectedFields[1] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[1] != nil {
                selectedFields.removeValue(forKey: 1)
            }
        }
    }
    var copyrightSelected: Bool {
        get {
            return selectedFields[2] != nil
        }
        set {
            if newValue && selectedFields[2] == nil {
                selectedFields[2] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[2] != nil {
                selectedFields.removeValue(forKey: 2)
            }
        }
    }
    var customIdSelected: Bool {
        get {
            return selectedFields[3] != nil
        }
        set {
            if newValue && selectedFields[3] == nil {
                selectedFields[3] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[3] != nil {
                selectedFields.removeValue(forKey: 3)
            }
        }
    }
    var customTitleSelected: Bool {
        get {
            return selectedFields[4] != nil
        }
        set {
            if newValue && selectedFields[4] == nil {
                selectedFields[4] = SwiftProtobuf.Google_Protobuf_Empty()
            } else if !newValue && selectedFields[4] != nil {
                selectedFields.removeValue(forKey: 4)
            }
        }
    }
}
