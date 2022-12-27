// Copyright (C) 2022 Parrot Drones SAS
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

/// StreamServer controller
class StreamServerController: DeviceComponentController, StreamServerBackend {

    /// StreamServer peripheral for which this object is the backend.
    private var streamServerCore: StreamServerCore!

    /// All currently maintained streams.
    private var controllers: [StreamController] = []
    /// Stream controller listeners owner.
    private var controllerListeners = [StreamController: StreamControllerListenerCore]()

    /// Maximum amount of streams that are allowed to be open at the same time. Opening a
    /// stream beyond this limit will result in the least recently open stream to be suspended in case of a
    /// [camera live stream][CameraLiveController], or closed in case of a [media replay stream][MediaReplayController].
    ///  A value of `0` disables any limit.
    private let maxConcurrentStreams: UInt

    /// Allows to remap requested live sources onto other live sources, mainly to provide
    /// compatibility with unsupported sources on legacy drones (Anafi 1 family).
    private let liveSourceMap: (CameraLiveSource) -> CameraLiveSource

    /// 'true' when streaming is enabled.
    public var enabled: Bool = false {
        didSet {
            if enabled != oldValue {
                streamServerCore.update(enable: enabled)
                if enabled {
                    let ctrls = controllers.reversed()

                    if maxConcurrentStreams == 0 {
                        ctrls.forEach { ctrl in
                            ctrl.enabled = true
                        }
                    } else {
                        ctrls.prefix(Int(maxConcurrentStreams)).forEach { ctrl in
                            ctrl.enabled = true
                        }
                    }
                } else {
                    for ctrl in controllers {
                        ctrl.suspend()
                    }
                }
            }
        }
    }

    /// Constructor
    ///
    /// - Parameters:
    ///    - deviceController: the drone controller that owns this peripheral controller.
    ///    - maxConcurrentStreams: Maximum amount of streams that are allowed to be open at the same time.
    ///      Opening a stream beyond this limit will result in the least recently open stream to be suspended in case of a
    ///      camera live stream, or closed in case of a media replay stream
    ///      A value of `0` disables any limit (default value).
    ///    - liveSourceMap: allows to remap requested live sources onto other live sources, mainly to provide
    ///      By default, remapping is disabled, sources are open as-is.
    init(deviceController: DeviceController, maxConcurrentStreams: UInt = 0,
         liveSourceMap: @escaping (CameraLiveSource) -> CameraLiveSource = { source in source }) {
        self.maxConcurrentStreams = maxConcurrentStreams
        self.liveSourceMap = liveSourceMap
        super.init(deviceController: deviceController)
        streamServerCore = StreamServerCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected.
    override func didConnect() {
        guard controllers.isEmpty else {
            ULog.e(.streamTag, "didConnect controllers not empty: \(controllers)")
            return
        }

        streamServerCore.enabled = true
        streamServerCore.publish()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        // dispose all stream controllers to correctly stop the sdkcoreStream in background
        controllers.forEach { strmCtrl in
            strmCtrl.dispose()
        }
        controllers.removeAll()
        controllerListeners.removeAll()
        streamServerCore.unpublish()
    }

    /// Registers a controller
    ///
    /// - Parameter controller: controller to register
    private func register(controller: StreamController) {
        controller.enabled = streamServerCore.enabled

        controllers.append(controller)
        controllerListeners[controller] = StreamControllerListenerCore(streamServerController: self,
                                                                       streamController: controller)
    }

    /// Creates a new `MediaReplayCore` instance to stream the given media source.
    ///
    /// - Parameter source: media source to stream
    /// - Returns: a new media replay stream
    func newMediaReplay(source: MediaSourceCore) -> MediaReplayCore {
        let ctrl = StreamController.Media(deviceController: deviceController, source: source)
        register(controller: ctrl)

        return ctrl.gsdkStreamMediaReplay
    }

    /// Releases the given media replay stream.
    ///
    /// - Parameter stream: media replay stream to release
    func releaseMediaReplay(stream: MediaReplayCore) {
        // remove the controller of this media replay stream
        guard let index = controllers.compactMap({ $0 as? StreamController.Media })
                .firstIndex(where: {$0.gsdkStream == stream}) else {
            return
        }
        let strCtrl = controllers.remove(at: index)
        strCtrl.dispose()
        controllerListeners[strCtrl] = nil
    }

    /// Retrieves a camera live stream.
    ///
    /// There is only one live stream instance for each CameraLiveSource, which is shared among all open references.
    ///
    /// - Parameter source: the camera live source of the live stream to retreive
    /// - Returns: the camera live stream researched
    func getCameraLive(source: CameraLiveSource) -> CameraLiveCore {
        // remap requested live source
        let liveSource = liveSourceMap(source)

        // If a live stream controller of this source exists
        if let ctrl = controllers.compactMap({ $0 as? StreamController.Live })
                .first(where: { $0.gsdkSource == liveSource }) {
            return ctrl.gsdkStreamLive
        } else {
            // Create a new live stream controller for this source
            let ctrl = StreamController.Live(deviceController: deviceController, source: liveSource)
            register(controller: ctrl)
            return ctrl.gsdkStreamLive
        }
    }

    /// Stream Controller Listener implementation.
    private class StreamControllerListenerCore: NSObject {
        /// Stream server controller
        unowned let streamServerCtrl: StreamServerController
        /// Stream controller
        unowned var streamCtrl: StreamController
        /// Stream controller Listener handle
        var listener: StreamController.ListenerHandle?

        /// Constructor
        ///
        /// - Parameters:
        ///    - streamServerController: stream server controller
        ///    - streamController: stream controller
        init(streamServerController: StreamServerController, streamController: StreamController) {
            self.streamServerCtrl = streamServerController
            self.streamCtrl = streamController
            super.init()

            listener = streamController.register(streamWouldOpen: { [unowned self] in
                streamWouldOpen()
            }, sdkcoreStreamStateDidChange: { [unowned self] state in
                sdkcoreStreamStateDidChange(state: state)
            }, availableMediaDidChange: {})
        }

        /// Called when the stream would like to be open, following an explicit request of play or pause.
        func streamWouldOpen() {
            guard let index = streamServerCtrl.controllers.firstIndex(of: streamCtrl) else {
                fatalError("strmCtrl not found")
            }

            ULog.d(.streamTag,
                   "Handling stream open request [streamingEnabled: \(streamServerCtrl.enabled)]: \(streamCtrl)")

            guard streamServerCtrl.enabled else { return }

            streamServerCtrl.controllers.remove(at: index)

            // if the concurrent streams limit is enabled
            if streamServerCtrl.maxConcurrentStreams > 0 {
                let activeStrmCtrls = streamServerCtrl.controllers.filter { ctrl in
                    ctrl.gsdkStream.state == .starting || ctrl.gsdkStream.state == .started
                }

                ULog.d(.streamTag, "Active streams: \(activeStrmCtrls.count)" +
                       "\(activeStrmCtrls.map {"\($0.description)"}.joined(separator: "\n  - "))"
                )

                if activeStrmCtrls.count == streamServerCtrl.maxConcurrentStreams {
                    activeStrmCtrls.last?.suspend()
                } else {
                    assert(activeStrmCtrls.count < streamServerCtrl.maxConcurrentStreams)
                }
                streamServerCtrl.enabled = true
            }

            streamServerCtrl.controllers.insert(streamCtrl, at: 0)
        }

        /// Called on the Sdkcore stream state change.
        ///
        /// - Parameter state: new Sdkcore stream state
        func sdkcoreStreamStateDidChange(state: ArsdkStreamState) {
            guard state != .closed else { return }

            // Note: controllers may be removed while the underlying sdkcore stream still notifying
            //       state changes (ex: on unpublish, we dispose/clear all controllers, but they will
            //       all report state -> CLOSED in this callback). Ignore them.
            guard let index = streamServerCtrl.controllers.firstIndex(of: streamCtrl) else { return }
            streamServerCtrl.controllers.remove(at: index)

            ULog.d(.streamTag, "Handling stream closing [streamingEnabled: \(streamServerCtrl.enabled)]: \(streamCtrl)")

            // if there is any stream suspended by concurrent streams limit.
            if streamServerCtrl.enabled &&
               streamServerCtrl.controllers.filter({ strmCtrl in
                   strmCtrl.gsdkStream.state == .starting || strmCtrl.gsdkStream.state == .started
               }).count < streamServerCtrl.maxConcurrentStreams {

                // resume the last live stream supended.
                streamServerCtrl.controllers.last { strmCtrl in
                    strmCtrl is StreamController.Live && strmCtrl.gsdkStream.state == .suspended
                }?.enabled = true
            }

            streamServerCtrl.controllers.append(streamCtrl)
        }
    }
}

extension StreamController {
    /// Suspends the stream.
    func suspend() {
        ULog.d(.streamTag, "Suspending stream: \(self)")
        enabled = false
        if self is StreamController.Media || self is StreamController.FileReplay {
            // stop file and media replay streams
            stop()
        }
    }
}
