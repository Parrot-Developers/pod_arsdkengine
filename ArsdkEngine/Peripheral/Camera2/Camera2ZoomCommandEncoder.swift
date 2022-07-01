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

/// Camera2 zoom control command encoder.
class Camera2ZoomCommandEncoder: NoAckCmdEncoder {

    let type = ArsdkNoAckCmdType.cameraZoom

    /// Max number of times the command should be sent with the same value.
    let maxRepeatedSent = 10

    /// Queue used to dispatch messages on it in order to ensure synchronization between main queue and pomp
    /// loop. All synchronized variables of this object must be accessed (read and write) in this queue
    private let queue = DispatchQueue(label: "com.parrot.arsdkengine.camera2.zoom.encoder")

    // synchronized vars
    /// Desired control mode.
    private var desiredControlMode = Arsdk_Camera_ZoomControlMode.level
    /// Desired target.
    private var desiredTarget: Double = 1.0
    /// Whether ongoing zoom control commands are cancelled.
    private var controlCancelled = false

    // pomp loop only vars
    /// Latest control mode sent to drone.
    private var latestControlMode = Arsdk_Camera_ZoomControlMode.level
    /// Latest target sent to drone.
    private var latestTarget: Double = 1.0

    /// Number of times the same command has been sent.
    private var sentCnt = -1

    var encoder: () -> (ArsdkCommandEncoder?) {
        return encoderBlock
    }

    /// Encoder of the current piloting command that should be sent to the device.
    private var encoderBlock: (() -> (ArsdkCommandEncoder?))!

    /// Constructor.
    ///
    /// - Parameters:
    ///    - cameraId: camera identifier
    init(cameraId: UInt64) {
        encoderBlock = { [unowned self] in
            // Note: this code will be called in the pomp loop

            var encoderControlMode = Arsdk_Camera_ZoomControlMode.level
            var encoderTarget: Double = 0.0
            var cancelled = false
            // set the local var in a synchronized queue
            queue.sync {
                encoderControlMode = desiredControlMode
                encoderTarget = desiredTarget
                cancelled = controlCancelled
            }

            if cancelled {
                latestControlMode = .level
                latestTarget = 1
                return nil
            }

            // if control has changed or target has changed
            if latestControlMode != encoderControlMode ||
                latestTarget != encoderTarget {

                latestControlMode = encoderControlMode
                latestTarget = encoderTarget
                sentCnt = maxRepeatedSent
            }

            // only decrement the counter if the control is in level,
            // or, if the control is in velocity and target is zero
            if encoderControlMode == .level || encoderTarget == 0.0 {
                sentCnt -= 1
            }

            if sentCnt >= 0 {
                var zoomCommand = Arsdk_Camera_Command.SetZoomTarget()
                zoomCommand.cameraID = cameraId
                zoomCommand.controlMode = encoderControlMode
                zoomCommand.target = encoderTarget
                var cameraCommand = Arsdk_Camera_Command()
                cameraCommand.id = .setZoomTarget(zoomCommand)
                if let payload = try? cameraCommand.serializedData() {
                    return ArsdkFeatureGeneric.customCmdNonAckEncoder(serviceId: ArsdkCameraCommandEncoder.serviceId,
                                                                      msgNum: UInt(cameraCommand.id!.number),
                                                                      payload: payload)
                }
            }
            return nil
        }
    }

    /// Controls the zoom.
    ///
    /// - Parameters:
    ///   - mode: control mode to send
    ///   - target: target to send
    func control(mode: Camera2ZoomControlMode, target: Double) {
        queue.sync {
            controlCancelled = false
            desiredControlMode = mode.arsdkValue!
            desiredTarget = target
        }
    }

    /// Cancels ongoing zoom control commands, if any.
    func cancelControl() {
        queue.sync {
            controlCancelled = true
        }
    }
}
