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

/// Delegate to send Camera2 commands.
protocol Camera2CommandDelegate: AnyObject {
    /// Sends camera state request.
    ///
    /// - Parameters:
    ///   - id: camera id
    ///   - requestDefaultCapabilities: `true` to query default capabilities
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func sendStateRequest(id: UInt64, requestDefaultCapabilities: Bool) -> Bool

    /// Sends command to change the camera configuration.
    ///
    /// - Parameters:
    ///   - id: camera id
    ///   - config: new configuration
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func configure(id: UInt64, config: Camera2ConfigCore.Config) -> Bool

    /// Sends command to change the exposure lock mode.
    ///
    /// - Parameters:
    ///   - id: camera id
    ///   - exposureLockMode: requested exposure lock mode
    ///   - centerX: horizontal position of lock exposure region when `exposureLockMode` is `region`
    ///   - centerY: vertical position of lock exposure region when `exposureLockMode` is `region`
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func set(id: UInt64, exposureLockMode: Camera2ExposureLockMode, centerX: Double?, centerY: Double?) -> Bool

    /// Sends command to change the white balance lock mode.
    ///
    /// - Parameters:
    ///   - id: camera id
    ///   - whiteBalanceLock: requested white balance lock mode
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func set(id: UInt64, whiteBalanceLock: Camera2WhiteBalanceLockMode) -> Bool

    /// Sends command to change media metadata.
    ///
    /// - Parameters:
    ///   - id: camera id
    ///   - mediaMetadata: requested media metadata
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func set(id: UInt64, mediaMetadata: [Camera2MediaMetadataType: String]) -> Bool

    /// Sends command to start photo capture.
    ///
    /// - Parameter id: camera id
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func startPhotoCapture(id: UInt64) -> Bool

    /// Sends command to stop photo capture.
    ///
    /// - Parameter id: camera id
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func stopPhotoCapture(id: UInt64) -> Bool

    /// Sends command to start recording.
    ///
    /// - Parameter id: camera id
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func startRecording(id: UInt64) -> Bool

    /// Sends command to stop recording.
    ///
    /// - Parameter id: camera id
    /// - Returns: `true` if the command has been sent, `false`otherwise
    func stopRecording(id: UInt64) -> Bool

    /// Registers a `NoAckCmdEncoder`. Used for zoom commands.
    ///
    /// - Parameter encoder: encoder to register
    func registerNoAckEncoder(encoder: NoAckCmdEncoder) -> RegisteredNoAckCmdEncoder?

    /// Resets zoom level.
    ///
    /// The camera will reset the zoom level to 1, as fast as it can.
    ///
    /// - Parameter id: camera id
    func resetZoomLevel(id: UInt64)
}

/// Camera2 controller.
class Camera2Controller {

    /// Camera2 component.
    private(set) var camera: Camera2Core!

    /// Delegate to send commands.
    private unowned let backend: Camera2CommandDelegate

    /// Zoom backend.
    private var zoomBackend: Camera2ZoomCommandEncoder

    /// Registered zoom commands encoder.
    private var registeredZoomEncoder: RegisteredNoAckCmdEncoder?

    /// Store device specific values.
    private var deviceStore: SettingsStore?

    /// Preset store.
    private var presetStore: SettingsStore?

    /// All settings that can be stored.
    enum SettingKey: String, StoreKey {
        case modelKey = "model"
        case capabilitiesKey = "capabilities"
        case configKey = "config"
    }

    /// Stored settings.
    enum Setting: Hashable {
        /// Camera model.
        case model(Camera2Model)
        /// Camera configuration.
        case config(Camera2ConfigCore.Config)

        /// All values to allow enumerating settings.
        static let allCases: Set<Setting> = [
            .model(.main),
            .config(Camera2Controller.emptyConfig)
        ]

        /// Setting storage key.
        var key: SettingKey {
            switch self {
            case .model: return .modelKey
            case .config: return .configKey
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings.
    enum Capabilities: Hashable {
        /// Camera capabilities.
        case capabilities(Camera2ConfigCore.Capabilities)

        /// All values to allow enumerating capabilities.
        static let allCases: Set<Capabilities> = [
            .capabilities(Camera2ConfigCore.Capabilities(rules: [:]))
        ]

        /// Capabilities storage key.
        var key: SettingKey {
            switch self {
            case .capabilities: return .capabilitiesKey
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Capabilities, rhs: Capabilities) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Setting values as received from the drone.
    private var droneSettings = Set<Setting>()

    /// Whether camera is active.
    private var active: Bool {
        get {
            _active
        }
        set {
            if _active != newValue {
                _active = newValue
                camera.update(isActive: _active)
                registeredZoomEncoder?.unregister()
                registeredZoomEncoder = nil
                if _active {
                    if zoomReceived {
                        registeredZoomEncoder = backend.registerNoAckEncoder(encoder: zoomBackend)
                        camera.zoom.publish()
                    }
                    if photoStateReceived {
                        camera.photoCapture.publish()
                    }
                    if recordingStateReceived {
                        camera.recording.publish()
                    }
                    if exposureLockStateReceived {
                        camera.exposureLock.publish()
                    }
                    if whiteBalanceLockStateReceived {
                        camera.whiteBalanceLock.publish()
                    }
                    if mediaMetadataStateReceived {
                        camera.mediaMetadata.publish()
                    }
                    if photoProgressReceived {
                        camera.photoProgressIndicator.publish()
                    }
                    if exposureReceived {
                        camera.exposureIndicator.publish()
                    }
                } else {
                    camera.photoCapture.unpublish()
                    camera.recording.unpublish()
                    camera.exposureLock.unpublish()
                    camera.whiteBalanceLock.unpublish()
                    camera.mediaMetadata.unpublish()
                    camera.photoProgressIndicator.unpublish()
                    camera.exposureIndicator.unpublish()
                    camera.zoom.unpublish()
                }
            }
        }
    }

    /// Whether camera is active.
    private var _active = false

    /// Whether the drone is connected.
    public var connected: Bool = false

    /// Camera identifier.
    private let id: UInt64

    /// Empty capabilities.
    private let emptyCapabilities = Camera2ConfigCore.Capabilities(rules: [:])

    /// Camera default capabilities.
    private var defaultCapabilities: Camera2ConfigCore.Capabilities?

    /// Empty configuration.
    private static let emptyConfig = Camera2ConfigCore.Config(params: [Camera2ParamId: ParamValueBase]())

    /// Current configuration. Loaded from presets and merged with configuration updates from the drone.
    private var currentConfig = emptyConfig

    /// Whether camera state event has been received since connection to drone.
    private var stateReceived = false

    /// Whether a photo state event has been received since connection to drone.
    private var photoStateReceived = false

    /// Whether a recording state event has been received since connection to drone.
    private var recordingStateReceived = false

    /// Whether an exposure lock state event has been received since connection to drone.
    private var exposureLockStateReceived = false

    /// Whether a white balance lock state event has been received since connection to drone.
    private var whiteBalanceLockStateReceived = false

    /// Whether a media metata state event has been received since connection to drone.
    private var mediaMetadataStateReceived = false

    /// Whether a photo progress event has been received since connection to drone.
    private var photoProgressReceived = false

    /// Whether an exposure event has been received since connection to drone.
    private var exposureReceived = false

    /// Whether a zoom event or zoom state event has been received since connection to drone.
    private var zoomReceived = false

    /// Flight plan execution state.
    ///
    /// At connection, camera presets should not be sent to drone if a flight plan is playing.
    private var flightPlanState: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState?

    /// Constructor.
    ///
    /// - Parameters:
    ///    - store: store where this peripheral will be stored
    ///    - deviceStore: store for device specific values
    ///    - presetStore: preset store
    ///    - id: camera id
    ///    - model: camera model
    ///    - backend: camera commands delegate
    ///    - zoomBackend: camera zoom control command delegate
    init(store: ComponentStoreCore,
         deviceStore: SettingsStore?,
         presetStore: SettingsStore?,
         id: UInt64,
         model: Camera2Model?,
         backend: Camera2CommandDelegate,
         zoomBackend: Camera2ZoomCommandEncoder) {
        self.deviceStore = deviceStore
        self.presetStore = presetStore
        self.id = id
        self.backend = backend
        self.zoomBackend = zoomBackend

        var _model: Camera2Model
        if let model = model {
            _model = model
            settingDidChange(.model(_model))
        } else {
            if let model: Camera2Model = presetStore?.read(key: SettingKey.modelKey) {
                _model = model
            } else {
                _model = .main
            }
        }

        switch _model {
        case .main:
            camera = MainCamera2Core(store: store, backend: self,
                                     initialConfig: currentConfig, capabilities: emptyCapabilities)
        }

        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadCapabilities()
            loadPresets()
            camera.publish()
        }
    }

    /// Called when preset changed.
    func presetDidChange(presetStore: SettingsStore) {
        // reload preset store
        self.presetStore = presetStore
        loadCapabilities()
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Loads the capabilities.
    /// Should be called before `loadPresets()`.
    private func loadCapabilities() {
        if let deviceStore = deviceStore {
            for capability in Capabilities.allCases {
                switch capability {
                case .capabilities:
                    if let capabilities: Camera2ConfigCore.Capabilities = deviceStore.read(key: capability.key) {
                        defaultCapabilities = capabilities
                        camera.update(capabilities: capabilities)
                    }
                }
            }
            camera.notifyUpdated()
        }
    }

    /// Loads saved settings.
    private func loadPresets() {
        if let presetStore = presetStore {
            for setting in Setting.allCases {
                switch setting {
                case .model:
                    break
                case .config:
                    if let config: Camera2ConfigCore.Config = presetStore.read(key: setting.key) {
                        currentConfig = config
                        camera.update(config: currentConfig)
                    }
                }
            }
        }
        camera.notifyUpdated()
    }

    /// Called when the drone is connected, save all settings received during the connection and not yet in the preset
    /// store.
    public func storeNewPresets() {
        if let presetStore = presetStore {
            for setting in droneSettings {
                switch setting {
                case .model(let model):
                    presetStore.writeIfNew(key: setting.key, value: model)
                case .config(let config):
                    presetStore.writeIfNew(key: setting.key, value: config)
                }
            }
            presetStore.commit()
        }
    }

    /// Applies presets.
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .model:
                break
            case .config(let config):
                // send camera presets only if flight plan is not playing
                if flightPlanState != .playing,
                   let preset: Camera2ConfigCore.Config = presetStore?.read(key: setting.key) {
                    if preset != config {
                        _ = backend.configure(id: id, config: preset.diffFrom(config))
                    }
                    camera.update(config: preset)
                } else {
                    camera.update(config: config)
                }
            }
        }
    }

    /// Called when a command that notifies a setting change has been received.
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.update(with: setting)

        switch setting {
        case .model:
            break
        case .config(let config):
            ULog.d(.tag, "Current camera config \(config.description)")
            currentConfig = config
            camera.update(config: currentConfig)
        }
    }

    /// Processes stored capabilities changes.
    ///
    /// - Parameter capabilities: changed capabilities
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .capabilities(let newCapabilities):
            deviceStore?.write(key: capabilities.key, value: newCapabilities)
            camera.update(capabilities: newCapabilities)
        }
        deviceStore?.commit()
    }

    /// Drone is connected.
    public func didConnect() {
        connected = true
        if stateReceived {
            storeNewPresets()
            applyPresets()
        }
    }

    /// Drone is disconnected.
    func didDisconnect() {
        connected = false
        stateReceived = false
        photoStateReceived = false
        recordingStateReceived = false
        exposureLockStateReceived = false
        whiteBalanceLockStateReceived = false
        mediaMetadataStateReceived = false
        photoProgressReceived = false
        exposureReceived = false
        zoomReceived = false
        currentConfig = Camera2Controller.emptyConfig
        flightPlanState = nil
        // set camera as inactive, this will unpublish components
        active = false
        camera.cancelRollback()
        // restore default capabilities for offline mode
        if let defaultCapabilities = defaultCapabilities {
            camera.update(capabilities: defaultCapabilities)
        }
        camera.notifyUpdated()
    }

    /// Drone is about to be forgotten.
    func willForget() {
        camera.photoCapture.unpublish()
        camera.recording.unpublish()
        camera.exposureLock.unpublish()
        camera.whiteBalanceLock.unpublish()
        camera.mediaMetadata.unpublish()
        camera.zoom.unpublish()
        camera.unpublish()
    }

    /// Sends state request to drone.
    func queryState() {
        // _ = backend.sendStateRequest(id: id, requestDefaultCapabilities: defaultCapabilities == nil)
        // TODO: for now we always query defaultCapabilities, as we have no way to tell if we
        //       need to update them or not (needs drone firmware version at connection time,
        //       plus some scheme to know whether the sdk version also did change)
        _ = backend.sendStateRequest(id: id, requestDefaultCapabilities: true)
    }
}

/// Extension implementing Camera2Backend.
extension Camera2Controller: Camera2Backend {
    func configure(config: Camera2ConfigCore.Config) -> Bool {
        presetStore?.write(key: SettingKey.configKey, value: config).commit()
        if connected {
            return backend.configure(id: id, config: config.diffFrom(currentConfig))
        } else {
            camera.update(config: config).notifyUpdated()
            return false
        }
    }

    func set(exposureLockMode: Camera2ExposureLockMode, centerX: Double?, centerY: Double?) -> Bool {
        return active && backend.set(id: id, exposureLockMode: exposureLockMode, centerX: centerX, centerY: centerY)
    }

    func set(whiteBalanceLock: Camera2WhiteBalanceLockMode) -> Bool {
        return active && backend.set(id: id, whiteBalanceLock: whiteBalanceLock)
    }

    func set(mediaMetadata: [Camera2MediaMetadataType: String]) -> Bool {
        return active && backend.set(id: id, mediaMetadata: mediaMetadata)
    }

    func startPhotoCapture() -> Bool {
        return active && backend.startPhotoCapture(id: id)
    }

    func stopPhotoCapture() -> Bool {
        return active && backend.stopPhotoCapture(id: id)
    }

    func startRecording() -> Bool {
        return active && backend.startRecording(id: id)
    }

    func stopRecording() -> Bool {
        return active && backend.stopRecording(id: id)
    }

    func control(mode: Camera2ZoomControlMode, target: Double) {
        if active {
            zoomBackend.control(mode: mode, target: target)
        }
    }

    func resetZoomLevel() {
        if active {
            // cancel any ongoing control command
            zoomBackend.cancelControl()
            // send reset zoom command
            backend.resetZoomLevel(id: id)
        }
    }
}

/// Extension for Camera2 events processing.
extension Camera2Controller {

    /// Processes a `State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Camera_Event.State) {
        if state.defaultCapabilitiesSelected {
            defaultCapabilities = state.defaultCapabilities.gsdkCapabilities
            capabilitiesDidChange(.capabilities(defaultCapabilities!))
        }
        if state.currentCapabilitiesSelected,
            let defaultCapabilities = defaultCapabilities {
            let capabilities = defaultCapabilities.overriddenBy(other: state.currentCapabilities.gsdkCapabilities)
            camera.update(capabilities: capabilities)
        }
        if state.configSelected {
            settingDidChange(.config(state.config.toGsdkConfig(defaultConfig: currentConfig)))
        }
        if state.activeSelected {
            active = state.active
        }
        if state.photoSelected {
            onPhotoState(state.photo)
        }
        if state.recordingSelected {
            onRecordingState(state.recording)
        }
        if state.exposureLockSelected {
            onExposureLockState(state.exposureLock)
        }
        if state.whiteBalanceLockSelected {
            onWhiteBalanceLockState(state.whiteBalanceLock)
        }
        if state.mediaMetadataSelected {
            onMediaMetadataState(state.mediaMetadata)
        }
        if state.zoomSelected {
            onZoomState(state.zoom)
        }

        if !stateReceived && connected {
            storeNewPresets()
            applyPresets()
        }
        stateReceived = true
        camera.notifyUpdated()
        camera.publish()
    }

    /// Processes a `Photo` state.
    ///
    /// - Parameter photo: state to process
    private func onPhotoState(_ photo: Arsdk_Camera_Event.State.Photo) {
        photoStateReceived = true
        switch photo.state {
        case .active:
            let startTime = Date(timeIntervalSince1970: Double(photo.startTimestamp) / 1000.0)
            let photoCount = Int(photo.photoCount)
            camera.photoCapture.update(state: .started(startTime: startTime, photoCount: photoCount,
                                                       mediaStorage: StorageType(fromArsdk: photo.storage)))
            if active {
                camera.photoCapture.publish()
            }
        case .inactive:
            var latestSavedMediaId: String?
            if case .stopping(_, let savedMediaId) = camera.photoCapture.state {
                latestSavedMediaId = savedMediaId
            }
            camera.photoCapture.update(state: .stopped(latestSavedMediaId: latestSavedMediaId))
            if active {
                camera.photoCapture.publish()
            }
        case .unavailable:
            camera.photoCapture.unpublish()
        case .UNRECOGNIZED:
            ULog.w(.tag, "Unknown photo state, skipping this event.")
        }
        camera.photoCapture.notifyUpdated()
    }

    /// Processes a `Recording` state.
    ///
    /// - Parameter recording: state to process
    private func onRecordingState(_ recording: Arsdk_Camera_Event.State.Recording) {
        recordingStateReceived = true
        switch recording.state {
        case .active:
            let startTime = Date(timeIntervalSince1970: Double(recording.startTimestamp) / 1000.0)
            camera.recording.update(state: .started(startTime: startTime, videoBitrate: UInt(recording.videoBitrate),
                                                    mediaStorage: StorageType(fromArsdk: recording.storage)))
            if active {
                camera.recording.publish()
            }
        case .inactive:
            var latestSavedMediaId: String?
            if case .stopping(_, let savedMediaId) = camera.recording.state {
                latestSavedMediaId = savedMediaId
            }
            camera.recording.update(state: .stopped(latestSavedMediaId: latestSavedMediaId))
            if active {
                camera.recording.publish()
            }
        case .unavailable:
            camera.recording.unpublish()
        case .UNRECOGNIZED:
            ULog.w(.tag, "Unknown recording state, skipping this event.")
        }
        camera.recording.notifyUpdated()
    }

    /// Processes an `ExposureLock` state.
    ///
    /// - Parameter exposureLock: state to process
    private func onExposureLockState(_ exposureLock: Arsdk_Camera_Event.State.ExposureLock) {
        exposureLockStateReceived = true
        if let mode = Camera2ExposureLockMode(fromArsdk: exposureLock.mode) {
            camera.exposureLock.update(mode: mode)
        } else {
            ULog.w(.tag, "Unknown exposure lock mode, ignoring.")
        }
        let supportModes = Set(exposureLock.supportedModes.compactMap { Camera2ExposureLockMode(fromArsdk: $0) })
        camera.exposureLock.update(supportedModes: supportModes).notifyUpdated()
        if active {
            camera.exposureLock.publish()
        }
    }

    /// Processes a `WhiteBalanceLock` state.
    ///
    /// - Parameter whiteBalanceLock: state to process
    private func onWhiteBalanceLockState(_ whiteBalanceLock: Arsdk_Camera_Event.State.WhiteBalanceLock) {
        whiteBalanceLockStateReceived = true
        if let mode = Camera2WhiteBalanceLockMode(fromArsdk: whiteBalanceLock.mode) {
            camera.whiteBalanceLock.update(mode: mode)
        } else {
            ULog.w(.tag, "Unknown white balance lock mode, ignoring.")
        }
        let supportModes
            = Set(whiteBalanceLock.supportedModes.compactMap { Camera2WhiteBalanceLockMode(fromArsdk: $0) })
        camera.whiteBalanceLock.update(supportedModes: supportModes).notifyUpdated()
        if active {
            camera.whiteBalanceLock.publish()
        }
    }

    /// Processes a `MediaMetadata` state.
    ///
    /// - Parameter mediaMetadata: state to process
    private func onMediaMetadataState(_ mediaMetadata: Arsdk_Camera_MediaMetadata) {
        mediaMetadataStateReceived = true
        var metadata = [Camera2MediaMetadataType: String]()
        if mediaMetadata.customIdSelected {
            metadata[.customId] = mediaMetadata.customID
        }
        if mediaMetadata.copyrightSelected {
            metadata[.copyright] = mediaMetadata.copyright
        }
        if mediaMetadata.customTitleSelected {
            metadata[.customTitle] = mediaMetadata.customTitle
        }
        camera.mediaMetadata.update(mediaMetadata: metadata).notifyUpdated()
        if active {
            camera.mediaMetadata.publish()
        }
    }

    /// Processes a `Zoom` state.
    ///
    /// - Parameter zoom: state to process
    private func onZoomState(_ zoom: Arsdk_Camera_Event.State.Zoom) {
        zoomReceived = true
        camera.zoom.update(maxLevel: zoom.zoomLevelMax)
            .update(maxLossLessLevel: zoom.zoomHighQualityLevelMax)
            .notifyUpdated()
        if active {
            if registeredZoomEncoder == nil {
                registeredZoomEncoder = backend.registerNoAckEncoder(encoder: zoomBackend)
            }
            camera.zoom.publish()
        }
    }

    /// Processes a `Photo` event.
    ///
    /// - Parameter photo: event to process
    func onPhoto(_ photo: Arsdk_Camera_Event.Photo) {
        switch photo.type {
        case .stop:
            let reason = Camera2PhotoCaptureState.StopReason(fromArsdk: photo.stopReason) ?? .errorInternal
            let savedMediaId = photo.mediaID.isEmpty ? nil : photo.mediaID
            camera.photoCapture.update(state: .stopping(reason: reason, savedMediaId: savedMediaId))
                .notifyUpdated()
        default:
            break
        }
    }

    /// Processes a `Recording` event.
    ///
    /// - Parameter recording: event to process
    func onRecording(_ recording: Arsdk_Camera_Event.Recording) {
        switch recording.type {
        case .stop, .stopping:
            let reason = Camera2RecordingState.StopReason(fromArsdk: recording.stopReason) ?? .errorInternal
            let savedMediaId = recording.mediaID.isEmpty ? nil : recording.mediaID
            camera.recording.update(state: .stopping(reason: reason, savedMediaId: savedMediaId))
                .notifyUpdated()
        default:
            break
        }
    }

    /// Processes a `NextPhotoInterval` event.
    ///
    /// - Parameter nextPhotoInterval: event to process
    func onNextPhotoInterval(_ nextPhotoInterval: Arsdk_Camera_Event.NextPhotoInterval) {
        photoProgressReceived = true
        switch nextPhotoInterval.mode {
        case .timeLapse:
            camera.photoProgressIndicator.resetRemainingDistance()
                .update(remainingTime: nextPhotoInterval.interval)
        case .gpsLapse:
            camera.photoProgressIndicator.resetRemainingTime()
                .update(remainingDistance: nextPhotoInterval.interval)
        default :
            camera.photoProgressIndicator.resetRemainingTime().resetRemainingDistance()
        }
        camera.photoProgressIndicator.notifyUpdated()
        if active {
            camera.photoProgressIndicator.publish()
        }
    }

    /// Processes an `Exposure` event.
    ///
    /// - Parameter exposure: event to process
    func onExposure(_ exposure: Arsdk_Camera_Event.Exposure) {
        exposureReceived = true
        if let isoSensitivity = Camera2Iso(fromArsdk: exposure.isoSensitivity) {
            camera.exposureIndicator.update(isoSensitivity: isoSensitivity)
        }
        if let shutterSpeed = Camera2ShutterSpeed(fromArsdk: exposure.shutterSpeed) {
            camera.exposureIndicator.update(shutterSpeed: shutterSpeed)
        }
        if exposure.hasExposureLockRegion,
            exposure.exposureLockRegion.hasCenter {
            camera.exposureIndicator.update(centerX: exposure.exposureLockRegion.center.x,
                                            centerY: exposure.exposureLockRegion.center.y,
                                            width: exposure.exposureLockRegion.width,
                                            height: exposure.exposureLockRegion.height)
        } else {
            camera.exposureIndicator.clearLockRegion()
        }
        camera.exposureIndicator.notifyUpdated()
        if active {
            camera.exposureIndicator.publish()
        }
    }

    /// Processes an `ZoomLevel` event.
    ///
    /// - Parameter zoom: event to process
    func onZoom(_ zoom: Arsdk_Camera_Event.ZoomLevel) {
        camera.zoom.update(level: zoom.level).notifyUpdated()
    }
}

/// Extension for flight plan state events processing.
extension Camera2Controller {
    /// Called when flight plan playing state is received from the drone.
    ///
    /// - Parameter state: flight plan state
    func onMavlinkFilePlayingStateChanged(
        state: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState) {
        flightPlanState = state
    }
}

/// Extension that adds conversion to gsdk.
extension Arsdk_Camera_Capabilities {
    /// Creates a new `Camera2ConfigCore.Capabilities` from `Arsdk_Camera_Capabilities`.
    var gsdkCapabilities: Camera2ConfigCore.Capabilities {
        let gsdkRules = rules.reduce(into: [Int: Camera2Rule]()) {
            $0[Int($1.index)] = $1.gsdkRule
        }
        return Camera2ConfigCore.Capabilities(rules: gsdkRules)
    }
}

/// Extension that adds conversion to gsdk.
extension Arsdk_Camera_Capabilities.Rule {
    /// Creates a new `Camera2Rule` from `Arsdk_Camera_Capabilities.Rule`.
    var gsdkRule: Camera2Rule {
        var rule = Camera2Rule(index: Int(index))

        if cameraModesSelected {
            rule[Camera2Params.mode] = Set(cameraModes.compactMap {Camera2Mode(fromArsdk: $0)})
        }
        if photoDynamicRangesSelected {
            rule[Camera2Params.photoDynamicRange]
                = Set(photoDynamicRanges.compactMap {Camera2DynamicRange(fromArsdk: $0)})
        }
        if photoModesSelected {
            rule[Camera2Params.photoMode] = Set(photoModes.compactMap {Camera2PhotoMode(fromArsdk: $0)})
        }
        if photoResolutionsSelected {
            rule[Camera2Params.photoResolution]
                = Set(photoResolutions.compactMap {Camera2PhotoResolution(fromArsdk: $0)})
        }
        if photoFormatsSelected {
            rule[Camera2Params.photoFormat] = Set(photoFormats.compactMap {Camera2PhotoFormat(fromArsdk: $0)})
        }
        if photoFileFormatsSelected {
            rule[Camera2Params.photoFileFormat]
                = Set(photoFileFormats.compactMap {Camera2PhotoFileFormat(fromArsdk: $0)})
        }
        if photoSignaturesSelected {
            rule[Camera2Params.photoDigitalSignature]
                = Set(photoSignatures.compactMap {Camera2DigitalSignature(fromArsdk: $0)})
        }
        if photoBracketingPresetsSelected {
            rule[Camera2Params.photoBracketing]
                = Set(photoBracketingPresets.compactMap {Camera2BracketingValue(fromArsdk: $0)})
        }
        if photoBurstValuesSelected {
            rule[Camera2Params.photoBurst] = Set(photoBurstValues.compactMap {Camera2BurstValue(fromArsdk: $0)})
        }
        if photoTimeLapseIntervalRangeSelected {
            rule[Camera2Params.photoTimelapseInterval]
                = photoTimeLapseIntervalRange.min...photoTimeLapseIntervalRange.max
        }
        if photoGpsLapseIntervalRangeSelected {
            rule[Camera2Params.photoGpslapseInterval] = photoGpsLapseIntervalRange.min...photoGpsLapseIntervalRange.max
        }
        if photoStreamingModesSelected {
            rule[Camera2Params.photoStreamingMode]
                = Set(photoStreamingModes.compactMap {Camera2PhotoStreamingMode(fromArsdk: $0)})
        }
        if videoRecordingModesSelected {
            rule[Camera2Params.videoRecordingMode]
                = Set(videoRecordingModes.compactMap {Camera2VideoRecordingMode(fromArsdk: $0)})
        }
        if videoRecordingDynamicRangesSelected {
            rule[Camera2Params.videoRecordingDynamicRange]
                = Set(videoRecordingDynamicRanges.compactMap {Camera2DynamicRange(fromArsdk: $0)})
        }
        if videoRecordingCodecsSelected {
            rule[Camera2Params.videoRecordingCodec]
                = Set(videoRecordingCodecs.compactMap {Camera2VideoCodec(fromArsdk: $0)})
        }
        if videoRecordingResolutionsSelected {
            rule[Camera2Params.videoRecordingResolution]
                = Set(videoRecordingResolutions.compactMap {Camera2RecordingResolution(fromArsdk: $0)})
        }
        if videoRecordingFrameratesSelected {
            rule[Camera2Params.videoRecordingFramerate]
                = Set(videoRecordingFramerates.compactMap {Camera2RecordingFramerate(fromArsdk: $0)})
        }
        if videoRecordingBitratesSelected {
            rule[Camera2Params.videoRecordingBitrate] = Set(videoRecordingBitrates.compactMap {UInt($0)})
        }
        if audioRecordingModesSelected {
            rule[Camera2Params.audioRecordingMode]
                = Set(audioRecordingModes.compactMap {Camera2AudioRecordingMode(fromArsdk: $0)})
        }
        if autoRecordModesSelected {
            rule[Camera2Params.autoRecordMode] = Set(autoRecordModes.compactMap {Camera2AutoRecordMode(fromArsdk: $0)})
        }
        if exposureModesSelected {
            rule[Camera2Params.exposureMode] = Set(exposureModes.compactMap {Camera2ExposureMode(fromArsdk: $0)})
        }
        if exposureMaximumIsoSensitivitiesSelected {
            rule[Camera2Params.maximumIsoSensitivity]
                = Set(exposureMaximumIsoSensitivities.compactMap {Camera2Iso(fromArsdk: $0)})
        }
        if exposureManualIsoSensitivitiesSelected {
            rule[Camera2Params.isoSensitivity]
                = Set(exposureManualIsoSensitivities.compactMap {Camera2Iso(fromArsdk: $0)})
        }
        if exposureManualShutterSpeedsSelected {
            rule[Camera2Params.shutterSpeed]
                = Set(exposureManualShutterSpeeds.compactMap {Camera2ShutterSpeed(fromArsdk: $0)})
        }
        if evCompensationsSelected {
            rule[Camera2Params.exposureCompensation]
                = Set(evCompensations.compactMap {Camera2EvCompensation(fromArsdk: $0)})
        }
        if whiteBalanceModesSelected {
            rule[Camera2Params.whiteBalanceMode]
                = Set(whiteBalanceModes.compactMap {Camera2WhiteBalanceMode(fromArsdk: $0)})
        }
        if whiteBalanceTemperaturesSelected {
            rule[Camera2Params.whiteBalanceTemperature]
                = Set(whiteBalanceTemperatures.compactMap {Camera2WhiteBalanceTemperature(fromArsdk: $0)})
        }
        if imageStylesSelected {
            rule[Camera2Params.imageStyle] = Set(imageStyles.compactMap {Camera2Style(fromArsdk: $0)})
        }
        if imageContrastRangeSelected {
            rule[Camera2Params.imageContrast] = imageContrastRange.min...imageContrastRange.max
        }
        if imageSaturationRangeSelected {
            rule[Camera2Params.imageSaturation] = imageSaturationRange.min...imageSaturationRange.max
        }
        if imageSharpnessRangeSelected {
            rule[Camera2Params.imageSharpness] = imageSharpnessRange.min...imageSharpnessRange.max
        }
        if zoomMaxSpeedRangeSelected {
            rule[Camera2Params.zoomMaxSpeed] = zoomMaxSpeedRange.min...zoomMaxSpeedRange.max
        }
        if zoomVelocityControlQualityModesSelected {
            rule[Camera2Params.zoomVelocityControlQualityMode]
                = Set(zoomVelocityControlQualityModes.compactMap {Camera2ZoomVelocityControlQualityMode(fromArsdk: $0)})
        }
        if alignmentOffsetPitchRangeSelected {
            rule[Camera2Params.alignmentOffsetPitch] = alignmentOffsetPitchRange.min...alignmentOffsetPitchRange.max
        }
        if alignmentOffsetRollRangeSelected {
            rule[Camera2Params.alignmentOffsetRoll] = alignmentOffsetRollRange.min...alignmentOffsetRollRange.max
        }
        if alignmentOffsetYawRangeSelected {
            rule[Camera2Params.alignmentOffsetYaw] = alignmentOffsetYawRange.min...alignmentOffsetYawRange.max
        }
        if exposureMeteringsSelected {
            rule[Camera2Params.autoExposureMeteringMode] = Set(exposureMeterings.compactMap {
                Camera2AutoExposureMeteringMode(fromArsdk: $0)
            })
        }
        if storagePoliciesSelected {
            rule[Camera2Params.storagePolicy] = Set(storagePolicies.compactMap {Camera2StoragePolicy(fromArsdk: $0)})
        }

        return rule

    }
}

/// Extension that adds conversion to gsdk.
extension Arsdk_Camera_Config {
    /// Creates a new `Camera2ConfigCore.Config` from `Arsdk_Camera_Config`.
    func toGsdkConfig(defaultConfig: Camera2ConfigCore.Config) -> Camera2ConfigCore.Config {
        var config = defaultConfig
        if cameraModeSelected, let cameraMode = Camera2Mode(fromArsdk: cameraMode) {
            config[Camera2Params.mode] = cameraMode
        }
        if photoDynamicRangeSelected, let photoDynamicRange = Camera2DynamicRange(fromArsdk: photoDynamicRange) {
            config[Camera2Params.photoDynamicRange] = photoDynamicRange
        }
        if photoModeSelected, let photoMode = Camera2PhotoMode(fromArsdk: photoMode) {
            config[Camera2Params.photoMode] = photoMode
        }
        if photoResolutionSelected, let photoResolution = Camera2PhotoResolution(fromArsdk: photoResolution) {
            config[Camera2Params.photoResolution] = photoResolution
        }
        if photoFormatSelected, let photoFormat = Camera2PhotoFormat(fromArsdk: photoFormat) {
            config[Camera2Params.photoFormat] = photoFormat
        }
        if photoFileFormatSelected, let photoFileFormat = Camera2PhotoFileFormat(fromArsdk: photoFileFormat) {
            config[Camera2Params.photoFileFormat] = photoFileFormat
        }
        if photoSignatureSelected,
            let photoDigitalSignature = Camera2DigitalSignature(fromArsdk: photoSignature) {
            config[Camera2Params.photoDigitalSignature] = photoDigitalSignature
        }
        if photoBracketingPresetSelected,
            let photoBracketing = Camera2BracketingValue(fromArsdk: photoBracketingPreset) {
            config[Camera2Params.photoBracketing] = photoBracketing
        }
        if photoBurstValueSelected, let photoBurst = Camera2BurstValue(fromArsdk: photoBurstValue) {
            config[Camera2Params.photoBurst] = photoBurst
        }
        if photoTimeLapseIntervalSelected {
            config[Camera2Params.photoTimelapseInterval] = photoTimeLapseInterval
        }
        if photoGpsLapseIntervalSelected {
            config[Camera2Params.photoGpslapseInterval] = photoGpsLapseInterval
        }
        if photoStreamingModeSelected,
            let photoStreamingMode = Camera2PhotoStreamingMode(fromArsdk: photoStreamingMode) {
            config[Camera2Params.photoStreamingMode] = photoStreamingMode
        }
        if videoRecordingModeSelected,
            let videoRecordingMode = Camera2VideoRecordingMode(fromArsdk: videoRecordingMode) {
            config[Camera2Params.videoRecordingMode] = videoRecordingMode
        }
        if videoRecordingDynamicRangeSelected,
            let videoRecordingDynamicRange = Camera2DynamicRange(fromArsdk: videoRecordingDynamicRange) {
            config[Camera2Params.videoRecordingDynamicRange] = videoRecordingDynamicRange
        }
        if videoRecordingCodecSelected, let videoRecordingCodec = Camera2VideoCodec(fromArsdk: videoRecordingCodec) {
            config[Camera2Params.videoRecordingCodec] = videoRecordingCodec
        }
        if videoRecordingResolutionSelected,
            let videoRecordingResolution = Camera2RecordingResolution(fromArsdk: videoRecordingResolution) {
            config[Camera2Params.videoRecordingResolution] = videoRecordingResolution
        }
        if videoRecordingFramerateSelected,
            let videoRecordingFramerate = Camera2RecordingFramerate(fromArsdk: videoRecordingFramerate) {
            config[Camera2Params.videoRecordingFramerate] = videoRecordingFramerate
        }
        if videoRecordingBitrateSelected {
            config[Camera2Params.videoRecordingBitrate] = UInt(videoRecordingBitrate)
        }
        if audioRecordingModeSelected,
            let audioRecordingMode = Camera2AudioRecordingMode(fromArsdk: audioRecordingMode) {
            config[Camera2Params.audioRecordingMode] = audioRecordingMode
        }
        if autoRecordModeSelected, let autoRecordMode = Camera2AutoRecordMode(fromArsdk: autoRecordMode) {
            config[Camera2Params.autoRecordMode] = autoRecordMode
        }
        if exposureModeSelected, let exposureMode = Camera2ExposureMode(fromArsdk: exposureMode) {
            config[Camera2Params.exposureMode] = exposureMode
        }
        if exposureMaximumIsoSensitivitySelected,
            let maximumIsoSensitivity = Camera2Iso(fromArsdk: exposureMaximumIsoSensitivity) {
            config[Camera2Params.maximumIsoSensitivity] = maximumIsoSensitivity
        }
        if exposureManualIsoSensitivitySelected,
            let isoSensitivity = Camera2Iso(fromArsdk: exposureManualIsoSensitivity) {
            config[Camera2Params.isoSensitivity] = isoSensitivity
        }
        if exposureManualShutterSpeedSelected,
            let shutterSpeed = Camera2ShutterSpeed(fromArsdk: exposureManualShutterSpeed) {
            config[Camera2Params.shutterSpeed] = shutterSpeed
        }
        if evCompensationSelected,
            let exposureCompensation = Camera2EvCompensation(fromArsdk: evCompensation) {
            config[Camera2Params.exposureCompensation] = exposureCompensation
        }
        if whiteBalanceModeSelected, let whiteBalanceMode = Camera2WhiteBalanceMode(fromArsdk: whiteBalanceMode) {
            config[Camera2Params.whiteBalanceMode] = whiteBalanceMode
        }
        if whiteBalanceTemperatureSelected,
            let whiteBalanceTemperature = Camera2WhiteBalanceTemperature(fromArsdk: whiteBalanceTemperature) {
            config[Camera2Params.whiteBalanceTemperature] = whiteBalanceTemperature
        }
        if imageStyleSelected, let imageStyle = Camera2Style(fromArsdk: imageStyle) {
            config[Camera2Params.imageStyle] = imageStyle
        }
        if imageContrastSelected {
            config[Camera2Params.imageContrast] = imageContrast
        }
        if imageSaturationSelected {
            config[Camera2Params.imageSaturation] = imageSaturation
        }
        if imageSharpnessSelected {
            config[Camera2Params.imageSharpness] = imageSharpness
        }
        if zoomMaxSpeedSelected {
            config[Camera2Params.zoomMaxSpeed] = zoomMaxSpeed
        }
        if zoomVelocityControlQualityModeSelected,
            let controlQualityMode = Camera2ZoomVelocityControlQualityMode(fromArsdk: zoomVelocityControlQualityMode) {
            config[Camera2Params.zoomVelocityControlQualityMode] = controlQualityMode
        }
        if alignmentOffsetPitchSelected {
            config[Camera2Params.alignmentOffsetPitch] = alignmentOffsetPitch
        }
        if alignmentOffsetRollSelected {
            config[Camera2Params.alignmentOffsetRoll] = alignmentOffsetRoll
        }
        if alignmentOffsetYawSelected {
            config[Camera2Params.alignmentOffsetYaw] = alignmentOffsetYaw
        }
        if exposureMeteringSelected, let autoExposureMeteringMode = Camera2AutoExposureMeteringMode(
            fromArsdk: exposureMetering) {
            config[Camera2Params.autoExposureMeteringMode] = autoExposureMeteringMode
        }
        if storagePolicySelected, let storagePolicy = Camera2StoragePolicy(fromArsdk: storagePolicy) {
            config[Camera2Params.storagePolicy] = storagePolicy
        }
        return config
    }
}

/// Extension that adds conversion to arsdk Config.
extension Camera2ConfigCore.Config {
    /// Creates a new `Arsdk_Camera_Config` from `Camera2ConfigCore.Config`.
    var arsdkConfig: Arsdk_Camera_Config {
        var config = Arsdk_Camera_Config()
        if let cameraMode = self[Camera2Params.mode] {
            config.cameraMode = cameraMode.arsdkValue!
            config.cameraModeSelected = true
        }
        if let photoDynamicRange = self[Camera2Params.photoDynamicRange] {
            config.photoDynamicRange = photoDynamicRange.arsdkValue!
            config.photoDynamicRangeSelected = true
        }
        if let photoMode = self[Camera2Params.photoMode] {
            config.photoMode = photoMode.arsdkValue!
            config.photoModeSelected = true
        }
        if let photoResolution = self[Camera2Params.photoResolution] {
            config.photoResolution = photoResolution.arsdkValue!
            config.photoResolutionSelected = true
        }
        if let photoFormat = self[Camera2Params.photoFormat] {
            config.photoFormat = photoFormat.arsdkValue!
            config.photoFormatSelected = true
        }
        if let photoFileFormat = self[Camera2Params.photoFileFormat] {
            config.photoFileFormat = photoFileFormat.arsdkValue!
            config.photoFileFormatSelected = true
        }
        if let photoDigitalSignature = self[Camera2Params.photoDigitalSignature] {
            config.photoSignature = photoDigitalSignature.arsdkValue!
            config.photoSignatureSelected = true
        }
        if let photoBracketing = self[Camera2Params.photoBracketing] {
            config.photoBracketingPreset = photoBracketing.arsdkValue!
            config.photoBracketingPresetSelected = true
        }
        if let photoBurst = self[Camera2Params.photoBurst] {
            config.photoBurstValue = photoBurst.arsdkValue!
            config.photoBurstValueSelected = true
        }
        if let photoTimelapseInterval = self[Camera2Params.photoTimelapseInterval] {
            config.photoTimeLapseInterval = photoTimelapseInterval
            config.photoTimeLapseIntervalSelected = true
        }
        if let photoGpslapseInterval = self[Camera2Params.photoGpslapseInterval] {
            config.photoGpsLapseInterval = photoGpslapseInterval
            config.photoGpsLapseIntervalSelected = true
        }
        if let photoStreamingMode = self[Camera2Params.photoStreamingMode] {
            config.photoStreamingMode = photoStreamingMode.arsdkValue!
            config.photoStreamingModeSelected = true
        }
        if let videoRecordingMode = self[Camera2Params.videoRecordingMode] {
            config.videoRecordingMode = videoRecordingMode.arsdkValue!
            config.videoRecordingModeSelected = true
        }
        if let videoRecordingDynamicRange = self[Camera2Params.videoRecordingDynamicRange] {
            config.videoRecordingDynamicRange = videoRecordingDynamicRange.arsdkValue!
            config.videoRecordingDynamicRangeSelected = true
        }
        if let videoRecordingCodec = self[Camera2Params.videoRecordingCodec] {
            config.videoRecordingCodec = videoRecordingCodec.arsdkValue!
            config.videoRecordingCodecSelected = true
        }
        if let videoRecordingResolution = self[Camera2Params.videoRecordingResolution] {
            config.videoRecordingResolution = videoRecordingResolution.arsdkValue!
            config.videoRecordingResolutionSelected = true
        }
        if let videoRecordingFramerate = self[Camera2Params.videoRecordingFramerate] {
            config.videoRecordingFramerate = videoRecordingFramerate.arsdkValue!
            config.videoRecordingFramerateSelected = true
        }
        if let videoRecordingBitrate = self[Camera2Params.videoRecordingBitrate] {
            config.videoRecordingBitrate = UInt32(videoRecordingBitrate)
            config.videoRecordingBitrateSelected = true
        }
        if let audioRecordingMode = self[Camera2Params.audioRecordingMode] {
            config.audioRecordingMode = audioRecordingMode.arsdkValue!
            config.audioRecordingModeSelected = true
        }
        if let autoRecordMode = self[Camera2Params.autoRecordMode] {
            config.autoRecordMode = autoRecordMode.arsdkValue!
            config.autoRecordModeSelected = true
        }
        if let exposureMode = self[Camera2Params.exposureMode] {
            config.exposureMode = exposureMode.arsdkValue!
            config.exposureModeSelected = true
        }
        if let maximumIsoSensitivity = self[Camera2Params.maximumIsoSensitivity] {
            config.exposureMaximumIsoSensitivity = maximumIsoSensitivity.arsdkValue!
            config.exposureMaximumIsoSensitivitySelected = true
        }
        if let isoSensitivity = self[Camera2Params.isoSensitivity] {
            config.exposureManualIsoSensitivity = isoSensitivity.arsdkValue!
            config.exposureManualIsoSensitivitySelected = true
        }
        if let shutterSpeed = self[Camera2Params.shutterSpeed] {
            config.exposureManualShutterSpeed = shutterSpeed.arsdkValue!
            config.exposureManualShutterSpeedSelected = true
        }
        if let exposureCompensation = self[Camera2Params.exposureCompensation] {
            config.evCompensation = exposureCompensation.arsdkValue!
            config.evCompensationSelected = true
        }
        if let whiteBalanceMode = self[Camera2Params.whiteBalanceMode] {
            config.whiteBalanceMode = whiteBalanceMode.arsdkValue!
            config.whiteBalanceModeSelected = true
        }
        if let whiteBalanceTemperature = self[Camera2Params.whiteBalanceTemperature] {
            config.whiteBalanceTemperature = whiteBalanceTemperature.arsdkValue!
            config.whiteBalanceTemperatureSelected = true
        }
        if let imageStyle = self[Camera2Params.imageStyle] {
            config.imageStyle = imageStyle.arsdkValue!
            config.imageStyleSelected = true
        }
        if let imageContrast = self[Camera2Params.imageContrast] {
            config.imageContrast = imageContrast
            config.imageContrastSelected = true
        }
        if let imageSaturation = self[Camera2Params.imageSaturation] {
            config.imageSaturation = imageSaturation
            config.imageSaturationSelected = true
        }
        if let imageSharpness = self[Camera2Params.imageSharpness] {
            config.imageSharpness = imageSharpness
            config.imageSharpnessSelected = true
        }
        if let zoomMaxSpeed = self[Camera2Params.zoomMaxSpeed] {
            config.zoomMaxSpeed = zoomMaxSpeed
            config.zoomMaxSpeedSelected = true
        }
        if let zoomVelocityControlQualityMode = self[Camera2Params.zoomVelocityControlQualityMode] {
            config.zoomVelocityControlQualityMode = zoomVelocityControlQualityMode.arsdkValue!
            config.zoomVelocityControlQualityModeSelected = true
        }
        if let alignmentOffsetPitch = self[Camera2Params.alignmentOffsetPitch] {
            config.alignmentOffsetPitch = alignmentOffsetPitch
            config.alignmentOffsetPitchSelected = true
        }
        if let alignmentOffsetRoll = self[Camera2Params.alignmentOffsetRoll] {
            config.alignmentOffsetRoll = alignmentOffsetRoll
            config.alignmentOffsetRollSelected = true
        }
        if let alignmentOffsetYaw = self[Camera2Params.alignmentOffsetYaw] {
            config.alignmentOffsetYaw = alignmentOffsetYaw
            config.alignmentOffsetYawSelected = true
        }
        if let exposureMetering = self[Camera2Params.autoExposureMeteringMode] {
            config.exposureMetering = exposureMetering.arsdkValue!
            config.exposureMeteringSelected = true
        }
        if let userStorage = self[Camera2Params.storagePolicy] {
            config.storagePolicy = userStorage.arsdkValue!
            config.storagePolicySelected = true
        }
        return config
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2Mode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2Mode, Arsdk_Camera_CameraMode>([
        .photo: .photo,
        .recording: .recording])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2DigitalSignature: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2DigitalSignature, Arsdk_Camera_DigitalSignature>([
        .none: .none,
        .drone: .drone])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2DynamicRange: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2DynamicRange, Arsdk_Camera_DynamicRange>([
        .sdr: .standard,
        .hdr8: .hdr8,
        .hdr10: .hdr10])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2PhotoMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2PhotoMode, Arsdk_Camera_PhotoMode>([
        .single: .single,
        .bracketing: .bracketing,
        .burst: .burst,
        .timeLapse: .timeLapse,
        .gpsLapse: .gpsLapse])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2PhotoResolution: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2PhotoResolution, Arsdk_Camera_PhotoResolution>([
        .res12MegaPixels: .photoResolution12MegaPixels,
        .res48MegaPixels: .photoResolution48MegaPixels])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2PhotoFormat: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2PhotoFormat, Arsdk_Camera_PhotoFormat>([
        .fullFrame: .fullFrame,
        .fullFrameStabilized: .fullFrameStabilized,
        .rectilinear: .rectilinear])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2PhotoFileFormat: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2PhotoFileFormat, Arsdk_Camera_PhotoFileFormat>([
        .jpeg: .jpeg,
        .dngAndJpeg: .dngJpeg])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2BracketingValue: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2BracketingValue, Arsdk_Camera_BracketingPreset>([
        .preset1ev: .bracketingPreset1Ev,
        .preset2ev: .bracketingPreset2Ev,
        .preset3ev: .bracketingPreset3Ev,
        .preset1ev2ev: .bracketingPreset1Ev2Ev,
        .preset1ev3ev: .bracketingPreset1Ev3Ev,
        .preset2ev3ev: .bracketingPreset2Ev3Ev,
        .preset1ev2ev3ev: .bracketingPreset1Ev2Ev3Ev])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2BurstValue: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2BurstValue, Arsdk_Camera_BurstValue>([
        .burst14Over4s: .burstValue14Over4S,
        .burst14Over2s: .burstValue14Over2S,
        .burst14Over1s: .burstValue14Over1S,
        .burst10Over4s: .burstValue10Over4S,
        .burst10Over2s: .burstValue10Over2S,
        .burst10Over1s: .burstValue10Over1S,
        .burst4Over4s: .burstValue4Over4S,
        .burst4Over2s: .burstValue4Over2S,
        .burst4Over1s: .burstValue4Over1S])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2PhotoStreamingMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2PhotoStreamingMode, Arsdk_Camera_PhotoStreamingMode>([
        .continuous: .continuous,
        .interrupted: .interrupt])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2VideoRecordingMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2VideoRecordingMode, Arsdk_Camera_VideoRecordingMode>([
        .standard: .standard])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2RecordingResolution: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2RecordingResolution, Arsdk_Camera_VideoResolution>([
        .resUhd4k: .videoResolution2160P,
        .res1080p: .videoResolution1080P])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2RecordingFramerate: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2RecordingFramerate, Arsdk_Camera_Framerate>([
        .fps24: .framerate24,
        .fps25: .framerate25,
        .fps30: .framerate30,
        .fps48: .framerate48,
        .fps50: .framerate50,
        .fps60: .framerate60,
        .fps96: .framerate96,
        .fps100: .framerate100,
        .fps120: .framerate120])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2AudioRecordingMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2AudioRecordingMode, Arsdk_Camera_AudioRecordingMode>([
        .mute: .mute,
        .drone: .drone])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2AutoRecordMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2AutoRecordMode, Arsdk_Camera_AutoRecordMode>([
        .disabled: .disabled,
        .recordFlight: .flight])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2VideoCodec: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2VideoCodec, Arsdk_Camera_VideoCodec>([
        .h264: .h264,
        .h265: .h265])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2ExposureMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2ExposureMode, Arsdk_Camera_ExposureMode>([
        .automatic: .automatic,
        .automaticPreferIsoSensitivity: .automaticPreferIsoSensitivity,
        .automaticPreferShutterSpeed: .automaticPreferShutterSpeed,
        .manual: .manual,
        .manualIsoSensitivity: .manualIsoSensitivity,
        .manualShutterSpeed: .manualShutterSpeed])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2WhiteBalanceLockMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2WhiteBalanceLockMode, Arsdk_Camera_WhiteBalanceLockMode>([
        .locked: .locked,
        .unlocked: .unlocked])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2ExposureLockMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2ExposureLockMode, Arsdk_Camera_ExposureLockMode>([
        .none: .unlocked,
        .currentValues: .fullLock,
        .region: .roiLock])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2PhotoCaptureState.StopReason: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2PhotoCaptureState.StopReason, Arsdk_Camera_PhotoStopReason>([
        .captureDone: .captureDone,
        .configurationChange: .configurationChange,
        .errorInsufficientStorageSpace: .insufficientStorageSpace,
        .errorInternal: .internalError,
        .userRequest: .userRequest])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2RecordingState.StopReason: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2RecordingState.StopReason, Arsdk_Camera_RecordingStopReason>([
        .configurationChange: .configurationChange,
        .errorInsufficientStorageSpace: .insufficientStorageSpace,
        .errorInsufficientStorageSpeed: .insufficientStorageSpeed,
        .errorInternal: .internalError,
        .userRequest: .userRequest])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2Iso: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<Camera2Iso, Arsdk_Camera_IsoSensitivity>([
        .iso25: .isoSensitivity25,
        .iso50: .isoSensitivity50,
        .iso64: .isoSensitivity64,
        .iso80: .isoSensitivity80,
        .iso100: .isoSensitivity100,
        .iso125: .isoSensitivity125,
        .iso160: .isoSensitivity160,
        .iso200: .isoSensitivity200,
        .iso250: .isoSensitivity250,
        .iso320: .isoSensitivity320,
        .iso400: .isoSensitivity400,
        .iso500: .isoSensitivity500,
        .iso640: .isoSensitivity640,
        .iso800: .isoSensitivity800,
        .iso1000: .isoSensitivity1000,
        .iso1200: .isoSensitivity1200,
        .iso1600: .isoSensitivity1600,
        .iso2000: .isoSensitivity2000,
        .iso2500: .isoSensitivity2500,
        .iso3200: .isoSensitivity3200,
        .iso4000: .isoSensitivity4000,
        .iso5000: .isoSensitivity5000,
        .iso6400: .isoSensitivity6400,
        .iso8000: .isoSensitivity8000,
        .iso10000: .isoSensitivity10000,
        .iso12800: .isoSensitivity12800,
        .iso16000: .isoSensitivity16000,
        .iso20000: .isoSensitivity20000,
        .iso25600: .isoSensitivity25600,
        .iso32000: .isoSensitivity32000,
        .iso40000: .isoSensitivity40000,
        .iso51200: .isoSensitivity51200])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2ShutterSpeed: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<Camera2ShutterSpeed, Arsdk_Camera_ShutterSpeed>([
        .oneOver10000: .shutterSpeed1Over10000,
        .oneOver8000: .shutterSpeed1Over8000,
        .oneOver6400: .shutterSpeed1Over6400,
        .oneOver5000: .shutterSpeed1Over5000,
        .oneOver4000: .shutterSpeed1Over4000,
        .oneOver3200: .shutterSpeed1Over3200,
        .oneOver2000: .shutterSpeed1Over2000,
        .oneOver2500: .shutterSpeed1Over2500,
        .oneOver1600: .shutterSpeed1Over1600,
        .oneOver1250: .shutterSpeed1Over1250,
        .oneOver1000: .shutterSpeed1Over1000,
        .oneOver800: .shutterSpeed1Over800,
        .oneOver640: .shutterSpeed1Over640,
        .oneOver500: .shutterSpeed1Over500,
        .oneOver400: .shutterSpeed1Over400,
        .oneOver320: .shutterSpeed1Over320,
        .oneOver240: .shutterSpeed1Over240,
        .oneOver200: .shutterSpeed1Over200,
        .oneOver160: .shutterSpeed1Over160,
        .oneOver120: .shutterSpeed1Over120,
        .oneOver100: .shutterSpeed1Over100,
        .oneOver80: .shutterSpeed1Over80,
        .oneOver60: .shutterSpeed1Over60,
        .oneOver50: .shutterSpeed1Over50,
        .oneOver40: .shutterSpeed1Over40,
        .oneOver30: .shutterSpeed1Over30,
        .oneOver25: .shutterSpeed1Over25,
        .oneOver15: .shutterSpeed1Over15,
        .oneOver10: .shutterSpeed1Over10,
        .oneOver8: .shutterSpeed1Over8,
        .oneOver6: .shutterSpeed1Over6,
        .oneOver4: .shutterSpeed1Over4,
        .oneOver3: .shutterSpeed1Over3,
        .oneOver2: .shutterSpeed1Over2,
        .oneOver1_5: .shutterSpeed1Over1Point5,
        .one: .shutterSpeed1])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2EvCompensation: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<Camera2EvCompensation, Arsdk_Camera_EvCompensation>([
        .evMinus3_00: .minus300,
        .evMinus2_67: .minus267,
        .evMinus2_33: .minus233,
        .evMinus2_00: .minus200,
        .evMinus1_67: .minus167,
        .evMinus1_33: .minus133,
        .evMinus1_00: .minus100,
        .evMinus0_67: .minus067,
        .evMinus0_33: .minus033,
        .ev0_00: .evCompensation000,
        .ev0_33: .evCompensation033,
        .ev0_67: .evCompensation067,
        .ev1_00: .evCompensation100,
        .ev1_33: .evCompensation133,
        .ev1_67: .evCompensation167,
        .ev2_00: .evCompensation200,
        .ev2_33: .evCompensation233,
        .ev2_67: .evCompensation267,
        .ev3_00: .evCompensation300])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2WhiteBalanceMode: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<Camera2WhiteBalanceMode, Arsdk_Camera_WhiteBalanceMode>([
        .automatic: .automatic,
        .candle: .candle,
        .sunset: .sunset,
        .incandescent: .incandescent,
        .warmWhiteFluorescent: .warmWhiteFluorescent,
        .halogen: .halogen,
        .fluorescent: .fluorescent,
        .coolWhiteFluorescent: .coolWhiteFluorescent,
        .flash: .flash,
        .daylight: .daylight,
        .sunny: .sunny,
        .cloudy: .cloudy,
        .snow: .snow,
        .hazy: .hazy,
        .shaded: .shaded,
        .greenFoliage: .greenFoliage,
        .blueSky: .blueSky,
        .custom: .custom])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2WhiteBalanceTemperature: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<Camera2WhiteBalanceTemperature, Arsdk_Camera_WhiteBalanceTemperature>([
        .k1500: .whiteBalanceTemperature1500,
        .k1750: .whiteBalanceTemperature1750,
        .k2000: .whiteBalanceTemperature2000,
        .k2250: .whiteBalanceTemperature2250,
        .k2500: .whiteBalanceTemperature2500,
        .k2750: .whiteBalanceTemperature2750,
        .k3000: .whiteBalanceTemperature3000,
        .k3250: .whiteBalanceTemperature3250,
        .k3500: .whiteBalanceTemperature3500,
        .k3750: .whiteBalanceTemperature3750,
        .k4000: .whiteBalanceTemperature4000,
        .k4250: .whiteBalanceTemperature4250,
        .k4500: .whiteBalanceTemperature4500,
        .k4750: .whiteBalanceTemperature4750,
        .k5000: .whiteBalanceTemperature5000,
        .k5250: .whiteBalanceTemperature5250,
        .k5500: .whiteBalanceTemperature5500,
        .k5750: .whiteBalanceTemperature5750,
        .k6000: .whiteBalanceTemperature6000,
        .k6250: .whiteBalanceTemperature6250,
        .k6500: .whiteBalanceTemperature6500,
        .k6750: .whiteBalanceTemperature6750,
        .k7000: .whiteBalanceTemperature7000,
        .k7250: .whiteBalanceTemperature7250,
        .k7500: .whiteBalanceTemperature7500,
        .k7750: .whiteBalanceTemperature7750,
        .k8000: .whiteBalanceTemperature8000,
        .k8250: .whiteBalanceTemperature8250,
        .k8500: .whiteBalanceTemperature8500,
        .k8750: .whiteBalanceTemperature8750,
        .k9000: .whiteBalanceTemperature9000,
        .k9250: .whiteBalanceTemperature9250,
        .k9500: .whiteBalanceTemperature9500,
        .k9750: .whiteBalanceTemperature9750,
        .k10000: .whiteBalanceTemperature10000,
        .k10250: .whiteBalanceTemperature10250,
        .k10500: .whiteBalanceTemperature10500,
        .k10750: .whiteBalanceTemperature10750,
        .k11000: .whiteBalanceTemperature11000,
        .k11250: .whiteBalanceTemperature11250,
        .k11500: .whiteBalanceTemperature11500,
        .k11750: .whiteBalanceTemperature11750,
        .k12000: .whiteBalanceTemperature12000,
        .k12250: .whiteBalanceTemperature12250,
        .k12500: .whiteBalanceTemperature12500,
        .k12750: .whiteBalanceTemperature12750,
        .k13000: .whiteBalanceTemperature13000,
        .k13250: .whiteBalanceTemperature13250,
        .k13500: .whiteBalanceTemperature13500,
        .k13750: .whiteBalanceTemperature13750,
        .k14000: .whiteBalanceTemperature14000,
        .k14250: .whiteBalanceTemperature14250,
        .k14500: .whiteBalanceTemperature14500,
        .k14750: .whiteBalanceTemperature14750,
        .k15000: .whiteBalanceTemperature15000])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2Style: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2Style, Arsdk_Camera_ImageStyle>([
        .custom: .custom,
        .standard: .standard,
        .plog: .plog,
        .intense: .intense,
        .pastel: .pastel,
        .photogrammetry: .photogrammetry])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2ZoomVelocityControlQualityMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2ZoomVelocityControlQualityMode,
        Arsdk_Camera_ZoomVelocityControlQualityMode>([
            .allowDegrading: .allowDegradation,
            .stopBeforeDegrading: .stopBeforeDegradation])
}

/// Extension that add conversion from/to arsdk enum.
extension Camera2ZoomControlMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2ZoomControlMode, Arsdk_Camera_ZoomControlMode>([
        .level: .level,
        .velocity: .velocity])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2AutoExposureMeteringMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2AutoExposureMeteringMode, Arsdk_Camera_ExposureMetering>([
        .standard: .standard,
        .centerTop: .centerTop])
}

/// Extension that adds conversion from/to arsdk enum.
extension Camera2StoragePolicy: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Camera2StoragePolicy, Arsdk_Camera_StoragePolicy>([
        .automatic: .auto,
        .internal: .internal,
        .removable: .removable])
}

/// Extension that adds conversion from/to arsdk enum.
extension StorageType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<StorageType, Arsdk_Camera_StorageType>([
        .internal: .internal,
        .removable: .removable])
}

/// Extension to make Camera2Model storable.
extension Camera2Model: StorableEnum {
    static var storableMapper = Mapper<Camera2Model, String>([
        .main: "main"])
}

/// Extension to make Camera2Mode storable.
extension Camera2Mode: StorableEnum {
    static var storableMapper = Mapper<Camera2Mode, String>([
        .recording: "recording",
        .photo: "photo"])
}

/// Extension to make Camera2PhotoMode storable.
extension Camera2PhotoMode: StorableEnum {
    static var storableMapper = Mapper<Camera2PhotoMode, String>([
        .single: "single",
        .bracketing: "bracketing",
        .burst: "burst",
        .timeLapse: "timeLapse",
        .gpsLapse: "gpsLapse"])
}

/// Extension to make Camera2DigitalSignature storable.
extension Camera2DigitalSignature: StorableEnum {
    static var storableMapper = Mapper<Camera2DigitalSignature, String>([
        .none: "none",
        .drone: "drone"])
}

/// Extension to make Camera2DynamicRange storable.
extension Camera2DynamicRange: StorableEnum {
    static var storableMapper = Mapper<Camera2DynamicRange, String>([
        .sdr: "sdr",
        .hdr8: "hdr8",
        .hdr10: "hdr10"])
}

/// Extension to make Camera2PhotoResolution storable.
extension Camera2PhotoResolution: StorableEnum {
    static var storableMapper = Mapper<Camera2PhotoResolution, String>([
        .res12MegaPixels: "res12MegaPixels",
        .res48MegaPixels: "res48MegaPixels"])
}

/// Extension to make Camera2PhotoFormat storable.
extension Camera2PhotoFormat: StorableEnum {
    static var storableMapper = Mapper<Camera2PhotoFormat, String>([
        .fullFrame: "fullFrame",
        .fullFrameStabilized: "fullFrameStabilized",
        .rectilinear: "rectilinear"])
}

/// Extension to make Camera2PhotoFileFormat storable.
extension Camera2PhotoFileFormat: StorableEnum {
    static var storableMapper = Mapper<Camera2PhotoFileFormat, String>([
        .dngAndJpeg: "dngAndJpeg",
        .jpeg: "jpeg"])
}

/// Extension to make Camera2BracketingValue storable.
extension Camera2BracketingValue: StorableEnum {
    static var storableMapper = Mapper<Camera2BracketingValue, String>([
        .preset1ev: "1ev",
        .preset2ev: "2ev",
        .preset3ev: "3ev",
        .preset1ev2ev: "1ev2ev",
        .preset1ev3ev: "1ev3ev",
        .preset2ev3ev: "2ev3ev",
        .preset1ev2ev3ev: "1ev2ev3ev"])
}

/// Extension to make Camera2BurstValue storable.
extension Camera2BurstValue: StorableEnum {
    static var storableMapper = Mapper<Camera2BurstValue, String>([
        .burst14Over4s: "24/4",
        .burst14Over2s: "24/3",
        .burst14Over1s: "24/1",
        .burst10Over4s: "10/4",
        .burst10Over2s: "10/2",
        .burst10Over1s: "10/1",
        .burst4Over4s: "4/4",
        .burst4Over2s: "4/2",
        .burst4Over1s: "4/1"])
}

/// Extension to make Camera2PhotoStreamingMode storable.
extension Camera2PhotoStreamingMode: StorableEnum {
    static var storableMapper = Mapper<Camera2PhotoStreamingMode, String>([
        .continuous: "continuous",
        .interrupted: "interrupted"])
}

/// Extension to make Camera2VideoRecordingMode storable.
extension Camera2VideoRecordingMode: StorableEnum {
    static var storableMapper = Mapper<Camera2VideoRecordingMode, String>([
        .standard: "standard"])
}

/// Extension to make Camera2VideoCodec storable.
extension Camera2VideoCodec: StorableEnum {
    static var storableMapper = Mapper<Camera2VideoCodec, String>([
        .h264: "h264",
        .h265: "h265"])
}

/// Extension to make Camera2RecordingResolution storable.
extension Camera2RecordingResolution: StorableEnum {
    static var storableMapper = Mapper<Camera2RecordingResolution, String>([
        .resUhd4k: "uhd4k",
        .res1080p: "1080p"])
}

/// Extension to make Camera2RecordingFramerate storable.
extension Camera2RecordingFramerate: StorableEnum {
    static let storableMapper = Mapper<Camera2RecordingFramerate, String>([
        .fps24: "24",
        .fps25: "25",
        .fps30: "30",
        .fps48: "48",
        .fps50: "50",
        .fps60: "60",
        .fps96: "96",
        .fps100: "100",
        .fps120: "120"])
}

/// Extension to make Camera2AudioRecordingMode storable.
extension Camera2AudioRecordingMode: StorableEnum {
    static let storableMapper = Mapper<Camera2AudioRecordingMode, String>([
        .drone: "drone",
        .mute: "mute"])
}

/// Extension to make Camera2AutoRecordMode storable.
extension Camera2AutoRecordMode: StorableEnum {
    static let storableMapper = Mapper<Camera2AutoRecordMode, String>([
        .disabled: "disabled",
        .recordFlight: "recordFlight"])
}

/// Extension to make Camera2ExposureMode storable.
extension Camera2ExposureMode: StorableEnum {
    static var storableMapper = Mapper<Camera2ExposureMode, String>([
        .automatic: "automatic",
        .automaticPreferIsoSensitivity: "automaticPreferIsoSensitivity",
        .automaticPreferShutterSpeed: "automaticPreferShutterSpeed",
        .manualIsoSensitivity: "manualIsoSensitivity",
        .manualShutterSpeed: "manualShutterSpeed",
        .manual: "manual"])
}

/// Extension to make Camera2Iso storable.
extension Camera2Iso: StorableEnum {
    static var storableMapper = Mapper<Camera2Iso, String>([
        .iso25: "iso 25",
        .iso50: "iso 50",
        .iso64: "iso 64",
        .iso80: "iso 80",
        .iso100: "iso 100",
        .iso125: "iso 125",
        .iso160: "iso 160",
        .iso200: "iso 200",
        .iso250: "iso 250",
        .iso320: "iso 320",
        .iso400: "iso 400",
        .iso500: "iso 500",
        .iso640: "iso 640",
        .iso800: "iso 800",
        .iso1000: "iso 1000",
        .iso1200: "iso 1200",
        .iso1600: "iso 1600",
        .iso2000: "iso 2000",
        .iso2500: "iso 2500",
        .iso3200: "iso 3200",
        .iso4000: "iso 4000",
        .iso5000: "iso 5000",
        .iso6400: "iso 6400",
        .iso8000: "iso 8000",
        .iso10000: "iso 10000",
        .iso12800: "iso 12800",
        .iso16000: "iso 16000",
        .iso20000: "iso 20000",
        .iso25600: "iso 25600",
        .iso32000: "iso 32000",
        .iso40000: "iso 40000",
        .iso51200: "iso 51200"
        ])
}

/// Extension to make Camera2ShutterSpeed storable.
extension Camera2ShutterSpeed: StorableEnum {
    static var storableMapper = Mapper<Camera2ShutterSpeed, String>([
        .oneOver10000: "1/10000s",
        .oneOver8000: "1/8000s",
        .oneOver6400: "1/6400s",
        .oneOver5000: "1/5000s",
        .oneOver4000: "1/4000s",
        .oneOver3200: "1/3200s",
        .oneOver2500: "1/2500s",
        .oneOver2000: "1/2000s",
        .oneOver1600: "1/1600s",
        .oneOver1250: "1/1250s",
        .oneOver1000: "1/1000s",
        .oneOver800: "1/800s",
        .oneOver640: "1/640s",
        .oneOver500: "1/500s",
        .oneOver400: "1/400s",
        .oneOver320: "1/320s",
        .oneOver240: "1/240s",
        .oneOver200: "1/200s",
        .oneOver160: "1/160s",
        .oneOver120: "1/120s",
        .oneOver100: "1/100s",
        .oneOver80: "1/80s",
        .oneOver60: "1/60s",
        .oneOver50: "1/50s",
        .oneOver40: "1/40s",
        .oneOver30: "1/30s",
        .oneOver25: "1/25s",
        .oneOver15: "1/15s",
        .oneOver10: "1/10s",
        .oneOver8: "1/8s",
        .oneOver6: "1/6s",
        .oneOver4: "1/4s",
        .oneOver3: "1/3s",
        .oneOver2: "1/2s",
        .oneOver1_5: "1/1.5s",
        .one: "1s"
        ])
}

/// Extension to make Camera2EvCompensation storable.
extension Camera2EvCompensation: StorableEnum {
    static var storableMapper = Mapper<Camera2EvCompensation, String>([
        .evMinus3_00: "evMinus3_00",
        .evMinus2_67: "-2.67 ev",
        .evMinus2_33: "-2.33 ev",
        .evMinus2_00: "-2.00 ev",
        .evMinus1_67: "-1.67 ev",
        .evMinus1_33: "-1.33 ev",
        .evMinus1_00: "-1.00 ev",
        .evMinus0_67: "-0.67 ev",
        .evMinus0_33: "-0.33 ev",
        .ev0_00: "0.00 ev",
        .ev0_33: "+0.33 ev",
        .ev0_67: "+0.67 ev",
        .ev1_00: "+1.00 ev",
        .ev1_33: "+1.33 ev",
        .ev1_67: "+1.67 ev",
        .ev2_00: "+2.00 ev",
        .ev2_33: "+2.33 ev",
        .ev2_67: "+2.67 ev",
        .ev3_00: "+3.00 ev"
        ])
}

/// Extension to make Camera2WhiteBalanceMode storable.
extension Camera2WhiteBalanceMode: StorableEnum {
    static var storableMapper = Mapper<Camera2WhiteBalanceMode, String>([
        .automatic: "automatic",
        .candle: "candle",
        .sunset: "sunset",
        .incandescent: "incandescent",
        .warmWhiteFluorescent: "warmWhiteFluorescent",
        .halogen: "halogen",
        .fluorescent: "fluorescent",
        .coolWhiteFluorescent: "coolWhiteFluorescent",
        .daylight: "daylight",
        .sunny: "sunny",
        .cloudy: "cloudy",
        .snow: "snow",
        .hazy: "hazy",
        .shaded: "shaded",
        .greenFoliage: "greenFoliage",
        .blueSky: "blueSky",
        .custom: "custom",
        .flash: "flash"])
}

/// Extension to make Camera2WhiteBalanceTemperature storable.
extension Camera2WhiteBalanceTemperature: StorableEnum {
    static var storableMapper = Mapper<Camera2WhiteBalanceTemperature, String>([
        .k1500: "k1500",
        .k1750: "k1750",
        .k2000: "k2000",
        .k2250: "k2250",
        .k2500: "k2500",
        .k2750: "k2750",
        .k3000: "k3000",
        .k3250: "k3250",
        .k3500: "k3500",
        .k3750: "k3750",
        .k4000: "k4000",
        .k4250: "k4250",
        .k4500: "k4500",
        .k4750: "k4750",
        .k5000: "k5000",
        .k5250: "k5250",
        .k5500: "k5500",
        .k5750: "k5750",
        .k6000: "k6000",
        .k6250: "k6250",
        .k6500: "k6500",
        .k6750: "k6750",
        .k7000: "k7000",
        .k7250: "k7250",
        .k7500: "k7500",
        .k7750: "k7750",
        .k8000: "k8000",
        .k8250: "k8250",
        .k8500: "k8500",
        .k8750: "k8750",
        .k9000: "k9000",
        .k9250: "k9250",
        .k9500: "k9500",
        .k9750: "k9750",
        .k10000: "k10000",
        .k10250: "k10250",
        .k10500: "k10500",
        .k10750: "k10750",
        .k11000: "k11000",
        .k11250: "k11250",
        .k11500: "k11500",
        .k11750: "k11750",
        .k12000: "k12000",
        .k12250: "k12250",
        .k12500: "k12500",
        .k12750: "k12750",
        .k13000: "k13000",
        .k13250: "k13250",
        .k13500: "k13500",
        .k13750: "k13750",
        .k14000: "k14000",
        .k14250: "k14250",
        .k14500: "k14500",
        .k14750: "k14750",
        .k15000: "k15000"])
}

/// Extension to make Camera2Style storable.
extension Camera2Style: StorableEnum {
    static let storableMapper = Mapper<Camera2Style, String>([
        .custom: "custom",
        .intense: "intense",
        .pastel: "pastel",
        .plog: "plog",
        .standard: "standard",
        .photogrammetry: "photogrammetry"])
}

/// Extension to make Camera2ZoomVelocityControlQualityMode storable.
extension Camera2ZoomVelocityControlQualityMode: StorableEnum {
    static let storableMapper = Mapper<Camera2ZoomVelocityControlQualityMode, String>([
        .allowDegrading: "allowDegrading",
        .stopBeforeDegrading: "stopBeforeDegrading"])
}

/// Extension to make Camera2AutoExposureMeteringMode storable.
extension Camera2AutoExposureMeteringMode: StorableEnum {
    static var storableMapper = Mapper<Camera2AutoExposureMeteringMode, String>([
        .standard: "standard",
        .centerTop: "centerTop"])
}

/// Extension to make Camera2UserStorage storable.
extension Camera2StoragePolicy: StorableEnum {
    static var storableMapper = Mapper<Camera2StoragePolicy, String>([
        .automatic: "automatic",
        .internal: "internal",
        .removable: "removable"])
}

/// Extension to make Camera2ConfigCore.Config storable.
extension Camera2ConfigCore.Config: StorableType {

    private enum Key: String {
        case cameraMode, photoMode, photoDynamicRange, photoResolution, photoFormat, photoFileFormat,
        photoDigitalSignature, photoBracketing, photoBurst, photoTimelapseInterval, photoGpslapseInterval,
        photoStreamingMode, videoRecordingMode, videoRecordingDynamicRange, videoRecordingCodec,
        videoRecordingResolution, videoRecordingFramerate, videoRecordingBitrate,
        audioRecordingMode, autoRecordMode, exposureMode, maximumIsoSensitivity,
        isoSensitivity, shutterSpeed, exposureCompensation, whiteBalanceMode, whiteBalanceTemperature, imageStyle,
        imageContrast, imageSaturation, imageSharpness, zoomMaxSpeed, zoomVelocityControlQualityMode,
        alignmentOffsetPitch, alignmentOffsetRoll, alignmentOffsetYaw, autoExposureMeteringMode, userStorage
    }

    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content) {
            self = Camera2ConfigCore.Config(params: [:])
            if let param = Camera2Mode(content[Key.cameraMode.rawValue]) {
                self[Camera2Params.mode] = param.storableValue
            }
            if let param = Camera2PhotoMode(content[Key.photoMode.rawValue]) {
                self[Camera2Params.photoMode] = param.storableValue
            }
            if let param = Camera2DynamicRange(content[Key.photoDynamicRange.rawValue]) {
                self[Camera2Params.photoDynamicRange] = param.storableValue
            }
            if let param = Camera2PhotoResolution(content[Key.photoResolution.rawValue]) {
                self[Camera2Params.photoResolution] = param.storableValue
            }
            if let param = Camera2PhotoFormat(content[Key.photoFormat.rawValue]) {
                self[Camera2Params.photoFormat] = param.storableValue
            }
            if let param = Camera2PhotoFileFormat(content[Key.photoFileFormat.rawValue]) {
                self[Camera2Params.photoFileFormat] = param.storableValue
            }
            if let param = Camera2DigitalSignature(content[Key.photoDigitalSignature.rawValue]) {
                self[Camera2Params.photoDigitalSignature] = param.storableValue
            }
            if let param = Camera2BracketingValue(content[Key.photoBracketing.rawValue]) {
                self[Camera2Params.photoBracketing] = param.storableValue
            }
            if let param = Camera2BurstValue(content[Key.photoBurst.rawValue]) {
                self[Camera2Params.photoBurst] = param.storableValue
            }
            if let param = Double(content[Key.photoTimelapseInterval.rawValue]) {
                self[Camera2Params.photoTimelapseInterval] = param.storableValue
            }
            if let param = Double(content[Key.photoGpslapseInterval.rawValue]) {
                self[Camera2Params.photoGpslapseInterval] = param.storableValue
            }
            if let param = Camera2PhotoStreamingMode(content[Key.photoStreamingMode.rawValue]) {
                self[Camera2Params.photoStreamingMode] = param.storableValue
            }
            if let param = Camera2VideoRecordingMode(content[Key.videoRecordingMode.rawValue]) {
                self[Camera2Params.videoRecordingMode] = param.storableValue
            }
            if let param = Camera2DynamicRange(content[Key.videoRecordingDynamicRange.rawValue]) {
                self[Camera2Params.videoRecordingDynamicRange] = param.storableValue
            }
            if let param = Camera2VideoCodec(content[Key.videoRecordingCodec.rawValue]) {
                self[Camera2Params.videoRecordingCodec] = param.storableValue
            }
            if let param = Camera2RecordingResolution(content[Key.videoRecordingResolution.rawValue]) {
                self[Camera2Params.videoRecordingResolution] = param.storableValue
            }
            if let param = Camera2RecordingFramerate(content[Key.videoRecordingFramerate.rawValue]) {
                self[Camera2Params.videoRecordingFramerate] = param.storableValue
            }
            if let param = UInt(content[Key.videoRecordingBitrate.rawValue]) {
                self[Camera2Params.videoRecordingBitrate] = param.storableValue
            }
            if let param = Camera2AudioRecordingMode(content[Key.audioRecordingMode.rawValue]) {
                self[Camera2Params.audioRecordingMode] = param.storableValue
            }
            if let param = Camera2AutoRecordMode(content[Key.autoRecordMode.rawValue]) {
                self[Camera2Params.autoRecordMode] = param.storableValue
            }
            if let param = Camera2ExposureMode(content[Key.exposureMode.rawValue]) {
                self[Camera2Params.exposureMode] = param.storableValue
            }
            if let param = Camera2Iso(content[Key.maximumIsoSensitivity.rawValue]) {
                self[Camera2Params.maximumIsoSensitivity] = param.storableValue
            }
            if let param = Camera2Iso(content[Key.isoSensitivity.rawValue]) {
                self[Camera2Params.isoSensitivity] = param.storableValue
            }
            if let param = Camera2ShutterSpeed(content[Key.shutterSpeed.rawValue]) {
                self[Camera2Params.shutterSpeed] = param.storableValue
            }
            if let param = Camera2EvCompensation(content[Key.exposureCompensation.rawValue]) {
                self[Camera2Params.exposureCompensation] = param.storableValue
            }
            if let param = Camera2WhiteBalanceMode(content[Key.whiteBalanceMode.rawValue]) {
                self[Camera2Params.whiteBalanceMode] = param.storableValue
            }
            if let param = Camera2WhiteBalanceTemperature(content[Key.whiteBalanceTemperature.rawValue]) {
                self[Camera2Params.whiteBalanceTemperature] = param.storableValue
            }
            if let param = Camera2Style(content[Key.imageStyle.rawValue]) {
                self[Camera2Params.imageStyle] = param.storableValue
            }
            if let param = Double(content[Key.imageContrast.rawValue]) {
                self[Camera2Params.imageContrast] = param.storableValue
            }
            if let param = Double(content[Key.imageSaturation.rawValue]) {
                self[Camera2Params.imageSaturation] = param.storableValue
            }
            if let param = Double(content[Key.imageSharpness.rawValue]) {
                self[Camera2Params.imageSharpness] = param.storableValue
            }
            if let param = Double(content[Key.zoomMaxSpeed.rawValue]) {
                self[Camera2Params.zoomMaxSpeed] = param.storableValue
            }
            if let param = Camera2ZoomVelocityControlQualityMode(content[Key.zoomVelocityControlQualityMode.rawValue]) {
                self[Camera2Params.zoomVelocityControlQualityMode] = param.storableValue
            }
            if let param = Double(content[Key.alignmentOffsetPitch.rawValue]) {
                self[Camera2Params.alignmentOffsetPitch] = param.storableValue
            }
            if let param = Double(content[Key.alignmentOffsetRoll.rawValue]) {
                self[Camera2Params.alignmentOffsetRoll] = param.storableValue
            }
            if let param = Double(content[Key.alignmentOffsetYaw.rawValue]) {
                self[Camera2Params.alignmentOffsetYaw] = param.storableValue
            }
            if let param = Camera2AutoExposureMeteringMode(content[Key.autoExposureMeteringMode.rawValue]) {
                self[Camera2Params.autoExposureMeteringMode] = param.storableValue
            }
            if let param = Camera2StoragePolicy(content[Key.userStorage.rawValue]) {
                self[Camera2Params.storagePolicy] = param.storableValue
            }
        } else {
            return nil
        }
    }

    func asStorable() -> StorableProtocol {
        var configDict = [String: AnyStorable]()
        if let param = self[Camera2Params.mode] {
            configDict[Key.cameraMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoMode] {
            configDict[Key.photoMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoDynamicRange] {
            configDict[Key.photoDynamicRange.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoResolution] {
            configDict[Key.photoResolution.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoFormat] {
            configDict[Key.photoFormat.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoFileFormat] {
            configDict[Key.photoFileFormat.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoDigitalSignature] {
            configDict[Key.photoDigitalSignature.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoBracketing] {
            configDict[Key.photoBracketing.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoBurst] {
            configDict[Key.photoBurst.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoTimelapseInterval] {
            configDict[Key.photoTimelapseInterval.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoGpslapseInterval] {
            configDict[Key.photoGpslapseInterval.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.photoStreamingMode] {
            configDict[Key.photoStreamingMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.videoRecordingMode] {
            configDict[Key.videoRecordingMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.videoRecordingDynamicRange] {
            configDict[Key.videoRecordingDynamicRange.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.videoRecordingCodec] {
            configDict[Key.videoRecordingCodec.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.videoRecordingResolution] {
            configDict[Key.videoRecordingResolution.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.videoRecordingFramerate] {
            configDict[Key.videoRecordingFramerate.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.videoRecordingBitrate] {
            configDict[Key.videoRecordingBitrate.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.audioRecordingMode] {
            configDict[Key.audioRecordingMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.autoRecordMode] {
            configDict[Key.autoRecordMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.exposureMode] {
            configDict[Key.exposureMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.maximumIsoSensitivity] {
            configDict[Key.maximumIsoSensitivity.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.isoSensitivity] {
            configDict[Key.isoSensitivity.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.shutterSpeed] {
            configDict[Key.shutterSpeed.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.exposureCompensation] {
            configDict[Key.exposureCompensation.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.whiteBalanceMode] {
            configDict[Key.whiteBalanceMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.whiteBalanceTemperature] {
            configDict[Key.whiteBalanceTemperature.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.imageStyle] {
            configDict[Key.imageStyle.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.imageContrast] {
            configDict[Key.imageContrast.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.imageSaturation] {
            configDict[Key.imageSaturation.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.imageSharpness] {
            configDict[Key.imageSharpness.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.zoomMaxSpeed] {
            configDict[Key.zoomMaxSpeed.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.zoomVelocityControlQualityMode] {
            configDict[Key.zoomVelocityControlQualityMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.alignmentOffsetPitch] {
            configDict[Key.alignmentOffsetPitch.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.alignmentOffsetRoll] {
            configDict[Key.alignmentOffsetRoll.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.alignmentOffsetYaw] {
            configDict[Key.alignmentOffsetYaw.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.autoExposureMeteringMode] {
            configDict[Key.autoExposureMeteringMode.rawValue] = AnyStorable(param)
        }
        if let param = self[Camera2Params.storagePolicy] {
            configDict[Key.userStorage.rawValue] = AnyStorable(param)
        }
        return StorableDict(configDict)
    }
}

/// Extension to make Camera2Rule storable.
extension Camera2Rule: StorableType {

    private enum Key: String {
        case index, cameraMode, photoMode, photoDynamicRange, photoResolution, photoFormat, photoFileFormat,
        photoDigitalSignature, photoBracketing, photoBurst, photoTimelapseInterval, photoGpslapseInterval,
        photoStreamingMode, videoRecordingMode, videoRecordingDynamicRange, videoRecordingCodec,
        videoRecordingResolution, videoRecordingFramerate, videoRecordingBitrate,
        audioRecordingMode, autoRecordMode, exposureMode, maximumIsoSensitivity,
        isoSensitivity, shutterSpeed, exposureCompensation, whiteBalanceMode, whiteBalanceTemperature, imageStyle,
        imageContrast, imageSaturation, imageSharpness, zoomMaxSpeed, zoomVelocityControlQualityMode,
        alignmentOffsetPitch, alignmentOffsetRoll, alignmentOffsetYaw, autoExposureMeteringMode, userStorage
    }

    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
            let index = Int(AnyStorable(content[Key.index.rawValue])) {
            self = Camera2Rule(index: index)
            if let domain = StorableArray<Camera2Mode>(content[Key.cameraMode.rawValue]) {
                self[Camera2Params.mode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2PhotoMode>(content[Key.photoMode.rawValue]) {
                self[Camera2Params.photoMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2DynamicRange>(content[Key.photoDynamicRange.rawValue]) {
                self[Camera2Params.photoDynamicRange] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2PhotoResolution>(content[Key.photoResolution.rawValue]) {
                self[Camera2Params.photoResolution] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2PhotoFormat>(content[Key.photoFormat.rawValue]) {
                self[Camera2Params.photoFormat] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2PhotoFileFormat>(content[Key.photoFileFormat.rawValue]) {
                self[Camera2Params.photoFileFormat] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2DigitalSignature>(content[Key.photoDigitalSignature.rawValue]) {
                self[Camera2Params.photoDigitalSignature] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2BracketingValue>(content[Key.photoBracketing.rawValue]) {
                self[Camera2Params.photoBracketing] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2BurstValue>(content[Key.photoBurst.rawValue]) {
                self[Camera2Params.photoBurst] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Double>(content[Key.photoTimelapseInterval.rawValue]) {
                self[Camera2Params.photoTimelapseInterval] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Double>(content[Key.photoGpslapseInterval.rawValue]) {
                self[Camera2Params.photoGpslapseInterval] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Camera2PhotoStreamingMode>(content[Key.photoStreamingMode.rawValue]) {
                self[Camera2Params.photoStreamingMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2VideoRecordingMode>(content[Key.videoRecordingMode.rawValue]) {
                self[Camera2Params.videoRecordingMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2DynamicRange>(content[Key.videoRecordingDynamicRange.rawValue]) {
                self[Camera2Params.videoRecordingDynamicRange] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2VideoCodec>(content[Key.videoRecordingCodec.rawValue]) {
                self[Camera2Params.videoRecordingCodec] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2RecordingResolution>(content[Key.videoRecordingResolution.rawValue]) {
                self[Camera2Params.videoRecordingResolution] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2RecordingFramerate>(content[Key.videoRecordingFramerate.rawValue]) {
                self[Camera2Params.videoRecordingFramerate] = Set(domain.storableValue)
            }
            if let domain = StorableArray<UInt>(content[Key.videoRecordingBitrate.rawValue]) {
                self[Camera2Params.videoRecordingBitrate] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2AudioRecordingMode>(content[Key.audioRecordingMode.rawValue]) {
                self[Camera2Params.audioRecordingMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2AutoRecordMode>(content[Key.autoRecordMode.rawValue]) {
                self[Camera2Params.autoRecordMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2ExposureMode>(content[Key.exposureMode.rawValue]) {
                self[Camera2Params.exposureMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2Iso>(content[Key.maximumIsoSensitivity.rawValue]) {
                self[Camera2Params.maximumIsoSensitivity] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2Iso>(content[Key.isoSensitivity.rawValue]) {
                self[Camera2Params.isoSensitivity] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2ShutterSpeed>(content[Key.shutterSpeed.rawValue]) {
                self[Camera2Params.shutterSpeed] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2EvCompensation>(content[Key.exposureCompensation.rawValue]) {
                self[Camera2Params.exposureCompensation] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2WhiteBalanceMode>(content[Key.whiteBalanceMode.rawValue]) {
                self[Camera2Params.whiteBalanceMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2WhiteBalanceTemperature>(
                content[Key.whiteBalanceTemperature.rawValue]) {
                self[Camera2Params.whiteBalanceTemperature] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2Style>(content[Key.imageStyle.rawValue]) {
                self[Camera2Params.imageStyle] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Double>(content[Key.imageContrast.rawValue]) {
                self[Camera2Params.imageContrast] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Double>(content[Key.imageSaturation.rawValue]) {
                self[Camera2Params.imageSaturation] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Double>(content[Key.imageSharpness.rawValue]) {
                self[Camera2Params.imageSharpness] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Double>(content[Key.zoomMaxSpeed.rawValue]) {
                self[Camera2Params.zoomMaxSpeed] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Camera2ZoomVelocityControlQualityMode>(
                content[Key.zoomVelocityControlQualityMode.rawValue]) {
                self[Camera2Params.zoomVelocityControlQualityMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Double>(content[Key.alignmentOffsetPitch.rawValue]) {
                self[Camera2Params.alignmentOffsetPitch] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Double>(content[Key.alignmentOffsetRoll.rawValue]) {
                self[Camera2Params.alignmentOffsetRoll] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Double>(content[Key.alignmentOffsetYaw.rawValue]) {
                self[Camera2Params.alignmentOffsetYaw] = domain.storableValue[0]...domain.storableValue[1]
            }
            if let domain = StorableArray<Camera2AutoExposureMeteringMode>(content[
                Key.autoExposureMeteringMode.rawValue]) {
                self[Camera2Params.autoExposureMeteringMode] = Set(domain.storableValue)
            }
            if let domain = StorableArray<Camera2StoragePolicy>(content[Key.userStorage.rawValue]) {
                self[Camera2Params.storagePolicy] = Set(domain.storableValue)
            }
        } else {
            return nil
        }
    }

    func asStorable() -> StorableProtocol {
        var ruleDict = [
            Key.index.rawValue: AnyStorable(index)
        ]
        if let domain = self[Camera2Params.mode] {
            ruleDict[Key.cameraMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.photoMode] {
            ruleDict[Key.photoMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.photoDynamicRange] {
            ruleDict[Key.photoDynamicRange.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.photoResolution] {
            ruleDict[Key.photoResolution.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2PhotoFormat> = self[Camera2Params.photoFormat] {
            ruleDict[Key.photoFormat.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.photoDigitalSignature] {
            ruleDict[Key.photoDigitalSignature.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2PhotoFileFormat> = self[Camera2Params.photoFileFormat] {
            ruleDict[Key.photoFileFormat.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2BracketingValue> = self[Camera2Params.photoBracketing] {
            ruleDict[Key.photoBracketing.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2BurstValue> = self[Camera2Params.photoBurst] {
            ruleDict[Key.photoBurst.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.photoTimelapseInterval] {
            ruleDict[Key.photoTimelapseInterval.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.photoGpslapseInterval] {
            ruleDict[Key.photoGpslapseInterval.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain = self[Camera2Params.photoStreamingMode] {
            ruleDict[Key.photoStreamingMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.videoRecordingMode] {
            ruleDict[Key.videoRecordingMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.videoRecordingDynamicRange] {
            ruleDict[Key.videoRecordingDynamicRange.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.videoRecordingCodec] {
            ruleDict[Key.videoRecordingCodec.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2RecordingResolution> = self[Camera2Params.videoRecordingResolution] {
            ruleDict[Key.videoRecordingResolution.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2RecordingFramerate> = self[Camera2Params.videoRecordingFramerate] {
            ruleDict[Key.videoRecordingFramerate.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<UInt> = self[Camera2Params.videoRecordingBitrate] {
            ruleDict[Key.videoRecordingBitrate.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.audioRecordingMode] {
            ruleDict[Key.audioRecordingMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.autoRecordMode] {
            ruleDict[Key.autoRecordMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.exposureMode] {
            ruleDict[Key.exposureMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2Iso> = self[Camera2Params.maximumIsoSensitivity] {
            ruleDict[Key.maximumIsoSensitivity.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2Iso> = self[Camera2Params.isoSensitivity] {
            ruleDict[Key.isoSensitivity.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: Set<Camera2ShutterSpeed> = self[Camera2Params.shutterSpeed] {
            ruleDict[Key.shutterSpeed.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.exposureCompensation] {
            ruleDict[Key.exposureCompensation.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.whiteBalanceMode] {
            ruleDict[Key.whiteBalanceMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.whiteBalanceTemperature] {
            ruleDict[Key.whiteBalanceTemperature.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.imageStyle] {
            ruleDict[Key.imageStyle.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.imageContrast] {
            ruleDict[Key.imageContrast.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.imageSaturation] {
            ruleDict[Key.imageSaturation.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.imageSharpness] {
            ruleDict[Key.imageSharpness.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.zoomMaxSpeed] {
            ruleDict[Key.zoomMaxSpeed.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain = self[Camera2Params.zoomVelocityControlQualityMode] {
            ruleDict[Key.zoomVelocityControlQualityMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.alignmentOffsetPitch] {
            ruleDict[Key.alignmentOffsetPitch.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.alignmentOffsetRoll] {
            ruleDict[Key.alignmentOffsetRoll.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain: ClosedRange<Double> = self[Camera2Params.alignmentOffsetYaw] {
            ruleDict[Key.alignmentOffsetYaw.rawValue] = AnyStorable([domain.lowerBound, domain.upperBound])
        }
        if let domain = self[Camera2Params.autoExposureMeteringMode] {
            ruleDict[Key.autoExposureMeteringMode.rawValue] = AnyStorable(Array(domain))
        }
        if let domain = self[Camera2Params.storagePolicy] {
            ruleDict[Key.userStorage.rawValue] = AnyStorable(Array(domain))
        }
        return StorableDict(ruleDict)
    }
}

/// Extension to make Camera2ConfigCore.Capabilities storable.
extension Camera2ConfigCore.Capabilities: StorableType {
    private enum Key: String {
        case rules
    }

    convenience init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
            let storedRules = StorableDict<String, Camera2Rule>(content[Key.rules.rawValue]) {
            let rules = storedRules.storableValue.reduce(into: [Int: Camera2Rule]()) { result, value in
                if let key = Int(value.key) {
                    result[key] = value.value
                }
            }
            self.init(rules: rules)
        } else {
            return nil
        }
    }

    func asStorable() -> StorableProtocol {
        let storableRules = rules.reduce(into: [String: Camera2Rule]()) { result, value in
            result["\(value.key)"] = value.value
        }
        return StorableDict<String, AnyStorable>([
            Key.rules.rawValue: StorableDict(storableRules)])
    }
}
