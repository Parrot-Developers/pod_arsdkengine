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
import SdkCore

/// Implementation of the StreamSharingManager utility.
public class StreamSharingManagerCore: StreamSharingManager {

    /// The utility descriptor
    public let desc: UtilityCoreDescriptor = Utilities.streamSharingManager

    public var serviceStarted: Bool {
        return recordingStarted || streamStarted
    }

    /// Tells whether stream sharing is currently enabled.
    private var enabled: Bool = false

    /// Whether recording service is started.
    private var recordingStarted: Bool = false

    /// Whether streaming service is started.
    private var streamStarted: Bool = false

    /// Registered monitors.
    private var monitors: Set<Monitor> = []

    /// SdkCore stream sharing instance.
    private var sdkCoreStreamSharing: ArsdkStreamSharing!

    /// Constructor.
    ///
    /// - Parameter pompLoopUtil: pomp loop running the sdkCoreStream
    init(pompLoopUtil: PompLoopUtil) {
        sdkCoreStreamSharing = ArsdkStreamSharing(pompLoopUtil: pompLoopUtil, streamSharingDelegate: self)
    }

    public func start() {
        sdkCoreStreamSharing.start()
        enabled = true
        monitors.forEach { monitor in
            monitor.didEnable()
        }
    }

    public func stop() {
        sdkCoreStreamSharing.stop()
        enabled = false
        recordingStarted = false
        streamStarted = false
    }

    public func setStream(sdkCoreStream: ArsdkStream?) {
        if enabled {
            sdkCoreStreamSharing.setStream(sdkCoreStream)
        }
    }

    public func startRecording(mediaDir: URL, privateDir: URL, resolution: StreamSharingResolution, bitrate: Int,
                               overlay: Bool, unitSystem: OverlayUnitSystem,
                               coordinateSystem: OverlayCoordinateSystem) {
        sdkCoreStreamSharing.startRecording(mediaDir.path, privateDir: privateDir.path,
                                            resolution: resolution.arsdkValue!, bitrate: Int32(bitrate),
                                            overlay: overlay, unitSystem: unitSystem.arsdkValue!,
                                            coordinateSystem: coordinateSystem.arsdkValue!)
    }

    public func stopRecording() {
        sdkCoreStreamSharing.stopRecording()
        recordingStarted = false
    }

    public func finalizeRecord(reason: ArsdkStreamRecordStopReason) {
        sdkCoreStreamSharing.finalizeRecord(reason)
    }

    public func startStreaming(url: URL, resolution: StreamSharingResolution, maxBitrate: Int, overlay: Bool,
                               unitSystem: OverlayUnitSystem, coordinateSystem: OverlayCoordinateSystem,
                               rtspTransport: StreamSharingRtspTransport) {
        sdkCoreStreamSharing.startStream(url.absoluteString, resolution: resolution.arsdkValue!,
                                         maxBitrate: Int32(maxBitrate), overlay: overlay,
                                         unitSystem: unitSystem.arsdkValue!,
                                         coordinateSystem: coordinateSystem.arsdkValue!,
                                         rtspTransport: rtspTransport.arsdkValue!)
    }

    public func stopStreaming() {
        sdkCoreStreamSharing.stopStream()
        streamStarted = false
    }

    public func setRecordingState(recording: Bool, duration: TimeInterval) {
        if serviceStarted {
            sdkCoreStreamSharing.setRecordingState(recording, duration: UInt64(duration * 1000))
        }
    }

    public func setRecordingFormat(resolution: ArsdkStreamOverlayResolution, framerate: Float, isThermal: Bool) {
        if serviceStarted {
            sdkCoreStreamSharing.setRecordingFormat(resolution, framerate: framerate, isThermal: isThermal)
        }
    }

    public func setControllerBatteryLevel(level: Int) {
        if serviceStarted {
            sdkCoreStreamSharing.setControllerBatteryLevel(UInt32(level))
        }
    }
}

/// Extension for monitoring.
extension StreamSharingManagerCore {

    public func startMonitoring(didEnable: @escaping () -> Void,
                                serviceDidStart: @escaping () -> Void,
                                recordingStateDidChange: @escaping (StreamRecordingState?, _ file: URL?,
                                                                    _ reason: StreamRecordingStopReason?) -> Void,
                                streamingStateDidChange: @escaping (StreamingState, _ error: StreamingError?,
                                                               _ url: URL?) -> Void)
    -> MonitorCore {
        let monitor = Monitor(manager: self, didEnable: didEnable, serviceDidStart: serviceDidStart,
                              recordingStateDidChange: recordingStateDidChange,
                              streamingStateDidChange: streamingStateDidChange)
        monitors.insert(monitor)
        return monitor
    }

    /// Stops monitoring with a given monitor.
    ///
    /// - Parameter monitor: the monitor
    private func stopMonitoring(with monitor: Monitor) {
        monitors.remove(monitor)
    }

    /// Monitor allowing to listen to StreamSharingManager change notifications.
    private class Monitor: NSObject, MonitorCore {

        /// Monitored manager.
        private let manager: StreamSharingManagerCore

        /// Called back when stream sharing is enabled.
        fileprivate let didEnable: () -> Void

        /// Called back when stream recording service or streaming service is started.
        fileprivate let serviceDidStart: () -> Void

        /// Called back when recording state changes.
        fileprivate let recordingStateDidChange: (StreamRecordingState?, _ file: URL?,
                                                  _ reason: StreamRecordingStopReason?) -> Void

        /// Called back when streaming state changes.
        fileprivate let streamingStateDidChange: (StreamingState, _ error: StreamingError?, _ url: URL?) -> Void

        /// Contructor
        ///
        /// - Parameters:
        ///    - manager: the stream sharing manager
        ///    - didEnable: called back when stream sharing is enabled
        ///    - serviceDidStart: called back when stream recording service or streaming service is started
        ///    - recordingStateDidChange: called back when recording state changes
        ///    - streamingStateDidChange: called back when streaming state changes
        init(manager: StreamSharingManagerCore,
             didEnable: @escaping () -> Void,
             serviceDidStart: @escaping () -> Void,
             recordingStateDidChange: @escaping (StreamRecordingState?, _ file: URL?,
                                                 _ reason: StreamRecordingStopReason?) -> Void,
             streamingStateDidChange: @escaping (StreamingState, _ error: StreamingError?, _ url: URL?) -> Void) {
            self.manager = manager
            self.didEnable = didEnable
            self.serviceDidStart = serviceDidStart
            self.recordingStateDidChange = recordingStateDidChange
            self.streamingStateDidChange = streamingStateDidChange
        }

        func stop() {
            manager.stopMonitoring(with: self)
        }
    }
}

/// Extension for ArsdkStreamSharing events processing.
extension StreamSharingManagerCore: ArsdkStreamSharingDelegate {

    public func onRecord(_ event: ArsdkStreamEvent, reason: ArsdkStreamRecordStopReason, file fileName: String?) {

        let state: StreamRecordingState?

        switch event {
        case .start:
            state = .started
            recordingStarted = true
            monitors.forEach { monitor in monitor.serviceDidStart() }
        case .stop:
            state = .stopped
        case .begin:
            state = .recording
        case .end:
            state = recordingStarted ? .started : nil
        case .connecting:
            return
        case .error:
            state = .error
        @unknown default:
            return
        }

        monitors.forEach { monitor in
            monitor.recordingStateDidChange(
                state,
                fileName.flatMap { URL(string: $0) },
                StreamRecordingStopReason(fromArsdk: reason)
            )
        }
    }

    public func onStreamEvent(_ event: ArsdkStreamEvent, status: Int32, url: String?,
                            reason: ArsdkStreamDisconnectionReason) {
        var error: StreamingError?
        let state: StreamingState? = {
            switch event {
            case .start:
                streamStarted = true
                monitors.forEach { monitor in monitor.serviceDidStart() }
                return .started
            case .stop:
                switch status {
                case -EFAULT:
                    error = .invalidUrl
                case ..<0:
                    error = .unknown
                default:
                    break
                }
                return .stopped
            case .begin:
                return .streaming
            case .end:
                error = StreamingError(fromArsdk: reason)
                return streamStarted ? .started : nil
            case .connecting:
                return .connecting
            case .error:
                error = StreamingError(fromArsdk: reason)
                return .error
            @unknown default:
                return nil
            }
        }()

        guard let state = state else { return }

        monitors.forEach { monitor in
            monitor.streamingStateDidChange(state, error, url.flatMap { URL(string: $0) })
        }
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension StreamSharingResolution: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<StreamSharingResolution, ArsdkStreamResolution>([
        .res1080p: .resolution1080p,
        .res720p: .resolution720p,
        .res480p: .resolution480p,
        .res360p: .resolution360p,
        .res240p: .resolution240p])
}

/// Extension that adds conversion from/to arsdk enum.
extension StreamSharingRtspTransport: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<StreamSharingRtspTransport, ArsdkStreamRtspTransport>([
        .udp: .udp,
        .tcp: .tcp])
}

/// Extension that adds conversion from/to arsdk enum.
extension OverlayUnitSystem: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<OverlayUnitSystem, ArsdkStreamUnitSystem>([
        .metric: .metric,
        .imperial: .imperial,
        .aviation: .aviation])
}

/// Extension that adds conversion from/to arsdk enum.
extension OverlayCoordinateSystem: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<OverlayCoordinateSystem, ArsdkStreamCoordinateSystem>([
        .dms: .dms,
        .dd: .dd,
        .mgrs: .mgrs,
        .utm: .utm,
        .sk42: .sk42])
}

/// Extension that adds conversion from/to arsdk enum.
extension StreamingError: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<StreamingError, ArsdkStreamDisconnectionReason>([
        .unknown: .unknown,
        .clientRequest: .clientRequest,
        .serverRequest: .serverRequest,
        .networkError: .networkError,
        .refused: .refused,
        .alreadyInUse: .alreadyInUse,
        .timeout: .timeout,
        .internalError: .internalError])
}

/// Extension that adds conversion from/to arsdk enum
extension StreamRecordingStopReason: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<StreamRecordingStopReason, ArsdkStreamRecordStopReason>([
        .unknown: .unknown,
        .userRequest: .userRequest,
        .aborted: .aborted,
        .peerShutdown: .peerShutdown,
        .newSessionRestart: .newSessionRestart,
        .internalRestart: .internalRestart,
        .noSpaceLeft: .noSpaceLeft,
        .internalError: .internalError
    ])
}
