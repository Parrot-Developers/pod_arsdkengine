// Copyright (C) 2020 Parrot Drones SAS
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
import SwiftProtobuf

/// Controller for camera2 peripherals.
class Camera2Router: DeviceComponentController {

    /// Component settings key prefix.
    private let settingKeyPrefix = "Camera2-"

    /// Camera controllers, by camera identifier.
    private var cameraControllers: [UInt64: Camera2Controller] = [:]

    /// Decoder for camera events.
    private var arsdkDecoder: ArsdkCameraEventDecoder!

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        arsdkDecoder = ArsdkCameraEventDecoder(listener: self)

        // load persisted camera controllers
        if GroundSdkConfig.sharedInstance.offlineSettings == .model {
            let entries = deviceController.deviceStore.getEntriesForPrefix(key: settingKeyPrefix)
            if let entries = entries {
                for key in entries {
                    let suffix: String = String(key.suffix(key.count - settingKeyPrefix.count))
                    if !suffix.isEmpty, let cameraId = UInt64(suffix) {
                        let zoomBackend = Camera2ZoomCommandEncoder(cameraId: cameraId)
                        let cameraController = Camera2Controller(store: deviceController.device.peripheralStore,
                                                                 deviceStore: deviceController.deviceStore
                                                                  .getSettingsStore(key: key),
                                                                 presetStore: deviceController.presetStore
                                                                  .getSettingsStore(key: key),
                                                                 id: cameraId,
                                                                 model: nil,
                                                                 backend: self,
                                                                 zoomBackend: zoomBackend)
                        cameraControllers[cameraId] = cameraController
                    }
                }
            }
        }
    }

    /// Drone is about to be forgotten.
    override func willForget() {
        super.willForget()
        cameraControllers.forEach {
            $1.willForget()
        }
    }

    /// Drone is about to be connected.
    override func willConnect() {
        super.willConnect()
        // send camera list query
        listCameras()
    }

    /// Drone is connected.
    override func didConnect() {
        cameraControllers.forEach {
            $1.didConnect()
        }
        super.didConnect()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        cameraControllers.forEach {
            $1.didDisconnect()
        }
        super.didDisconnect()
    }

    /// Preset did change.
    override func presetDidChange() {
        cameraControllers.forEach {
            let settingsKey = "\(settingKeyPrefix)\($0)"
            let presetStore = deviceController.presetStore.getSettingsStore(key: settingsKey)
            $1.presetDidChange(presetStore: presetStore)
        }
        super.presetDidChange()
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)

        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonMavlinkstateUid {
            ArsdkFeatureCommonMavlinkstate.decode(command, callback: self)
        }
    }
}

/// Extension for methods to send Camera2 commands.
extension Camera2Router {

    /// Sends to the drone a camera2 command.
    ///
    /// - Parameters:
    ///   - command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCameraCommand(_ command: Arsdk_Camera_Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = ArsdkCameraCommandEncoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }

    /// Sends command to query the list of cameras.
    private func listCameras() {
        var listCameras = Arsdk_Camera_Command.ListCameras()
        listCameras.modelFilter = Arsdk_Camera_CameraModel.allCases
        _ = sendCameraCommand(.listCameras(listCameras))
    }
}

/// Extension implementing Camera2CommandDelegate.
extension Camera2Router: Camera2CommandDelegate {

    func sendStateRequest(id: UInt64, requestDefaultCapabilities: Bool) -> Bool {
        var getState = Arsdk_Camera_Command.GetState()
        getState.cameraID = id
        getState.includeDefaultCapabilities = requestDefaultCapabilities
        return sendCameraCommand(.getState(getState))
    }

    func configure(id: UInt64, config: Camera2ConfigCore.Config) -> Bool {
        ULog.d(.tag, "Configure camera \(config.description)")
        var configure = Arsdk_Camera_Command.Configure()
        configure.cameraID = id
        configure.config = config.arsdkConfig
        return sendCameraCommand(.configure(configure))
    }

    func set(id: UInt64, exposureLockMode: Camera2ExposureLockMode, centerX: Double?, centerY: Double?) -> Bool {
        var lockExposure = Arsdk_Camera_Command.LockExposure()
        lockExposure.cameraID = id
        switch exposureLockMode {
        case .none:
            lockExposure.mode = .unlocked
        case .currentValues:
            lockExposure.mode = .fullLock
        case .region:
            lockExposure.mode = .roiLock
            lockExposure.roi = Arsdk_Camera_ExposureRoi.Center()
            lockExposure.roi.x = centerX ?? 0.0
            lockExposure.roi.y = centerY ?? 0.0
        }
        return sendCameraCommand(.lockExposure(lockExposure))
    }

    func set(id: UInt64, whiteBalanceLock: Camera2WhiteBalanceLockMode) -> Bool {
        var lockWhiteBalance = Arsdk_Camera_Command.LockWhiteBalance()
        lockWhiteBalance.cameraID = id
        lockWhiteBalance.mode = whiteBalanceLock.arsdkValue!
        return sendCameraCommand(.lockWhiteBalance(lockWhiteBalance))
    }

    func set(id: UInt64, mediaMetadata: [Camera2MediaMetadataType: String]) -> Bool {
        var setMediaMetadata = Arsdk_Camera_Command.SetMediaMetadata()
        setMediaMetadata.cameraID = id
        if let customId = mediaMetadata[.customId] {
            setMediaMetadata.metadata.customID = customId
            setMediaMetadata.metadata.customIdSelected = true
        }
        if let copyright = mediaMetadata[.copyright] {
            setMediaMetadata.metadata.copyright = copyright
            setMediaMetadata.metadata.copyrightSelected = true
        }
        if let customTitle = mediaMetadata[.customTitle] {
            setMediaMetadata.metadata.customTitle = customTitle
            setMediaMetadata.metadata.customTitleSelected = true
        }
        return sendCameraCommand(.setMediaMetadata(setMediaMetadata))
    }

    func startPhotoCapture(id: UInt64) -> Bool {
        var startPhoto = Arsdk_Camera_Command.StartPhoto()
        startPhoto.cameraID = id
        return sendCameraCommand(.startPhoto(startPhoto))
    }

    func stopPhotoCapture(id: UInt64) -> Bool {
        var stopPhoto = Arsdk_Camera_Command.StopPhoto()
        stopPhoto.cameraID = id
        return sendCameraCommand(.stopPhoto(stopPhoto))
    }

    func startRecording(id: UInt64) -> Bool {
        var startRecording = Arsdk_Camera_Command.StartRecording()
        startRecording.cameraID = id
        return sendCameraCommand(.startRecording(startRecording))
    }

    func stopRecording(id: UInt64) -> Bool {
        var stopRecording = Arsdk_Camera_Command.StopRecording()
        stopRecording.cameraID = id
        return sendCameraCommand(.stopRecording(stopRecording))
    }

    func registerNoAckEncoder(encoder: NoAckCmdEncoder) -> RegisteredNoAckCmdEncoder? {
        return deviceController.backend?.subscribeNoAckCommandEncoder(encoder: encoder)
    }

    func resetZoomLevel(id: UInt64) {
        var resetZoom = Arsdk_Camera_Command.ResetZoom()
        resetZoom.cameraID = id
        _ = sendCameraCommand(.resetZoom(resetZoom))
    }
}

/// Extension for Camera2 events processing.
extension Camera2Router: ArsdkCameraEventDecoderListener {
    /// Processes a `CameraList` event.
    ///
    /// - Parameter cameraList: event to process
    func onCameraList(_ cameraList: Arsdk_Camera_Event.CameraList) {
        cameraList.cameras.forEach { descriptor in
            let settingsKey = "\(settingKeyPrefix)\(descriptor.key)"
            if cameraControllers[descriptor.key] == nil,
                let model: Camera2Model = Camera2Model.from(model: descriptor.value) {
                let zoomBackend = Camera2ZoomCommandEncoder(cameraId: descriptor.key)
                let cameraController = Camera2Controller(store: deviceController.device.peripheralStore,
                                                         deviceStore: deviceController.deviceStore
                                                          .getSettingsStore(key: settingsKey),
                                                         presetStore: deviceController.presetStore
                                                          .getSettingsStore(key: settingsKey),
                                                         id: descriptor.key,
                                                         model: model,
                                                         backend: self,
                                                         zoomBackend: zoomBackend)
                cameraControllers[descriptor.key] = cameraController
            }
            cameraControllers[descriptor.key]?.queryState()
        }
    }

    /// Processes a `State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Camera_Event.State) {
        guard let camera = cameraControllers[state.cameraID] else {
            ULog.w(.cameraTag, "Unknown camera \(state.cameraID)")
            return
        }
        camera.onState(state)
    }

    /// Processes a `Photo` event.
    ///
    /// - Parameter photo: event to process
    func onPhoto(_ photo: Arsdk_Camera_Event.Photo) {
        guard let camera = cameraControllers[photo.cameraID] else {
            ULog.w(.cameraTag, "Unknown camera \(photo.cameraID)")
            return
        }
        camera.onPhoto(photo)
    }

    /// Processes a `Recording` event.
    ///
    /// - Parameter recording: event to process
    func onRecording(_ recording: Arsdk_Camera_Event.Recording) {
        guard let camera = cameraControllers[recording.cameraID] else {
            ULog.w(.cameraTag, "Unknown camera \(recording.cameraID)")
            return
        }
        camera.onRecording(recording)
    }

    /// Processes a `NextPhotoInterval` event.
    ///
    /// - Parameter nextPhotoInterval: event to process
    func onNextPhotoInterval(_ nextPhotoInterval: Arsdk_Camera_Event.NextPhotoInterval) {
        guard let camera = cameraControllers[nextPhotoInterval.cameraID] else {
            ULog.w(.cameraTag, "Unknown camera \(nextPhotoInterval.cameraID)")
            return
        }
        camera.onNextPhotoInterval(nextPhotoInterval)
    }

    /// Processes an `Exposure` event.
    ///
    /// - Parameter exposure: event to process
    func onCameraExposure(_ exposure: Arsdk_Camera_Event.Exposure) {
        guard let camera = cameraControllers[exposure.cameraID] else {
            ULog.w(.cameraTag, "Unknown camera \(exposure.cameraID)")
            return
        }
        camera.onExposure(exposure)
    }

    /// Processes a `ZoomLevel` event.
    ///
    /// - Parameter zoom: event to process
    func onZoomLevel(_ zoom: Arsdk_Camera_Event.ZoomLevel) {
        guard let camera = cameraControllers[zoom.cameraID] else {
            ULog.w(.cameraTag, "Unknown camera \(zoom.cameraID)")
            return
        }
        camera.onZoom(zoom)
    }
}

/// Extension for flight plan state events processing.
extension Camera2Router: ArsdkFeatureCommonMavlinkstateCallback {
    func onMavlinkFilePlayingStateChanged(
        state: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState,
        filepath: String!, type: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedType) {
        cameraControllers.forEach { $0.value.onMavlinkFilePlayingStateChanged(state: state) }
    }
}
