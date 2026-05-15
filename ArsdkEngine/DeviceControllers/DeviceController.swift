// Copyright (C) 2019 Parrot Drones SAS
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

/// Callback called when the device controller close itself
protocol DeviceControllerStoppedListener: AnyObject {
    /// Device controller stopped itself
    ///
    /// - Parameter uid: device uid
    func onSelfStopped(uid: String)
}

/// The type returned by `subscribeNoAckCommandEncoder()`.
protocol RegisteredNoAckCmdEncoder {
    /// Unregister an `ArsdkCommandEncoder` previously registered in the NoAckCmdLoop
    ///
    /// - Note: the loop is running only if one (or more) commandEncoder is (are) present.
    func unregister()
}

/// Device controller protocol backend.
///
/// Used by the controller, after link connection is established, in order to send commands to the associated device.
protocol DeviceControllerBackend: AnyObject {

    /// Sends a command to the controller device.
    ///
    /// - Parameter command: command to send
    ///
    /// - Returns: true if the command could be sent
    func sendCommand(_ encoder: ((OpaquePointer) -> Int32))

    /// Creates the NoAck command loop of the controlled device.
    ///
    /// - Parameter periodMs: loop period, in milliseconds
    /// - Note: Useful only for drone devices.
    func createNoAckCmdLoop(periodMs: Int32)

    /// Delete the piloting command loop of the controlled device.
    ///
    /// - Note: Useful only for drone devices. This method unregister any ArsdkCommandEncoder previously registered
    /// in the NoAckLoop
    func deleteNoAckCmdLoop()

    /// Subscribe an `ArsdkCommandEncoder` in the NoAckCmdLoop (see: `createNoAckCmdLoop()`)
    /// The Encoder will be stored and executed in the NoAckLoop.
    ///
    /// To Unsubscribe, call the `unregister()` function  of the returned object `RegisteredNoAckCmdEncoder`
    /// You must keep a strong reference to this object and call the unregister() function in order to stop the command.
    /// However, it is also possible to directly call the function `deleteNoAckCmdLoop` to stop all the commands.
    ///
    /// - Note: The loop is running only if one (or more) commandEncoder is (are) present.
    /// - Parameter encoder: non ack command encoder.
    /// - Returns: an object that will be used for unsubscribe
    func subscribeNoAckCommandEncoder(encoder: NoAckCmdEncoder) -> RegisteredNoAckCmdEncoder

    /// Creates a tcp proxy and gets the address and port to use to reach the given port on the given model
    ///
    /// - Parameters:
    ///   - model: the model to access
    ///   - port: the port to access
    ///   - completion: completion callback that is called when the tcp proxy is created (or on error).
    ///   - tcpProxy: the proxy handle to keep to maintain the proxy open. Nil if an error occurred.
    ///   - proxyAddress: the address to use in order to reach the given `port`. Nil if an error occurred.
    ///   - proxyPort: the port to use in order to reach the given `port`.
    ///                If `proxyAddress` is `nil`, this value should be ignored.
    func createTcpProxy(model: DeviceModel, port: Int,
                        completion: @escaping (_ tcpProxy: ArsdkTcpProxy?,
                                               _ proxyAddress: String?,
                                               _ proxyPort: Int) -> Void)

    /// Creates a tcp proxy and gets the address and port to use to reach the given port on the given model
    ///
    /// - Parameters:
    ///   - url: the url that the proxy should address
    ///   - port: the port to access
    ///   - completion: completion callback that is called when the tcp proxy is created (or on error).
    ///   - tcpProxy: the proxy handle to keep to maintain the proxy open. Nil if an error occurred.
    ///   - proxyAddress: the address to use in order to reach the given `port`. Nil if an error occurred.
    ///   - proxyPort: the port to use in order to reach the given `port`.
    ///                If `proxyAddress` is `nil`, this value should be ignored.
    func createTcpProxy(url: String, port: Int,
                        completion: @escaping (_ tcpProxy: ArsdkTcpProxy?,
                                               _ proxyAddress: String?,
                                               _ proxyPort: Int) -> Void)

    /// Creates a video live stream source.
    ///
    /// - Parameter cameraType: stream camera type
    /// - Returns: a new instance of a live stream source
    func createVideoSourceLive(cameraType: ArsdkSourceLiveCameraType) -> ArsdkSourceLive

    /// Creates a media stream source.
    ///
    /// - Parameters:
    ///    - url: stream url
    ///    - trackName: stream track name
    /// - Returns: a new instance of a media stream source
    func createVideoSourceMedia(url: String, trackName: String?) -> ArsdkSourceMedia

    /// Create a video stream instance.
    ///
    /// - Returns: a new instance of a stream
    func createVideoStream() -> ArsdkStream

    /// List all medias stored in the device
    ///
    /// - Parameters:
    ///   - completion: closure called when the media list has been retrieved, or if there is an error
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    /// - Returns: low level request, that can be used to cancel the browse request
    func browseMedia(model: DeviceModel, completion: @escaping ArsdkMediaListCompletion) -> ArsdkRequest

    /// Download a media thumbnail
    ///
    /// - Parameters:
    ///   - media: media to download the thumbnail
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - completion: closure called when the thumbnail has been downloaded or if there is an error
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadMediaThumbnail(_ media: ArsdkMedia, model: DeviceModel,
                                completion: @escaping ArsdkMediaDownloadThumbnailCompletion) -> ArsdkRequest

    /// Download a media
    ///
    /// - Parameters:
    ///   - media: media to download
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - format: requested format
    ///   - destDirectoryPath: downloaded media destination directory path
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadMedia(_ media: ArsdkMedia, model: DeviceModel, format: ArsdkMediaResourceFormat,
                       destDirectoryPath: String, progress: @escaping ArsdkMediaDownloadProgress,
                       completion: @escaping ArsdkMediaDownloadCompletion) -> ArsdkRequest

    /// Delete a media
    ///
    /// - Parameters:
    ///   - media: media to delete
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - completion: closure called when the media has been deleted or if there is an error
    func deleteMedia(_ media: ArsdkMedia, model: DeviceModel,
                     completion: @escaping ArsdkMediaDeleteCompletion) -> ArsdkRequest

    /// Update the controlled device with a given firmware
    ///
    /// - Parameters:
    ///   - file: Path of the firmware file
    ///   - model: actual model to access media of. Must be drone model when connected through a proxy
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request that can be used to cancel the upload request
    func update(withFile file: String, model: DeviceModel, progress: @escaping ArsdkUpdateProgress,
                completion: @escaping ArsdkUpdateCompletion) -> ArsdkRequest

    /// Uploads a given file on a given server type of a drone
    ///
    /// - Parameters:
    ///   - srcPath: local path of the file
    ///   - dstPath: destination path of the file
    ///   - model: model of the device
    ///   - serverType: type of the server on which to upload
    ///   - progress: progress block
    ///   - completion: completion block
    /// - Returns: low level request that can be used to cancel the upload request
    func upload(file srcPath: String, to dstPath: String, model: DeviceModel, serverType: ArsdkFtpServerType,
                progress: @escaping ArsdkFtpRequestProgress,
                completion: @escaping ArsdkFtpRequestCompletion) -> ArsdkRequest

    /// Download crashmls from the controlled device
    ///
    /// - Parameters:
    ///   - path: Path where crashmls will be downloaded
    ///   - model: actual device model to access of crashmls.
    ///            Must be drone model when connected through a proxy
    ///   - progress: progress closure ; one crashml is downloaded.
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadCrashml(path: String, model: DeviceModel,
                         progress: @escaping ArsdkCrashmlDownloadProgress,
                         completion: @escaping ArsdkCrashmlDownloadCompletion) -> ArsdkRequest

    /// Download flight logs from the controlled device
    ///
    /// - Parameters:
    ///   - path: Path where flight logs will be downloaded
    ///   - model: actual device model to access of flight logs.
    ///            Must be drone model when connected through a proxy
    ///   - progress: progress closure ; one flight log is downloaded.
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    func downloadFlightLog(path: String, model: DeviceModel,
                           progress: @escaping ArsdkFlightLogDownloadProgress,
                           completion: @escaping ArsdkFlightLogDownloadCompletion) -> ArsdkRequest

    /// Requests to receive remote control black box data.
    ///
    /// - Parameters:
    ///   - buttonAction: remote controller button action callback
    ///   - pilotingInfo: remote controller piloting info callback
    /// - Returns: an ArsdkRequest that can be canceled
    func subscribeToRcBlackBox(buttonAction: @escaping ArsdkRcBlackBoxButtonActionCb,
                               pilotingInfo: @escaping ArsdkRcBlackBoxPilotingInfoCb) -> ArsdkRequest

}

/// Class that stores a connection session state in an object.
/// Having an object that is created on each connection session allows timeout closure that weak capture it to ensure
/// checking state of the correct connect session.
class ControllerConnectionSession {
    /// Connection state of the session
    enum State {
        /// Controller is fully disconnected.
        case disconnected

        /// Controller has requested connection.
        case connectionRequested

        /// Link is connecting.
        /// The protocol connection is not initiated.
        case connecting

        /// Controller is creating the http client of the device.
        /// This is the first step of the protocol connection; the protocol is connecting.
        case creatingDeviceHttpClient

        /// Controller is getting all settings of the device.
        /// The protocol is connecting.
        case gettingAllSettings

        /// Controller is getting all states of the device.
        /// The protocol is connecting.
        case gettingAllStates

        /// Controller is fully connected to the device.
        /// The protocol is connected.
        case connected

        /// Controller main link is lost but backup link is active.
        case backupLink

        /// Controller is disconnecting the device.
        case disconnecting
    }
    var state: State

    private unowned let deviceController: DeviceController

    /// Constructor
    ///
    /// Will set the initial state as `.disconnected`.
    ///
    /// - Parameter deviceController: the device controller owning this object (unowned)
    convenience init(deviceController: DeviceController) {
        self.init(initialState: .disconnected, deviceController: deviceController)
    }

    /// Constructor
    ///
    /// - Parameters:
    ///   - initialState: the initial state of the connection
    ///   - deviceController: the device controller owning this object (unowned)
    init(initialState: State, deviceController: DeviceController) {
        state = initialState
        self.deviceController = deviceController
    }
}

/// Base class for a device controller.
class DeviceController: NSObject {

    /// Non-acknowledged command loop period, in milliseconds. `0` if disabled.
    private let noAckLoopPeriod: Int32

    /// Device managed by this drone controller
    private(set) var device: DeviceCore!

    /// Device representation in the persistent store
    let deviceStore: SettingsStore

    /// Device preset in the persistent store
    private(set) var presetStore: SettingsStore!

    /// Device model
    let deviceModel: DeviceModel

    /// Registered providers for this device controller, by connector uid
    private var providers = Set<DeviceProvider>()

    /// Current provider used to connect this device
    private(set) weak var activeProvider: DeviceProvider?

    /// The tcp proxy if it exists.
    /// Always nil when not connected.
    private var arsdkTcpProxy: ArsdkTcpProxy?

    /// Device http server
    var deviceServer: DeviceServer?

    /// All attached component controllers
    var componentControllers = [DeviceComponentController]()

    /// Connection session of the controller
    private(set) var connectionSession: ControllerConnectionSession!

    /// Arsdk engine instance
    private(set) unowned var engine: ArsdkEngine

    /// Device controller backend, not null when device controller connection is started
    private(set) var backend: DeviceControllerBackend?

    /// Callback called when the device controller close itself
    private weak var stopListener: DeviceControllerStoppedListener?

    /// The current black box session. Nil if black box support is disabled or device is not protocol-connected
    var blackBoxSession: BlackBoxSession?

    /// get all settings command encoder
    var getAllSettingsEncoder: ((OpaquePointer) -> Int32)!

    /// get all states command encoder
    var getAllStatesEncoder: ((OpaquePointer) -> Int32)!

    /// Send the current date and time to the managed device
    var sendDateAndTime: (() -> Void)!

    /// `true` when the controller must attempt to reconnect the device after disconnection if the active provider is a
    /// local provider. If the provider has a parent provider, then it is assumed that the parent provider will handle
    /// the auto reconnection itself.
    var autoReconnect = false

    /// Computed property that represents whether the background data is allowed or not.
    /// This computed property might be overriden by subclasses if they have custom conditions to allow or restrict
    /// background data. Overrides **must** call super.
    var dataSyncAllowed: Bool {
        return _dataSyncAllowed && !isUpdating
    }

    /// Private implementation of the data sync allowance.
    /// It will be changed according to the connection state. It is true as soon as the device is connected, and set
    /// back to false when device is disconnected.
    private var _dataSyncAllowed = false

    /// Tells whether device is currently updating.
    internal var isUpdating: Bool = false {
        didSet {
            if oldValue != isUpdating {
                dataSyncAllowanceMightHaveChanged()
            }
        }
    }

    /// Memorize the previous data sync allowance value in order to notify only if it has changed.
    private var previousDataSyncAllowed = false

    /// Device event logger.
    public var deviceEventLogger: DeviceEventLogger?

    /// API Capabilities.
    private var apiCapabilities = ArsdkApiCapabilities.unknown

    /// Description.
    override var description: String {
        return "\(String(describing: type(of: self))) [uid: \(device.uid), model: \(device.deviceModel)]"
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - engine: arsdk engine instance
    ///    - deviceUid: device uid
    ///    - deviceModel: device model
    ///    - nonAckLoopPeriod: non-acknowledged command loop period (in ms), `0` to disable (0 is default value)
    ///    - deviceFactory: closure to create the device managed by this controller
    init(engine: ArsdkEngine, deviceUid: String, deviceModel: DeviceModel, noAckLoopPeriod: Int32 = 0,
         deviceFactory: (_ delegate: DeviceCoreDelegate) -> DeviceCore) {

        self.noAckLoopPeriod = noAckLoopPeriod
        self.engine = engine
        self.deviceModel = deviceModel
        // load device dictionary
        self.deviceStore = SettingsStore(dictionary: engine.persistentStore.getDevice(uid: deviceUid))

        super.init()

        connectionSession = ControllerConnectionSession(deviceController: self)

        // gets presets
        let presetId: String
        if let currentPresetId: String = deviceStore.read(key: PersistentStore.devicePresetUid) {
            presetId = currentPresetId
        } else {
            presetId = PersistentStore.presetKey(forModel: deviceModel)
        }
        var presetDict: PersistentDictionary!
        presetDict = engine.persistentStore.getPreset(uid: presetId) { [weak self] in
            presetDict.reload()
            self?.componentControllers.forEach { component in component.presetDidChange() }
        }
        presetStore = SettingsStore(dictionary: presetDict)
        // create the device
        self.device = deviceFactory(self)
        if let firmwareVersionStr: String = deviceStore.read(key: PersistentStore.deviceFirmwareVersion),
           let firmwareVersion = FirmwareVersion.parse(versionStr: firmwareVersionStr) {
            self.device.firmwareVersionHolder.update(version: firmwareVersion)
        }
        if let boardId: String = deviceStore.read(key: PersistentStore.deviceBoardId) {
            self.device.boardIdHolder.update(boardId: boardId)
        }
        self.device.stateHolder.state.update(persisted: !deviceStore.new).notifyUpdated()
        ULog.d(.ctrlTag, "Create \(self)]")
    }

    /// Start the controller
    ///
    /// - Parameter stopListener: listener called if the device controller stops itself
    /// - Note: custom actions after the start should be defined in the subclasses
    final func start(stopListener: DeviceControllerStoppedListener) {
        ULog.d(.ctrlTag, "Starting \(self)")
        self.stopListener = stopListener
        controllerDidStart()
    }

    /// Stops the controller
    ///
    /// - Note: custom actions after the stop should be defined in the subclasses
    final func stop() {
        ULog.d(.ctrlTag, "Stopping \(self)")
        controllerDidStop()
    }

    /// Add a new provider for this device
    ///
    /// - Parameter provider: provider to add
    final func addProvider(_ provider: DeviceProvider) {
        let (inserted, _) = providers.insert(provider)
        if inserted {
            providersDidChange()
        }

        // The device controller should automatically reconnect to the device when all the following conditions are met:
        // - the autoReconnect flag is set,
        // - the device controller has no active provider,
        // - the given provider has no parent provider.
        // If the provider has a parent provider, the latter should handle the auto reconnection itself.
        if autoReconnect && activeProvider == nil && provider.parent == nil {
            _ = doConnect(provider: provider, parameters: [], cause: .connectionLost)
        }

        device.stateHolder.state.notifyUpdated()
    }

    /// Remove a provider of this device
    ///
    /// - Parameter provider: provider to remove
    final func removeProvider(_ provider: DeviceProvider) {
        if providers.remove(provider) != nil {
            if provider == activeProvider {
                activeProvider = nil
                autoReconnect = true
                transitToDisconnectedState(withCause: .connectionLost)
            }
            providersDidChange()
            // Stop the DeviceController if it has no more provider and if it has never been connected.
            if providers.isEmpty && deviceStore.new {
                stopSelf()
            }

            device.stateHolder.state.notifyUpdated()
        }
    }

    /// Registered providers did change, update device connectors and known state
    ///
    /// - Note: Note that this method does not publish changes made to the device state.
    ///   Caller has the responsibility to call `notifyUpdated`.
    final func providersDidChange() {
        device.stateHolder.state.update(connectors: providers.map({$0.connector}))
            .update(activeConnector: activeProvider?.connector)
    }

    /// Stop self
    private final func stopSelf() {
        stop()
        stopListener?.onSelfStopped(uid: device.uid)
    }

    /// Connects this controller using the given provider.
    ///
    /// - Parameters:
    ///   - provider:  provider to use to connect this device
    ///   - parameters: custom parameters to use to connect this device
    ///   - cause: cause of this connection request
    ///   - wakeIdle: `true` to wake up the drone if it's in idle state
    ///
    /// - Returns: `true` if the connection process has started, `false` otherwise
    final func doConnect(provider: DeviceProvider, parameters: [DeviceConnectionParameter],
                         cause: DeviceState.ConnectionStateCause, wakeIdle: Bool = false) -> Bool {
        connectionSession = ControllerConnectionSession(initialState: .connectionRequested, deviceController: self)
        activeProvider = provider
        device.stateHolder.state?
            .update(activeConnector: activeProvider!.connector)
            .update(connectionState: .connecting, withCause: cause)
            .notifyUpdated()
        return activeProvider!.connect(deviceController: self, parameters: parameters, wakeIdle: wakeIdle)
    }

    /// Disconnects this controller.
    ///
    /// - Parameter cause: cause of this disconnection request
    /// - Returns: `true` if the disconnection process has started, `false` otherwise
    func doDisconnect(cause: DeviceState.ConnectionStateCause) -> Bool {
        if let activeProvider = activeProvider {
            if activeProvider.disconnect(deviceController: self) {
                device.stateHolder.state?.update(connectionState: .disconnecting,
                                                 withCause: cause).notifyUpdated()
                connectionSession.state = .disconnecting
                return true
            }
        }
        return false
    }

    /// Send a command to the drone
    ///
    /// - Parameter encoder: encoder of the command to send
    /// - Returns: `true` if the command has been sent
    final func sendCommand(_ encoder: ((OpaquePointer) -> Int32)!) -> Bool {
        if let backend = backend {
            backend.sendCommand(encoder)
            return true
        } else {
            ULog.w(.ctrlTag, "sendCommand called without backend")
            return false
        }
    }

    /// List all medias stored in the device
    ///
    /// - Parameter completion: closure called when the media list has been retrieved, or if there is an error
    /// - Returns: low level request, that can be used to cancel the browse request
    final func browseMedia(completion: @escaping ArsdkMediaListCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.browseMedia(model: deviceModel, completion: completion)
        } else {
            ULog.w(.ctrlTag, "browseMedia called without backend")
        }
        return nil
    }

    /// Download media thumbnail
    ///
    /// - Parameters:
    ///   - media: media to download the thumbnail
    ///   - completion: closure called when the thumbnail has been downloaded or if there is an error
    /// - Returns: low level request, that can be used to cancel the download request
    final func downloadMediaThumbnail(_ media: ArsdkMedia,
                                      completion: @escaping ArsdkMediaDownloadThumbnailCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadMediaThumbnail(media, model: deviceModel, completion: completion)
        } else {
            ULog.w(.ctrlTag, "downloadMediaThumbnail called without backend")
        }
        return nil
    }

    /// Delete a media
    ///
    /// - Parameters:
    ///   - media: media to delete
    ///   - completion: closure called when the media has been deleted or if there is an error
    /// - Returns: low level request, that can be used to cancel the delete request
    final func deleteMedia(_ media: ArsdkMedia, completion: @escaping ArsdkMediaDeleteCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.deleteMedia(media, model: deviceModel, completion: completion)
        } else {
            ULog.w(.ctrlTag, "deleteMedia called without backend")
        }
        return nil
    }

    final func downloadMedia(_ media: ArsdkMedia, format: ArsdkMediaResourceFormat,
                             destDirectoryPath: String, progress: @escaping ArsdkMediaDownloadProgress,
                             completion: @escaping ArsdkMediaDownloadCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadMedia(
                media, model: deviceModel, format: format, destDirectoryPath: destDirectoryPath,
                progress: progress, completion: completion)
        } else {
            ULog.w(.ctrlTag, "downloadMedia called without backend")
        }
        return nil
    }

    /// Update the controlled device with a given firmware file
    ///
    /// - Parameters:
    ///   - file: the firmware file path
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the upload request
    final func update(withFile file: String, progress: @escaping ArsdkUpdateProgress,
                      completion: @escaping ArsdkUpdateCompletion) -> CancelableCore? {
        if let backend = backend {
            return backend.update(
                withFile: file, model: deviceModel, progress: progress, completion: { [weak self] status in
                    completion(status)
                    if status == .ok {
                        self?.firmwareDidUpload()
                    }
                })
        } else {
            ULog.w(.ctrlTag, "update firmware called without backend")
        }
        return nil
    }

    /// Uploads a given file on a given server type of a drone
    ///
    /// - Parameters:
    ///   - file: local path of the file
    ///   - to: destination path of the file
    ///   - serverType: type of the server on which to upload
    ///   - progress: progress block
    ///   - completion: completion block
    /// - Returns: low level request that can be used to cancel the upload request
    final func upload(
        file srcPath: String, to dstPath: String, serverType: ArsdkFtpServerType,
        progress: @escaping ArsdkFtpRequestProgress, completion: @escaping ArsdkFtpRequestCompletion) -> ArsdkRequest? {
            if let backend = backend {
                return backend.upload(file: srcPath, to: dstPath, model: deviceModel, serverType: serverType,
                                      progress: progress, completion: completion)
            } else {
                ULog.w(.ctrlTag, "upload file called without backend")
            }
            return nil
        }

    /// Download crashmls from the controlled device
    ///
    /// - Parameters:
    ///   - path: path where crashmls will be downloaded
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    final func downloadCrashml(path: String, progress: @escaping ArsdkCrashmlDownloadProgress,
                               completion: @escaping ArsdkCrashmlDownloadCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadCrashml(path: "\(path)/", model: deviceModel, progress: progress,
                                           completion: { status in
                completion(status)
            })
        } else {
            ULog.w(.ctrlTag, "crashml download called without backend")
        }
        return nil
    }

    /// Download flight logs from the controlled device
    ///
    /// - Parameters:
    ///   - path: path where flight logs will be downloaded
    ///   - progress: progress closure
    ///   - completion: completion closure
    /// - Returns: low level request, that can be used to cancel the download request
    final func downloadFlightLog(path: String, progress: @escaping ArsdkFlightLogDownloadProgress,
                                 completion: @escaping ArsdkFlightLogDownloadCompletion) -> ArsdkRequest? {
        if let backend = backend {
            return backend.downloadFlightLog(path: path, model: deviceModel, progress: progress,
                                             completion: { status in
                completion(status)
            })
        } else {
            ULog.w(.ctrlTag, "flight log download called without backend")
        }
        return nil
    }

    /// Signal that data sync allowance might have change.
    /// If it has actually changed, notify all components controllers about that change.
    final func dataSyncAllowanceMightHaveChanged() {
        if previousDataSyncAllowed != dataSyncAllowed {
            previousDataSyncAllowed = dataSyncAllowed

            activeProvider?.dataSyncAllowanceMightHaveChanged(deviceController: self)
            componentControllers.forEach {
                $0.dataSyncAllowanceChanged(allowed: dataSyncAllowed)
            }
        }
    }

    /// Make a transition in the connection state machine
    /// As the state machine is linear, we don't need the transition
    ///
    /// - Parameter cause: disconnection cause. Ignored if error is false.
    final func transitToNextConnectionState(withCause cause: DeviceState.ConnectionStateCause? = nil) {
        switch connectionSession.state {
        case .disconnected,
                .connecting,
                .backupLink:
            connectionSession.state = .creatingDeviceHttpClient
            ULog.i(.ctrlTag, "\(self) connected, creating the device http client")
            protocolWillConnect()
            // can force unwrap backend since we are connecting
            backend!.createTcpProxy(model: deviceModel, port: 80) { [weak self] proxy, address, port in
                guard let self = self else { return }
                guard self.connectionSession.state == .creatingDeviceHttpClient else { return }

                self.arsdkTcpProxy = proxy
                if let address = address {
                    self.deviceServer = DeviceServer(address: address, port: port)
                }
                // even if the creation of the tcp proxy failed, transit to next connection state.
                self.transitToNextConnectionState()
            }
        case .creatingDeviceHttpClient:
            ULog.i(.ctrlTag, "\(self) http client created, send date/time, getting AllSettings")
            connectionSession.state = .gettingAllSettings
            sendDateAndTime()
            sendLogsync(withRequest: true)
            sendGetAllSettings()
        case .gettingAllSettings:
            connectionSession.state = .gettingAllStates
            ULog.i(.ctrlTag, "\(self) AllSettingsChanged, getting AllStates")
            sendGetAllStates()
        case .gettingAllStates:
            // state is first changed in order to let component controllers freely ask whether data sync is allowed,
            // but do not notify them yet (they will be notified right after).
            connectionSession.state = .connected
            ULog.i(.ctrlTag, "\(self) AllStates, ready")
            _dataSyncAllowed = true
            // calling didConnect on all component controllers.
            protocolDidConnect()
            // now we can notify the component controllers about the new data sync allowance
            dataSyncAllowanceMightHaveChanged()
            // if board identifier not received during connection, we know board identifier is unavailable
            if device.boardIdHolder.boardId == nil {
                device.boardIdHolder.update(boardId: "")
            }
            // store the device
            deviceStore.write(key: PersistentStore.deviceName, value: device.nameHolder.name) // needed for the rc
            deviceStore.write(key: PersistentStore.deviceType, value: deviceModel.internalId)
            deviceStore.write(key: PersistentStore.devicePresetUid, value: presetStore.key)
            deviceStore.commit()
            device.stateHolder.state?.update(connectionState: .connected,
                                             withCause: .none)
                .update(persisted: true).notifyUpdated()
        default:
            break
        }
    }

    /// Make a transition in the connection state machine to the disconnected state
    ///
    /// - Parameter cause: disconnection cause. Ignored if error is false.
    ///
    /// - Note: Note that this method does not publish changes made to the device state.
    ///   Caller has the responsibility to call `notifyUpdated`.
    final func transitToDisconnectedState(withCause cause: DeviceState.ConnectionStateCause? = nil) {
        guard connectionSession.state != .disconnected else { return }

        ULog.i(.ctrlTag, "\(self) disconnected")

        let formerState = connectionSession.state
        connectionSession.state = .disconnected

        arsdkTcpProxy = nil
        deviceServer = nil

        // In "connecting" state the "protocol" connection is not yet initiated.
        if formerState != .connecting {
            // Notify the disconnection.
            protocolDidDisconnect()
        }
        _dataSyncAllowed = false
        dataSyncAllowanceMightHaveChanged()
        if let cause = cause {
            device.stateHolder.state?.update(connectionState: .disconnected, withCause: cause)
        } else {
            device.stateHolder.state?.update(connectionState: .disconnected)
        }

        // The device controller should automatically reconnect to the device when all the following conditions are met:
        // - the autoReconnect flag is set,
        // - the device controller has an active provider,
        // - this provider has no parent provider.
        // If the provider has a parent provider, the latter should handle the auto reconnection itself.
        let shouldAutoReconnect = autoReconnect && activeProvider != nil && activeProvider?.parent == nil
        if !shouldAutoReconnect ||
            !doConnect(provider: activeProvider!, parameters: [], cause: .connectionLost) {
            activeProvider = nil
            device.stateHolder.state?.update(activeConnector: nil)
        }
    }

    /// Send log synchronisation messages to the managed device
    private final func sendLogsync(withRequest: Bool) {
        if withRequest {
            let cmd = ArsdkLogsyncCommandEncoder.encoder(.syncRequest(SwiftProtobuf.Google_Protobuf_Empty()))
            _ = sendCommand(cmd)
        }
        var node = Arsdk_Logsync_Node()
        node.bootID = GroundSdk.bootID()
        node.model = UInt32(Arsdk_Logsync_Model.iosDevice.rawValue)
        node.role = .controller
        let evt = ArsdkLogsyncEventEncoder.encoder(.identifier(node))
        _ = sendCommand(evt)
    }

    /// Ask to the managed drone to get all its settings
    /// This step is ended when AllSettingsChanged event is received
    private final func sendGetAllSettings() {
        _ = sendCommand(getAllSettingsEncoder)
    }

    /// Ask to the managed drone to get all its states
    /// This step is ended when AllStatesChanged event is received
    private final func sendGetAllStates() {
        _ = sendCommand(getAllStatesEncoder)
    }

    // MARK: Methods managing connection state that subclass can implements

    /// Device controller did start
    func controllerDidStart() {
    }

    /// Device controller did stop
    func controllerDidStop() {
    }

    /// About to connect the device
    func protocolWillConnect() {
        componentControllers.forEach { component in component.willConnect() }
    }

    /// Device is connected (allSettings/States received)
    func protocolDidConnect() {
        // create the nonAckCommandLoop
        self.backend?.createNoAckCmdLoop(periodMs: noAckLoopPeriod)
        componentControllers.forEach { component in component.didConnect() }
        deviceEventLogger?.didConnect()
    }

    /// Device is disconnected
    func protocolDidDisconnect() {
        deviceEventLogger?.didDisconnect()
        componentControllers.forEach { component in component.didDisconnect() }
        self.backend?.deleteNoAckCmdLoop()
        blackBoxSession?.close()
        blackBoxSession = nil
    }

    /// A command has been received
    /// - Parameter command: received command
    func protocolDidReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            let cmdDec = ArsdkLogsyncCommandDecoder(listener: self)
            let evtDec = ArsdkLogsyncEventDecoder(listener: self)
            ArsdkFeatureGeneric.decode(command, callback: cmdDec)
            ArsdkFeatureGeneric.decode(command, callback: evtDec)
        }
        blackBoxSession?.onCommandReceived(command)
        deviceEventLogger?.onCommandReceived(command: command)
    }

    /// Firmware upload did success
    func firmwareDidUpload() { }
}

/// Extension of DeviceController that implements DeviceCoreDelegate
extension DeviceController: DeviceCoreDelegate {

    /// Removes the device from known devices list and clear all its stored data.
    ///
    /// - Returns: true if the device has been forgotten.
    final func forget() -> Bool {
        if connectionSession.state != .disconnected {
            _ = disconnect()
        }
        ULog.i(.ctrlTag, "Forgetting \(self)")
        componentControllers.forEach { component in component.willForget() }
        providers.forEach { $0.forget(deviceController: self)}
        deviceStore.clear()
        deviceStore.commit()
        device.stateHolder.state?.update(persisted: false).notifyUpdated()
        if providers.isEmpty {
            stopSelf()
        }
        return true
    }

    /// Connects the device.
    ///
    /// - Parameters:
    ///    - connector: connector to use to connect this device
    ///    - parameters: custom parameters to use to connect this device
    /// - Returns: true if the connection process has started
    final func connect(connector: DeviceConnector, parameters: [DeviceConnectionParameter]) -> Bool {
        if let provider = providers.first(where: { $0.connector == connector }) {
            ULog.d(.ctrlTag, "Connecting device \(self) using provider \(provider)")
            return doConnect(provider: provider, parameters: parameters, cause: .userRequest)
        }
        return false
    }

    /// Disconnects the device.
    ///
    /// This method can be used to disconnect the device when connected or to cancel the connection process if the
    /// device is currently connecting.
    ///
    /// - Returns: true if the disconnection process has started, false otherwise.
    final func disconnect() -> Bool {
        autoReconnect = false
        return doDisconnect(cause: .userRequest)
    }
}

// Backend callbacks
extension DeviceController {
    final func apiCapabilities(_ api: ArsdkApiCapabilities) {
        if api != apiCapabilities {
            guard api != ArsdkApiCapabilities.unknown else {
                ULog.w(.ctrlTag, "Bad API capabilities \(api)")
                return
            }
            apiCapabilities = api
            componentControllers.forEach { component in component.apiCapabilities(api) }
        }
    }

    final func linkWillConnect(provider: DeviceProvider, backupLink: Bool) {
        // connectionSession.state can be set to .connecting before linkWillConnect call
        guard connectionSession.state == .disconnected ||
                connectionSession.state == .connectionRequested ||
                connectionSession.state == .connecting ||
                connectionSession.state == .backupLink else {
            ULog.e(.ctrlTag, "Bad connection session state: \(connectionSession.state)")
            return
        }

        let cause: DeviceState.ConnectionStateCause? = backupLink ? .backupLink : nil

        if activeProvider == nil || activeProvider == provider {
            ULog.d(.ctrlTag, "\(self) link connecting [provider: \(provider)]")

            activeProvider = provider
            autoReconnect = false
            connectionSession.state = .connecting

            if let cause = cause {
                device.stateHolder.state?.update(connectionState: .connecting, withCause: cause)
            } else {
                device.stateHolder.state?.update(connectionState: .connecting)
            }
            device.stateHolder.state?.update(activeConnector: activeProvider!.connector)
                .notifyUpdated()
        }
    }

    final func linkDidConnect(provider: DeviceProvider, backend: DeviceControllerBackend) {
        // connectionSession.state can be set to .connecting before linkWillConnect call
        guard connectionSession.state == .connecting ||
                connectionSession.state == .disconnecting ||
                connectionSession.state == .disconnected ||
                connectionSession.state == .connectionRequested ||
                connectionSession.state == .backupLink else {
            // a proxy device controller may callback multiple times here in bad states, ignore.
            ULog.w(.ctrlTag, "Bad connection session state: \(connectionSession.state)")
            return
        }

        ULog.d(.ctrlTag, "\(self) link connected [provider: \(provider)]")

        self.backend = backend

        // a proxy device controller may callback directly here (without calling linkWillConnect), so make sure to
        // pass through connecting state
        if connectionSession.state != .connecting {
            linkWillConnect(provider: provider, backupLink: false)
        }

        transitToNextConnectionState()
    }

    /// Called when main link-level connection is lost, yet a backup link is still provided that allows for
    /// basic/emergency telemetry and control.
    final func backupLinkDidActivate(provider: DeviceProvider, backend: DeviceControllerBackend) {
        guard connectionSession.state != .backupLink else {
            // a proxy device controller may callback multiple times here in this state, ignore.
            ULog.w(.ctrlTag, "Bad connection session state: \(connectionSession.state)")
            return
        }

        ULog.d(.ctrlTag, "\(self) backup link activated [provider: \(provider)]")

        self.backend = backend

        // For the time being, we inline the transitToDisconnectedState routine here and we customize it for backup link
        // scenario. We may consider factorizing back at a later time, once the feature is stable (and we have
        // unit/integration tests for it).
        activeProvider = provider
        connectionSession.state = .backupLink
        arsdkTcpProxy = nil
        deviceServer = nil

        // TODO: maybe we should keep the blackbox alive in backup link... dunno: blackboxes are planned to be removed.
        blackBoxSession?.close()
        blackBoxSession = nil
        componentControllers.forEach { component in component.backupLinkDidActivate() }
        _dataSyncAllowed = false
        dataSyncAllowanceMightHaveChanged()

        // In case the device was previously disconnected, we 'mock' its state as 'CONNECTED'
        device.stateHolder.state?.update(connectionState: .connected,
                                         withCause: .backupLink)
            .update(persisted: true)
            .notifyUpdated()
    }

    final func linkDidDisconnect(removing: Bool) {
        ULog.d(.ctrlTag, "\(self) link disconnected [removing: \(removing)]")

        autoReconnect = autoReconnect || removing
        transitToDisconnectedState(withCause: removing ? .connectionLost : nil)
        self.backend = nil

        device.stateHolder.state.notifyUpdated()
    }

    final func linkDidCancelConnect(cause: DeviceState.ConnectionStateCause, removing: Bool) {
        autoReconnect = autoReconnect || removing
        transitToDisconnectedState(withCause: removing ? .connectionLost : cause)

        device.stateHolder.state.notifyUpdated()
    }

    final func didLoseLink() {
        ULog.i(.ctrlTag, "\(self) did lose link")
        componentControllers.forEach { component in component.didLoseLink() }

        autoReconnect = true
        _ = doDisconnect(cause: .connectionLost)
    }

    final func didReceiveCommand(_ command: OpaquePointer) {
        protocolDidReceiveCommand(command)
        componentControllers.forEach { component in
            component.didReceiveCommand(command)
        }
    }
}

/// Extension of DeviceController that implements ArsdkLogsyncEventDecoderListener
extension DeviceController: ArsdkLogsyncEventDecoderListener {

    func onIdentifier(_ identifier: Arsdk_Logsync_Node) {
        ULog.n(.ctrlTag, "EVT:BOOTID_SYNC;bootid='\(identifier.bootID)';model=\(identifier.model)" +
               ";role=\(identifier.role.rawValue)")
    }
}

/// Extension of DeviceController that implements ArsdkLogsyncCommandDecoderListener
extension DeviceController: ArsdkLogsyncCommandDecoderListener {

    func onSyncRequest(_ syncRequest: SwiftProtobuf.Google_Protobuf_Empty) {
        sendLogsync(withRequest: false)
    }
}

/// Extension of PersistentStore that brings dependency to GroundSdk
extension PersistentStore {
    /// Preset key for a given model
    ///
    /// - Parameter model: the model to get the key for
    /// - Returns: the key to access the preset
    static func presetKey(forModel model: DeviceModel) -> String {
        return model.description
    }
}

/// Extension of ArsdkRequest that makes it implement the Cancelable protocol
extension ArsdkRequest: CancelableCore { }
