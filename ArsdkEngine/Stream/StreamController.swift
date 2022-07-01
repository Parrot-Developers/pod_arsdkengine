// Copyright (C) 2021 Parrot Drones SAS
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

/// Stream controller listerner for stream server
public protocol StreamControllerServerListener {
    /// Notifies that the stream would like to be open, following an explicit request of play or pause.
    /// - Parameter streamController: the caller stream controller.
    func streamWouldOpen(streamController: StreamController)
    /// Notifies the close of the native stream, following an explicit request of stop or disable.
    /// - Parameter streamController: the caller stream controller.
    func streamDidClose(streamController: StreamController)
}

/// Stream controller implementation making the link between a StreamCore and an ArsdkStream.
public class StreamController: NSObject, StreamBackend {

    /// Live stream controller.
    class Live: StreamController {
        /// Device controller owner of the stream.
        let droneController: DroneController

        /// Constructor.
        ///
        /// - Parameters:
        ///    - deviceController: device controller to use to open the stream
        ///    - cameraType: type of camera live to stream
        ///    - stream: gsdk StreamCore ower of this StreamController
        public init(deviceController: DeviceController, cameraType: CameraLiveSource,
                    stream: StreamCore) {

            self.droneController = (deviceController as! DroneController)
            let source = droneController.createVideoSourceLive(cameraType: cameraType.arsdkValue!)!

            super.init(source: source, stream: stream)

            self.sdkcoreStream = droneController.createVideoStream(listener: self)!
        }
    }

    /// Media stream controller.
    class Media: StreamController {
        /// Device controller owner of the stream.
        let droneController: DroneController

        /// Constructor.
        ///
        /// - Parameters:
        ///    - deviceController: device controller to use to open the stream
        ///    - url: media source url
        ///    - trackName: track name of the source to stream
        ///    - stream: gsdk StreamCore ower of this StreamController
        public init(deviceController: DeviceController, url: String, trackName: String?,
                    stream: StreamCore) {

            self.droneController = (deviceController as! DroneController)
            let source = droneController.createVideoSourceMedia(url: url, trackName: trackName)!

            super.init(source: source, stream: stream)

            sdkcoreStream = droneController.createVideoStream(listener: self)!
        }
    }

    /// File replay stream controller.
    class FileReplay: StreamController {
        /// Pomp loop running the sdkcoreStream.
        let pompLoopUtil: PompLoopUtil

        /// Constructor.
        ///
        /// - Parameters:
        ///    - url: file source url
        ///    - trackName: track name of the source to stream
        ///    - stream: gsdk StreamCore ower of this StreamController
        public init(url: String, trackName: String?, stream: StreamCore) {

            let fileSource = SdkCoreFileSource(path: url, trackName: trackName)
            pompLoopUtil = PompLoopUtil(name: "com.parrot.arsdkengine.fileReplay:"+url)

            super.init(source: fileSource, stream: stream)

            sdkcoreStream = ArsdkStream(pompLoopUtil: pompLoopUtil, listener: self)
            pompLoopUtil.runLoop()
        }

        /// Destructor.
        deinit {
            pompLoopUtil.stopRun()
        }
    }

    /// if `false` the stream is forced to stop regardless of the `state`,
    /// If `true` the stream is enabled and the `state` is effective.
    public var enabled: Bool = false {
        didSet {
            if oldValue != enabled {
                ULog.i(.streamTag, "set enable: \(enabled)")
                stateRun()
            }
        }
    }

    /// Play state.
    public var state = StreamPlayState.stopped {
        didSet {
            if oldValue != state {
                DispatchQueue.main.async {
                    if self.state != .stopped {
                        self.serverListener?.streamWouldOpen(streamController: self)
                    }

                    self.gsdkStream?.streamPlayStateDidChange(playState: self.state)
                }
            }
        }
    }

    /// Gsdk StreamCore for which this object is the backend.
    private weak var gsdkStream: StreamCore?

    /// SdkCoreStream instance.
    fileprivate var sdkcoreStream: ArsdkStream!

    /// Stream source to play.
    fileprivate let source: SdkCoreSource

    /// Current SdkCoreStream command.
    private var currentCmd: Command?
    /// Pending SdkCoreStream command.
    private var pendingSeekCmd: Command?
    /// Last SdkCoreStream command failed.
    private var lastCmdFailed: Command?
    /// Last SdkCoreStream command status.
    private var lastCmdStatus = Int32(0)

    /// Stream sinks.
    private var sinks: Set<SinkController> = []

    /// Media registry
    private var medias = MediaRegistry()

    /// Stream server listening this StreamController
    public var serverListener: StreamControllerServerListener?

    /// Constructor
    ///
    /// - Parameters :
    ///    - source: source to stream
    ///    - stream: gsdk StreamCore ower of this StreamController
    init(source: SdkCoreSource, stream: StreamCore) {
        self.gsdkStream = stream
        self.source = source
        super.init()

        // MUST be inherited to set property sdkcoreStream.
    }

    /// Set the stream in playing state.
    public func play() {
        ULog.i(.streamTag, "play")
        state = .playing
        stateRun()
    }

    /// Set the stream in paused state.
    public func pause() {
        ULog.i(.streamTag, "pause")
        state = .paused
        stateRun()
    }

    /// Set the stream at a specific position.
    ///
    /// - Parameter position: position to seek in the stream, in seconds.
    public func seek(position: Int) {
        ULog.i(.streamTag, "seek to position: \(position)")

        if state == .stopped {
            state = .paused
        }
        pendingSeekCmd = CommandSeek(streamCtrl: self, position: position)
        stateRun()
    }

    /// Set the stream in stopped state.
    public func stop() {
        ULog.i(.streamTag, "stop")
        state = .stopped
        pendingSeekCmd = nil
        stateRun()
    }

    /// Manages the machine state.
    private func stateRun() {
        ULog.d(.streamTag, "stateRun enabled: \(enabled) state: \(state)")

        updateGsdkStreamState()

        if !enabled {
            // force stopped state.
            stateStoppedRun()
        } else {
            switch state {
            case .paused:
                statePausedRun()
            case .stopped:
                stateStoppedRun()
            case .playing:
                statePlayingRun()
            }
        }
    }

    /// Manages the stopped state.
    private func stateStoppedRun() {
        ULog.d(.streamTag, "stateStoppedRun sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
        switch sdkcoreStream.state {
        case .opening:
            // abort openning
            // Send close command.
            setCmd(CommandClose(streamCtrl: self))
        case .opened:
            // Send close command.
            setCmd(CommandClose(streamCtrl: self))
        case .closing:
            // Waiting closed state.
            break
        case .closed:
            // Do nothing.
            break
        @unknown default:
            ULog.e(.streamTag, "stateStoppedRun Bad sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
            return
        }
    }

    /// Manages the playing state.
    private func statePlayingRun() {
        ULog.d(.streamTag, "statePlayingRun sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
        switch sdkcoreStream.state {
        case .opening:
            // Waiting opened state.
            break
        case .opened:
            if sdkcoreStream.playbackState()?.speed == 0 || lastCmdStatus == -ETIMEDOUT {
                // Send play command.
                setCmd(CommandPlay(streamCtrl: self))
            } else if let pendingSeekCmd = pendingSeekCmd {
                // Send seek command.
                setCmd(pendingSeekCmd)
            }

        case .closing:
            // Waiting closed state.
            break
        case .closed:
            // Send open command.
            setCmd(CommandOpen(streamCtrl: self))
        @unknown default:
            ULog.e(.streamTag, "statePlayingRun Bad sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
            return
        }
    }

    /// Manages the paused state.
    private func statePausedRun() {
        ULog.d(.streamTag, "statePausedRun sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
        switch sdkcoreStream.state {
        case .opening:
            // Waiting opened state.
            break
        case .opened:
            if sdkcoreStream.playbackState()?.speed != 0 || lastCmdStatus == -ETIMEDOUT {
                // Send pause cmd
                setCmd(CommandPause(streamCtrl: self))
            } else if let pendingSeekCmd = pendingSeekCmd {
                // Send seek command.
                setCmd(pendingSeekCmd)
            }
        case .closing:
            // Waiting closed state.
            break
        case .closed:
            // Send open command.
            setCmd(CommandOpen(streamCtrl: self))
        @unknown default:
            ULog.e(.streamTag, "statePausedRun Bad sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
            return
        }
    }

    /// Updates the gsdk stream state.
    private func updateGsdkStreamState() {
        DispatchQueue.main.async {
            if !self.enabled && self.state != .stopped {
                ULog.i(.streamTag, "gsdkStream suspended")
                self.gsdkStream?.update(state: .suspended).notifyUpdated()
            } else if self.state == .stopped {
                ULog.i(.streamTag, "gsdkStream stopped")
                self.gsdkStream?.update(state: .stopped).notifyUpdated()
            } else if self.sdkcoreStream.state == .opened {
                ULog.i(.streamTag, "gsdkStream started")
                self.gsdkStream?.update(state: .started).notifyUpdated()
            } else {
                ULog.i(.streamTag, "gsdkStream starting")
                self.gsdkStream?.update(state: .starting).notifyUpdated()
            }
        }
    }

    /// Sets the command to send.
    ///
    /// - Parameter cmd: command to send
    private func setCmd(_ cmd: Command) {
        ULog.d(.streamTag, "setCmd cmd \(cmd) currentCmd: \(String(describing: currentCmd))" +
                " lastCmdFailed: \(String(describing: lastCmdFailed))")
        if currentCmd == nil && cmd != lastCmdFailed {
            currentCmd = cmd
            cmd.execute()
        }
    }

    /// Notifies the current command completion.
    ///
    /// - Parameter status: command completion status
    fileprivate func cmdCompletion(status: Int32) {
        ULog.d(.streamTag, "cmdCompletion currentCmd: \(String(describing: currentCmd)) status: \(status)")

        if status == 0 {
            if currentCmd == pendingSeekCmd {
                pendingSeekCmd = nil
            }

            lastCmdFailed = nil
            lastCmdStatus = 0
            currentCmd = nil
            stateRun()
        } else if status == -ETIMEDOUT {
            ULog.w(.streamTag, "command \(String(describing: currentCmd)) timeout")
            // Consider the command as not sent.

            lastCmdFailed = currentCmd
            lastCmdStatus = status
            currentCmd = nil
            stateRun()
        } else {
            ULog.e(.streamTag, "cmdCompletion command \(String(describing: currentCmd))" +
                   " err=\(status)(\(String(describing: strerror(-status)))")

            lastCmdFailed = currentCmd
            lastCmdStatus = status
            currentCmd = nil
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                self.lastCmdFailed = nil
                self.lastCmdStatus = 0
                self.stateRun()
            }
        }
    }

    /// Describes the sdkcore stream state.
    ///
    /// - Returns sdkcore stream state description
    func sdkcoreStreamStateDescription() -> String {
        switch sdkcoreStream.state {

        case .opening:
            return "opening"
        case .opened:
            return "opened"
        case .closing:
            return "closing"
        case .closed:
            return "closed"
        @unknown default:
            return "bad state"
        }
    }
}

// extension for sinks
extension StreamController {

    /// Registers a sink.
    ///
    /// - Parameter sink: sink to register
    public func register(sink: SinkController) {
        sinks.insert(sink)
        if sdkcoreStream.state == .opened {
            DispatchQueue.main.async {
                sink.onSdkCoreStreamAvailable(sdkCoreStream: self.sdkcoreStream)
            }
        }
    }

    /// Unregisters a sink.
    ///
    /// - Parameter sink: sink to unregister
    public func unregister(sink: SinkController) {
        sinks.remove(sink)
    }

    /// Retrieves RendererSink backend.
    ///
    /// - Parameter renderSink: GlRenderSinkCore owner of this backend.
    ///
    /// - returns: new GlRenderSink backend
    public func getRenderSinkBackend(renderSink: GlRenderSinkCore) -> GlRenderSinkBackend {
        return GlRenderSinkController(gsdkRenderSink: renderSink, streamCtrl: self)
    }

    /// Retrieves YuvSink backend.
    ///
    /// - Parameter yuvSink: YuvSinkCore owner of this backend.
    ///
    /// - returns: new YuvSink backend
    public func getYuvSinkBackend(yuvSink: YuvSinkCore) -> YuvSinkBackend {
        return YuvSinkController(gsdkYuvSink: yuvSink, streamCtrl: self)
    }

    /// Subscribes to stream media availability changes.
    ///
    /// In case a media of the requested kind is available when this method is called,
    /// 'MediaListener.onMediaAvailable()' is called immediately.
    ///
    /// - Parameters:
    ///    - listener: listener notified of media availability changes
    ///    - mediaType: type of media to listen
    func subscribeToMedia(listener: MediaListener, mediaType: SdkCoreMediaType) {
        medias.registerListener(listener: listener, mediaType: mediaType)
    }

    /// Unsubscribes from stream media availability changes.
    ///
    /// In case a media of the subscribed kind is still available when this method is called,
    /// {@code listener.}{@link MediaListener#onMediaUnavailable()} onMediaUnavailable()} is called immediately.
    ///
    /// - Parameters:
    ///    - listener: listener to unsubscribe
    ///    - mediaType: type of media that was listened
    func unsubscribeFromMedia(listener: MediaListener, mediaType: SdkCoreMediaType) {
        medias.unregisterListener(listener: listener, mediaType: mediaType)
    }
}

extension StreamController: ArsdkStreamListener {
    public func streamStateDidChange(_ stream: ArsdkStream) {
        ULog.d(.streamTag, "streamStateDidChange \(sdkcoreStreamStateDescription())")

        stateRun()

        switch sdkcoreStream.state {
        case .opening:
            break

        case .opened:
            // Notify sinks of the sdkCoreStream avability
            for sink in sinks {
                sink.onSdkCoreStreamAvailable(sdkCoreStream: sdkcoreStream)
            }

        case .closing:
            // Notify sinks of the sdkCoreStream unavability
            for sink in sinks {
                sink.onSdkCoreStreamUnavailable()
            }

        case .closed:
            // notify the server of the stream conplet closure
            if state == .stopped || !enabled {
                ULog.i(.streamTag, "streamDidClose")
                serverListener?.streamDidClose(streamController: self)
            }
        @unknown default:
            ULog.e(.streamTag, "streamStateDidChange Bad sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
            return
        }
    }

    public func streamPlaybackStateDidChange(_ stream: ArsdkStream, playbackState: ArsdkStreamPlaybackState) {
        gsdkStream?.streamPlaybackStateDidChange(duration: playbackState.duration,
                                       position: playbackState.position,
                                       speed: playbackState.speed,
                                       timestamp: TimeProvider.timeInterval)
    }

    public func mediaAdded(_ stream: ArsdkStream, mediaInfo: SdkCoreMediaInfo) {
        medias.addMedia(info: mediaInfo)
    }

    public func mediaRemoved(_ stream: ArsdkStream, mediaInfo: SdkCoreMediaInfo) {
        medias.removeMedia(info: mediaInfo)
    }
}

/// Sdkcore Stream command base.
private class Command: NSObject {

    /// The stream controller sending the command.
    let streamCtrl: StreamController

    /// Constructor.
    ///
    /// - Parameter streamCtrl: stream controller owner of this command.
    init(streamCtrl: StreamController) {
        self.streamCtrl = streamCtrl
    }

    /// Executes the command.
    func execute() {}

    override func isEqual(_ object: Any?) -> Bool {
        return type(of: object) == type(of: self)
    }

    public override var description: String {
        return "\(type(of: self))"
    }
}

/// Open command.
private class CommandOpen: Command {

    override func execute() {
        ULog.d(.streamTag, "CommandOpen")
        streamCtrl.sdkcoreStream.open(streamCtrl.source) { [weak self] status in
            ULog.d(.streamTag, "CommandOpen status: \(status)")
            self?.streamCtrl.cmdCompletion(status: status)
        }
    }
}

/// Play command.
private class CommandPlay: Command {

    override func execute() {
        ULog.d(.streamTag, "CommandPlay")
        streamCtrl.sdkcoreStream.play { [weak self] status in
            ULog.d(.streamTag, "CommandPlay status: \(status)")
            self?.streamCtrl.cmdCompletion(status: status)
        }
    }
}

/// Pause command.
private class CommandPause: Command {

    override func execute() {
        ULog.d(.streamTag, "CommandPause")
        streamCtrl.sdkcoreStream.pause { [weak self] status in
            ULog.d(.streamTag, "CommandPause status: \(status)")
            self?.streamCtrl.cmdCompletion(status: status)
        }
    }
}

/// Seek command.
private class CommandSeek: Command {
    /// Position to seek, in seconds.
    let position: Int

    /// Constructor.
    ///
    /// - Parameters:
    ///    - streamCtrl: stream controller owner of this command.
    ///    - position: position to seek, in seconds.
    init(streamCtrl: StreamController, position: Int) {
        self.position = position
        super.init(streamCtrl: streamCtrl)
    }

    override func execute() {
        ULog.d(.streamTag, "CommandSeek")
        streamCtrl.sdkcoreStream.seek(to: Int32(position)) { [weak self] status in
            if let self = self {
                ULog.d(.streamTag, "CommandSeek to \(self.position) status: \(status)")
                self.streamCtrl.cmdCompletion(status: status)
            }
        }
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? CommandSeek {
            return object.position == position
        } else {
            return false
        }
    }
}

/// Close command.
private class CommandClose: Command {

    override func execute() {
        ULog.d(.streamTag, "CommandClose")
        streamCtrl.sdkcoreStream.close { [weak self] status in
            ULog.d(.streamTag, "CommandClose status: \(status)")
            self?.streamCtrl.cmdCompletion(status: status)
        }
    }
}

/// Extension that adds conversion from/to arsdk enum
extension CameraLiveSource: ArsdkMappableEnum {

    static let arsdkMapper = Mapper<CameraLiveSource, ArsdkSourceLiveCameraType>([
        .unspecified: .unspecified,
        .frontCamera: .frontCamera,
        .frontStereoCameraLeft: .frontStereoCameraLeft,
        .frontStereoCameraRight: .frontStereoCameraRight,
        .verticalCamera: .verticalCamera,
        .disparity: .disparity])
}
