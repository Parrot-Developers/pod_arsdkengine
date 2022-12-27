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
import SdkCore
import GroundSdk

/// Base controller of stream sink.
public class SinkController: NSObject {

    /// Stream controller providing the sdkcoreStream.
    unowned let streamCtrl: StreamController

    /// Sdkcore stream powering this sink, `nil` if unavailable.
    weak var sdkcoreStream: ArsdkStream?

    /// `true` if close is close() is called else `false`.
    var closed = false

    /// Stream controller listener handle.
    private var streamCtrlListener: StreamController.ListenerHandle?

    /// Constructor
    ///
    /// - Parameter streamCtrl: the stream controller providing the sdkcoreStream.
    public init(streamCtrl: StreamController) {
        self.streamCtrl = streamCtrl
        super.init()
    }

    /// Closes the sink.
    public func close() {
        guard !closed else { return }
        closed = true

        if sdkcoreStream != nil {
            onSdkCoreStreamUnavailable()
        }
        // unregister listener
        streamCtrlListener = nil
    }

    /// Registers this sink controller as stream controller listener.
    func register() {
        streamCtrlListener = streamCtrl.register(streamWouldOpen: {},
                                                 sdkcoreStreamStateDidChange: sdkcoreStreamStateDidChange,
                                                 availableMediaDidChange: {})
        // call streamAvailable if the stream is already opened
        if streamCtrl.sdkcoreStream.state == .opened {
            onSdkCoreStreamAvailable(sdkCoreStream: streamCtrl.sdkcoreStream)
        }
    }

    /// Notifies that sdkcoreStream is available.
    ///
    /// - Parameter sdkCoreStream: the sdkCoreStream available.
    func onSdkCoreStreamAvailable(sdkCoreStream: ArsdkStream) {
        self.sdkcoreStream = sdkCoreStream
    }

    /// Notifies that sdkcoreStream is unavailable.
    func onSdkCoreStreamUnavailable() {
        sdkcoreStream = nil
    }

    /// Called on the Sdkcore stream state change.
    ///
    /// - Parameter state: new Sdkcore stream state.
    public func sdkcoreStreamStateDidChange(state: ArsdkStreamState) {
        switch state {
        case .opened:
            let stream = streamCtrl.sdkcoreStream
            onSdkCoreStreamAvailable(sdkCoreStream: stream)
        case .closing:
            onSdkCoreStreamUnavailable()
        default:
            break
        }
    }
}
