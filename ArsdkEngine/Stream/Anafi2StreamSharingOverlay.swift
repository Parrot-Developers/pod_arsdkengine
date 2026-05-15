// Copyright (C) 2024 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import GroundSdk

/// Controller that retrieves data for stream sharing overlay from Anafi family drones.
class Anafi2StreamSharingOverlay: DeviceComponentController {

    /// Camera identifiers, by camera model.
    private var cameraIds = [Camera2Model: UInt64]()

    /// Latest thermal mode received.
    private var thermalEnabled: Bool = false

    /// Latest recording state received.
    private var recordingState: Camera2RecordingState?

    /// Empty configuration.
    private static let emptyConfig = Camera2ConfigCore.Config(params: [Camera2ParamId: ParamValueBase]())

    /// Drone configuration, contains configuration updates from the drone.
    private var droneConfig = emptyConfig

    /// Stream sharing manager utility.
    private var streamSharingManager: StreamSharingManager?

    /// Stream sharing manager monitor.
    private var streamSharingMonitor: MonitorCore?

    /// Decoder for backup link controller events.
    private var arsdkDecoder: ArsdkCameraEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkCameraEventDecoder(listener: self)
        streamSharingManager = deviceController.engine.utilities.getUtility(Utilities.streamSharingManager)
    }

    override func didConnect() {
        streamSharingMonitor = streamSharingManager?.startMonitoring(
            didEnable: {},
            serviceDidStart: {},
            recordingStateDidChange: { [weak self] state, _, _ in
                if state == .recording {
                    self?.applyRecordingFormat()
                    self?.applyRecordingState()
                }
            },
            streamingStateDidChange: { [weak self] state, _, _ in
                if state == .streaming {
                    self?.applyRecordingFormat()
                    self?.applyRecordingState()
                }
            })
    }

    override func didDisconnect() {
        streamSharingMonitor?.stop()
        streamSharingMonitor = nil
        droneConfig = Anafi2StreamSharingOverlay.emptyConfig
        thermalEnabled = false
        recordingState = nil
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonNetworkeventUid {
            ArsdkFeatureCommonNetworkevent.decode(command, callback: self)
        } else {
            arsdkDecoder.decode(command)
        }
    }

    /// Applies received recording format to stream sharing backend.
    private func applyRecordingFormat() {
        let resolution: ArsdkStreamOverlayResolution?

        switch droneConfig[Camera2Params.mode] {
        case .photo:
            resolution = droneConfig[Camera2Params.photoResolution]?.stsh
        case .recording:
            resolution = droneConfig[Camera2Params.videoRecordingResolution]?.stsh
        default:
            resolution = nil
        }

        guard let resolution = resolution else { return }

        streamSharingManager?.setRecordingFormat(
            resolution: resolution,
            framerate: droneConfig[Camera2Params.videoRecordingFramerate]?.rawValue ?? 0,
            isThermal: thermalEnabled)
    }

    /// Applies received recording state to stream sharing backend.
    private func applyRecordingState() {
        guard let recordingState = recordingState else { return }

        switch recordingState {
        case let .started(_, duration, _, _):
            streamSharingManager?.setRecordingState(recording: true, duration: duration())
        default:
            streamSharingManager?.setRecordingState(recording: false, duration: 0)

        }
    }
}

/// Extension for Camera2 events processing.
extension Anafi2StreamSharingOverlay: ArsdkCameraEventDecoderListener {

    func onCameraList(_ cameraList: Arsdk_Camera_Event.CameraList) {
        cameraList.cameras.forEach { descriptor in
            if let model = Camera2Model.from(model: descriptor.value) {
                cameraIds[model] = descriptor.key
            }
        }
    }

    func onState(_ state: Arsdk_Camera_Event.State) {
        guard !state.activeSelected || state.active else { return }

        if state.configSelected {
            droneConfig = state.config.toGsdkConfig(defaultConfig: droneConfig)
            thermalEnabled = state.cameraID == cameraIds[.blendedThermal]
            applyRecordingFormat()
        }

        if state.recordingSelected {
            if state.recording.state == .active {
                let startTime =
                TimeProvider.dispatchTime.uptimeSeconds - Double(state.recording.duration.value) / 1000.0
                recordingState = .started(
                    startTimeOnSystemClock: 0,
                    duration: {
                        TimeProvider.dispatchTime.uptimeSeconds - startTime
                    },
                    videoBitrate: 0, mediaStorage: nil
                )
            } else {
                recordingState = .stopped(latestSavedMediaId: nil)
            }
            applyRecordingState()
        }
    }

    func onCameraExposure(_ cameraExposure: Arsdk_Camera_Event.Exposure) {}

    func onZoomLevel(_ zoomLevel: Arsdk_Camera_Event.ZoomLevel) {}

    func onNextPhotoInterval(_ nextPhotoInterval: Arsdk_Camera_Event.NextPhotoInterval) {}

    func onPhoto(_ photo: Arsdk_Camera_Event.Photo) {}

    func onRecording(_ recording: Arsdk_Camera_Event.Recording) {}

    func onCameraWhiteBalance(_ cameraWhiteBalance: Arsdk_Camera_Event.WhiteBalance) {}

    func onRequestStreamCamera(_ requestStreamCamera: Arsdk_Camera_StreamCamera) {}
}

// Called back when a command of the feature ArsdkFeatureCommonNetworkeventCallback is decoded.
extension Anafi2StreamSharingOverlay: ArsdkFeatureCommonNetworkeventCallback {

    func onDisconnection(cause: ArsdkFeatureCommonNetworkeventDisconnectionCause) {
        if cause == .offButton {
            streamSharingManager?.finalizeRecord(reason: .peerShutdown)
        }
    }
}

/// Extension that adds conversion to `ArsdkStreamOverlayResolution`.
extension Camera2PhotoResolution {

    var stsh: ArsdkStreamOverlayResolution? {
        switch self {
        case .res12MegaPixels: return .photo12Mpx
        case .res21MegaPixels: return .photo21Mpx
        case .res48MegaPixels: return .photo48Mpx
        case .res50MegaPixels: return .photo50Mpx
        }
    }
}

/// Extension that adds conversion to `ArsdkStreamOverlayResolution`.
extension Camera2RecordingResolution {

    var stsh: ArsdkStreamOverlayResolution? {
        switch self {
        case .res720p: return .video720p
        case .res1080p: return .video1080p
        case .resUhd4k: return .video2160p
        }
    }
}
