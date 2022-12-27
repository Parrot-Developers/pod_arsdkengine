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

/// Stream controller implementation making the link between a StreamCore and an ArsdkStream.
public class StreamController: NSObject, ReplayCoreBackend {

    /// Live stream controller.
    class Live: StreamController {
        /// Device controller owner of the stream.
        let droneController: DroneController

        /// Ground SDK live stream.
        var gsdkStreamLive: CameraLiveCore {
            gsdkStream as! CameraLiveCore
        }

        /// Ground SDK camera live source.
        public let gsdkSource: CameraLiveSource

        /// Constructor.
        ///
        /// - Parameters:
        ///    - deviceController: device controller to use to open the stream
        ///    - source: live source for the stream
        public init(deviceController: DeviceController, source: CameraLiveSource) {
            self.droneController = (deviceController as! DroneController)
            gsdkSource = source
            let arsdkSource = droneController.createVideoSourceLive(cameraType: source.arsdkValue!)!
            let sdkcoreStream = droneController.createVideoStream()!
            let backend = StreamCoreBackendCore()
            let gsdkStreamLive = CameraLiveCore(source: source, backend: backend)
            super.init(source: arsdkSource, stream: gsdkStreamLive, sdkcoreStream: sdkcoreStream, backend: backend)

            backend.controller = self
            sdkcoreStream.listener = self
        }
    }

    /// Media stream controller.
    class Media: StreamController {
        /// Device controller owner of the stream.
        let droneController: DroneController

        /// Ground SDK media replay.
        var gsdkStreamMediaReplay: MediaReplayCore {
            gsdkStream as! MediaReplayCore
        }

        /// Ground SDK media source.
        public let gsdkSource: MediaSourceCore

        /// Constructor.
        ///
        /// - Parameters:
        ///    - deviceController: device controller to use to open the stream
        ///    - source: media source to stream
        public init(deviceController: DeviceController, source: MediaSourceCore) {
            self.droneController = (deviceController as! DroneController)
            gsdkSource = source
            let arsdkSource = droneController.createVideoSourceMedia(url: source.streamUrl,
                                                                     trackName: source.streamTrackName)!
            let sdkcoreStream = droneController.createVideoStream()!
            let backend = StreamCoreBackendCore()
            let gsdkStreamMediaReplay = MediaReplayCore(source: source, backend: backend)
            super.init(source: arsdkSource, stream: gsdkStreamMediaReplay, sdkcoreStream: sdkcoreStream,
                       backend: backend)

            backend.controller = self
            sdkcoreStream.listener = self
        }
    }

    /// File replay stream controller.
    class FileReplay: StreamController {
        /// Pomp loop running the sdkcoreStream.
        let pompLoopUtil: PompLoopUtil

        /// Ground SDK file replay.
        var gsdkStreamFileReplay: FileReplayCore {
            gsdkStream as! FileReplayCore
        }

        /// Ground SDK file source.
        public let gsdkSource: FileReplaySource

        /// Constructor.
        ///
        /// - Parameter source: file source to stream
        public init(source: FileReplaySource) {

            gsdkSource = source
            let fileSource = SdkCoreFileSource(path: source.file.path, trackName: source.trackName)
            pompLoopUtil = PompLoopUtil(name: "com.parrot.arsdkengine.fileReplay:" + source.file.path)
            let backend = StreamCoreBackendCore()
            let gsdkStreamFileReplay = FileReplayCore(source: source, backend: backend)
            let sdkcoreStream = ArsdkStream(pompLoopUtil: pompLoopUtil)
            super.init(source: fileSource, stream: gsdkStreamFileReplay, sdkcoreStream: sdkcoreStream, backend: backend)

            backend.controller = self
            sdkcoreStream.listener = self

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
            guard oldValue != enabled else { return }

            ULog.i(.streamTag, "\(self) set enable: \(enabled)")
            stateRun()
        }
    }

    /// Play state.
    public var state = StreamPlayState.stopped {
        didSet {
            guard oldValue != state else { return }

            DispatchQueue.main.async {
                if oldValue == .stopped {
                    self.listeners.forEach { listener in
                        listener.streamWouldOpen()
                    }
                }
                self.gsdkStream.streamPlayStateDidChange(playState: self.state)
            }
        }
    }

    /// Gsdk StreamCore for which this object is the backend.
    var gsdkStream: StreamCore

    /// SdkCoreStream instance.
    var sdkcoreStream: ArsdkStream

    /// Stream source to play.
    fileprivate let source: SdkCoreSource

    /// StreamCore backend.
    private let backend: StreamCoreBackendCore

    /// Current SdkCoreStream command.
    private var currentCmd: Command?
    /// Pending SdkCoreStream command.
    private var pendingSeekCmd: Command?
    /// Last SdkCoreStream command failed.
    private var lastCmdFailed: Command?
    /// Last SdkCoreStream command status.
    private var lastCmdStatus = Int32(0)
    /// Stream controller listeners.
    private var listeners: Set<Listener> = []
    /// `true` if he stream controller is disposed and waits for the sdkcoreStream closure.
    private var disposed = false

    /// Constructor
    ///
    /// - Parameters :
    ///    - source: source to stream
    ///    - stream: gsdk StreamCore ower of this StreamController
    ///    - sdkcoreStream: sdkcoreStream to control
    ///    - backend: StreamCore backend.
    private init(source: SdkCoreSource, stream: StreamCore, sdkcoreStream: ArsdkStream,
                 backend: StreamCoreBackendCore) {
        self.gsdkStream = stream
        self.source = source
        self.sdkcoreStream = sdkcoreStream
        self.backend = backend
        super.init()
    }

    /// Disposes the controller.
    ///
    /// Must be called to correctly close sdkcoreStream.
    ///
    /// Once disposed, controller must not be used anymore.
    public func dispose() {
        assert(!disposed, "StreamController already disposed")
        disposed = true
        gsdkStream.releaseStream()
        // stop sdkcoreStream
        stop()
    }

    /// Set the stream in playing state.
    public func play() {
        ULog.i(.streamTag, "\(self) play")
        state = .playing
        stateRun()
    }

    /// Set the stream in paused state.
    public func pause() {
        ULog.i(.streamTag, "\(self) pause")
        state = .paused
        stateRun()
    }

    /// Set the stream at a specific position.
    ///
    /// - Parameter position: position to seek in the stream, in seconds.
    public func seek(position: Int) {
        ULog.i(.streamTag, "\(self) seek to position: \(position)")

        if state == .stopped {
            state = .paused
        }
        pendingSeekCmd = CommandSeek(streamCtrl: self, position: position)
        stateRun()
    }

    /// Set the stream in stopped state.
    public func stop() {
        ULog.i(.streamTag, "\(self) stop")
        state = .stopped
        pendingSeekCmd = nil
        stateRun()
    }

    public func newSink(config: SinkCoreConfig) -> SinkCore {
        if let config = config as? GlRenderSinkCore.Config {
            let sinkCtrl = GlRenderSinkController(streamCtrl: self, config: config)
            sinkCtrl.register()
            return sinkCtrl.gsdkRenderSink
        } else if let config = config as? RawVideoSinkConfig {
            let sinkCtrl = RawVideoSinkController(streamCtrl: self, config: config)
            sinkCtrl.register()
            return sinkCtrl.rawVideoSinkCore
        } else {
            fatalError("Bad stream sink configuration")
        }
    }

    /// Manages the machine state.
    private func stateRun() {
        ULog.d(.streamTag, "\(self) stateRun enabled: \(enabled) state: \(state)")

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
        ULog.d(.streamTag, "\(self) stateStoppedRun sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
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
            ULog.e(.streamTag, "\(self) stateStoppedRun Bad sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
            return
        }
    }

    /// Manages the playing state.
    private func statePlayingRun() {
        ULog.d(.streamTag, "\(self) statePlayingRun sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
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
            ULog.e(.streamTag, "\(self) statePlayingRun Bad sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
            return
        }
    }

    /// Manages the paused state.
    private func statePausedRun() {
        ULog.d(.streamTag, "\(self) statePausedRun sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
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
            ULog.e(.streamTag, "\(self) statePausedRun Bad sdkcoreStream.state: \(sdkcoreStreamStateDescription())")
            return
        }
    }

    /// Updates the gsdk stream state.
    private func updateGsdkStreamState() {
        DispatchQueue.main.async {
            if !self.enabled && self.state != .stopped {
                ULog.i(.streamTag, "\(self) gsdkStream suspended")
                self.gsdkStream.update(state: .suspended).notifyUpdated()
            } else if self.state == .stopped {
                ULog.i(.streamTag, "\(self) gsdkStream stopped")
                self.gsdkStream.update(state: .stopped).notifyUpdated()
            } else if self.sdkcoreStream.state == .opened {
                ULog.i(.streamTag, "\(self) gsdkStream started")
                self.gsdkStream.update(state: .started).notifyUpdated()
            } else {
                ULog.i(.streamTag, "\(self) gsdkStream starting")
                self.gsdkStream.update(state: .starting).notifyUpdated()
            }
        }
    }

    /// Sets the command to send.
    ///
    /// - Parameter cmd: command to send
    private func setCmd(_ cmd: Command) {
        ULog.d(.streamTag, "\(self) setCmd cmd \(cmd) currentCmd: \(String(describing: currentCmd))" +
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
        ULog.d(.streamTag, "\(self) cmdCompletion currentCmd: \(String(describing: currentCmd)) status: \(status)")

        if status == 0 {
            if currentCmd == pendingSeekCmd {
                pendingSeekCmd = nil
            }

            lastCmdFailed = nil
            lastCmdStatus = 0
            currentCmd = nil
            stateRun()
        } else if status == -ETIMEDOUT {
            ULog.w(.streamTag, "\(self) command \(String(describing: currentCmd)) timeout")
            // Consider the command as not sent.

            lastCmdFailed = currentCmd
            lastCmdStatus = status
            currentCmd = nil
            stateRun()
        } else {
            ULog.e(.streamTag, "\(self) cmdCompletion command \(String(describing: currentCmd))" +
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

/// extension for sinks
extension StreamController {

    /// Registers a listener
    ///
    /// - Parameters:
    ///    - streamWouldOpen: callback when the stream would open.
    ///    - sdkcoreStreamStateDidChange: callback on the Sdkcore stream state change.
    ///    - availableMediaDidChange: callback on the media availability change.
    ///
    /// - Returns listener: listener registered
    public func register(streamWouldOpen: @escaping () -> Void,
                         sdkcoreStreamStateDidChange: @escaping (ArsdkStreamState) -> Void,
                         availableMediaDidChange: @escaping () -> Void) -> ListenerHandle {
        let listener = Listener(streamWouldOpen: streamWouldOpen,
                                sdkcoreStreamStateDidChange: sdkcoreStreamStateDidChange,
                                availableMediaDidChange: availableMediaDidChange)
        listeners.insert(listener)
        return ListenerHandle(strmCtrl: self, listener: listener)
    }

    /// Stream controller listener handle
    /// The listener is removed when the handle is deinit.
    public class ListenerHandle {
        /// Stream controller
        weak var strmCtrl: StreamController?

        /// Stream controller listener
        let listener: Listener

        init(strmCtrl: StreamController, listener: Listener) {
            self.strmCtrl = strmCtrl
            self.listener = listener
        }

        deinit {
            // unregister the listener
            strmCtrl?.listeners.remove(listener)
        }
    }

    /// Stream controller listener for stream server
    class Listener: NSObject {

        /// Notifies that the stream would like to be open, following an explicit request of play or pause.
        let streamWouldOpen: () -> Void

        /// Notifies that the underlying sdkcore stream state changed.
        ///
        /// - Parameter state: new sdkcore stream state
        let sdkcoreStreamStateDidChange: (ArsdkStreamState) -> Void

        /// Notifies that the set of available medias for this stream changed.
        let availableMediaDidChange: () -> Void

        /// Contructor
        ///
        /// - Parameters:
        ///    - streamWouldOpen: Callback to notifies that the stream would like to be open,
        ///      following an explicit request of play or pause.
        ///    - sdkcoreStreamStateDidChange: Notifies that the underlying sdkcore stream state changed.
        ///    - availableMediaDidChange: Notifies that the set of available medias for this stream changed.
        init(streamWouldOpen: @escaping () -> Void,
             sdkcoreStreamStateDidChange: @escaping (ArsdkStreamState) -> Void,
             availableMediaDidChange: @escaping () -> Void) {
            self.streamWouldOpen = streamWouldOpen
            self.sdkcoreStreamStateDidChange = sdkcoreStreamStateDidChange
            self.availableMediaDidChange = availableMediaDidChange
        }
    }
}

extension StreamController: ArsdkStreamListener {
    public func streamStateDidChange(_ stream: ArsdkStream) {
        ULog.d(.streamTag, "\(self) streamStateDidChange \(sdkcoreStreamStateDescription())")

        stateRun()

        // notify state change.
        for listener in listeners {
            listener.sdkcoreStreamStateDidChange(sdkcoreStream.state)
        }
    }

    public func streamPlaybackStateDidChange(_ stream: ArsdkStream, playbackState: ArsdkStreamPlaybackState) {
        gsdkStream.streamPlaybackStateDidChange(duration: playbackState.duration,
                                                position: playbackState.position,
                                                speed: playbackState.speed,
                                                timestamp: TimeProvider.timeInterval)
    }

    public func mediaAdded(_ stream: ArsdkStream, mediaInfo: SdkCoreMediaInfo) {
        listeners.forEach { listener in
            listener.availableMediaDidChange()
        }
    }

    public func mediaRemoved(_ stream: ArsdkStream, mediaInfo: SdkCoreMediaInfo) {
        listeners.forEach { listener in
            listener.availableMediaDidChange()
        }
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
        ULog.d(.streamTag, "\(streamCtrl) CommandOpen")
        streamCtrl.sdkcoreStream.open(streamCtrl.source) { [weak self] status in
            guard let self = self else { return }
            ULog.d(.streamTag, "\(self.streamCtrl) CommandOpen status: \(status)")
            self.streamCtrl.cmdCompletion(status: status)
        }
    }
}

/// Play command.
private class CommandPlay: Command {

    override func execute() {
        ULog.d(.streamTag, "\(streamCtrl) CommandPlay")
        streamCtrl.sdkcoreStream.play { [weak self] status in
            guard let self = self else { return }
            ULog.d(.streamTag, "\(self.streamCtrl) CommandPlay status: \(status)")
            self.streamCtrl.cmdCompletion(status: status)
        }
    }
}

/// Pause command.
private class CommandPause: Command {

    override func execute() {
        ULog.d(.streamTag, "\(streamCtrl) CommandPause")
        streamCtrl.sdkcoreStream.pause { [weak self] status in
            guard let self = self else { return }
            ULog.d(.streamTag, "\(self.streamCtrl) CommandPause status: \(status)")
            self.streamCtrl.cmdCompletion(status: status)
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
        ULog.d(.streamTag, "\(streamCtrl) CommandSeek")
        streamCtrl.sdkcoreStream.seek(to: Int32(position)) { [weak self] status in
            if let self = self {
                ULog.d(.streamTag, "\(self.streamCtrl) CommandSeek to \(self.position) status: \(status)")
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
        ULog.d(.streamTag, "\(streamCtrl) CommandClose")
        streamCtrl.sdkcoreStream.close { [weak self] status in
            guard let self = self else { return }
            ULog.d(.streamTag, "\(self.streamCtrl) CommandClose status: \(status)")
            self.streamCtrl.cmdCompletion(status: status)
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

/// StreamCore backend implementation
private class StreamCoreBackendCore: StreamCoreBackend {
    /// Stream controller
    weak var controller: StreamController?

    var enabled: Bool {
        get {
            controller?.enabled ?? false
        }
        set {
            assert(controller != nil)
            controller?.enabled = newValue
        }
    }

    var state: StreamPlayState { controller?.state ?? .stopped }

    func play() {
        assert(controller != nil)
        controller?.play()
    }

    func pause() {
        assert(controller != nil)
        controller?.pause()
    }

    func seek(position: Int) {
        assert(controller != nil)
        controller?.seek(position: position)
    }

    func stop() {
        assert(controller != nil)
        controller?.stop()
    }

    func newSink(config: SinkCoreConfig) -> SinkCore {
        assert(controller != nil)
        return controller?.newSink(config: config) ?? SinkCore()
    }
}
