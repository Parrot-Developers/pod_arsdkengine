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

/// FlightPlan uploader specific part
protocol ArsdkFlightplanUploader: AnyObject {
    /// Configure the uploader
    ///
    /// - Parameter flightPlanPilotingItfController: the FPPilotingItfController
    func configure(flightPlanPilotingItfController: FlightPlanPilotingItfController)
    /// Reset the uploader
    ///
    func reset()
    /// Upload a given flight plan file on the drone.
    ///
    /// - Parameters:
    ///   - filepath: local path of the flight plan file
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: true or false if the upload is done with success
    ///   - flightPlanUid: uid of the flightplan returned by the drone
    /// - Returns: a request that can be canceled
    func uploadFlightPlan(filepath: String,
                          completion: @escaping (_ success: Bool, _ flightPlanUid: String?) -> Void) -> CancelableCore?
}

/// Return home piloting interface component controller class - with connexion through http
class HttpFlightPlanPilotingItfController: FlightPlanPilotingItfController {
    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController, uploader: HttpFlightPlanUploader())
    }
}

/// Return home piloting interface component controller base class
class FlightPlanPilotingItfController: ActivablePilotingItfController {

    /// Flight plan directory on the drone
    static let remoteFlightPlanDir = "/"

    /// The piloting interface from which this object is the backend
    private var flightPlanPilotingItf: FlightPlanPilotingItfCore {
        return pilotingItf as! FlightPlanPilotingItfCore
    }

    /// Current remote uid of the Flight Plan file uploaded
    /// (can be a filePath if the drone supports ftp upload, or an unique id of the flight plan if the drone supports
    /// upload via http (REST API))
    private var remoteFlightPlanUid: String? {
        didSet {
            if remoteFlightPlanUid != oldValue {
                flightPlanPilotingItf.update(flightPlanFileIsKnown: remoteFlightPlanUid != nil)
            }
        }
    }

    /// Whether or not the flight plan is available on the drone
    private var flightPlanAvailable = false
    /// Whether a flight plan is currently playing.
    private var isPlaying = false
    /// Whether the flight plan should be restarted instead of resumed when the piloting interface can be activated
    private var shouldRestartFlightPlan = false
    /// Mission item where the flight plan should start.
    private var startAtMissionItem: UInt?
    /// The disconnection policy to use.
    private var disconnectionPolicy: FlightPlanDisconnectionPolicy = .returnToHome

    /// Unavailability reasons of the drone.
    private var droneUnavailabilityReasons = Set<FlightPlanUnavailabilityReason>()
    /// Whether the flight plan is currently stopped
    private var isStopped = false
    /// Path of the file to upload.
    ///
    /// Used when the upload has to be delayed because we wait for the current flight plan to be paused.
    private var flightPlanPathToUpload: String?
    /// Flight plan type.
    private var flightPlanInterpreter: FlightPlanInterpreter = .legacy
    /// Custom flight plan id
    private var customFlightPlanId: String = ""
    /// True if an upload is requested. If True the PilotingItf will be unavailable
    private var uploadFpRequested = false
    /// Delegate to upload the FlightPlan
    private var uploader: ArsdkFlightplanUploader

    /// The current upload cancellable.
    private var currentUpload: CancelableCore?

    fileprivate init(activationController: PilotingItfActivationController, uploader: ArsdkFlightplanUploader) {
        self.uploader = uploader
        super.init(activationController: activationController, sendsPilotingCommands: false)
        pilotingItf = FlightPlanPilotingItfCore(
            store: droneController.drone.pilotingItfStore, backend: self)
        // by default, flight plan file is missing
        updateUnavailabilityReasons()
    }

    override func requestActivation() {
        if shouldRestartFlightPlan && flightPlanPilotingItf.isPaused {
            sendStopFlightPlan()
        } else {
            shouldRestartFlightPlan = false
            sendStartFlightPlan()
        }
    }

    override func requestDeactivation() {
        sendPauseFlightPlan()
    }

    /// Drone is connected
    override func didConnect() {
        uploader.configure(flightPlanPilotingItfController: self)
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        uploader.reset()
        pilotingItf.unpublish()
        flightPlanInterpreter = .legacy
        startAtMissionItem = nil
        disconnectionPolicy = .returnToHome
        uploadFpRequested = false

        // reset values that does not have a meaning while disconnected
        flightPlanPilotingItf.update(isPaused: false).update(flightPlanFileIsKnown: false)
            .update(latestUploadState: .none).update(latestActivationError: .none)
            .update(activateAtMissionItemSupported: false)
            .update(activateAtMissionItemV2Supported: false)
            .update(recoveryInfo: nil).update(flightPlanId: nil)
            .notifyUpdated()

        // super will call notifyUpdated
        super.didDisconnect()
    }

    /// Modifies the internal list of drone unavailability reasons
    ///
    /// - Parameters:
    ///   - reason: the reason
    ///   - isPresent: whether the reason is active or not
    private func modifyDroneUnavailabilityReasons(reason: FlightPlanUnavailabilityReason, isPresent: Bool) {
        if isPresent {
            droneUnavailabilityReasons.insert(reason)
        } else {
            droneUnavailabilityReasons.remove(reason)
        }
    }

    /// Updates the unavailability reasons of the controlled piloting interface
    /// - Note: caller is responsible to call the `notifiyUpdated()` function.
    private func updateUnavailabilityReasons() {
        var reasons: Set<FlightPlanUnavailabilityReason> = []
        if (remoteFlightPlanUid == nil && !isPlaying) || uploadFpRequested {
            reasons.insert(.missingFlightPlanFile)
        }
        if !flightPlanAvailable {
            reasons.formUnion(droneUnavailabilityReasons)
        }
        flightPlanPilotingItf.update(unavailabilityReasons: reasons)
    }

    /// Updates whether the file is known on the controlled piloting interface.
    ///
    /// - Parameters:
    ///   - playingState: current flight plan playing state
    ///   - playedFile: current played flight plan name
    private func updateFileIsKnown(
        playingState: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState, playedFile: String) {

            switch playingState {
            case .playing, .paused, .stopped:
                switch uploader {
                case is FtpFlightPlanUploader:
                    if let remoteFilepath = remoteFlightPlanUid, !playedFile.hasSuffix(remoteFilepath) {
                        remoteFlightPlanUid = nil
                    }
                case is HttpFlightPlanUploader :
                    if playedFile != remoteFlightPlanUid {
                        remoteFlightPlanUid = nil
                    }
                    flightPlanPilotingItf.update(flightPlanFileIsKnown: remoteFlightPlanUid != nil)
                default:
                    break
                }
            default:
                break
            }
        }

    /// Update the local availability of the flight plan
    func updateAvailability() {
        if !isPlaying {
            if (remoteFlightPlanUid != nil || flightPlanPathToUpload != nil) && flightPlanAvailable
                && !uploadFpRequested {
                notifyIdle()
            } else {
                notifyUnavailable()
            }
        }
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonFlightplanstateUid {
            ArsdkFeatureCommonFlightplanstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonMavlinkstateUid {
            ArsdkFeatureCommonMavlinkstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureFlightPlanUid {
            ArsdkFeatureFlightPlan.decode(command, callback: self)
        }
    }
}

// MARK: - FlightPlanPilotingItfBackend
/// Extension of FlightPlanPilotingItfController that implements FlightPlanPilotingItfBackend
extension FlightPlanPilotingItfController: FlightPlanPilotingItfBackend {
    func activate(restart: Bool, interpreter: FlightPlanInterpreter, missionItem: UInt?,
                  disconnectionPolicy: FlightPlanDisconnectionPolicy) -> Bool {
        flightPlanInterpreter = interpreter
        shouldRestartFlightPlan = restart
        startAtMissionItem = missionItem
        self.disconnectionPolicy = disconnectionPolicy
        flightPlanPilotingItf.update(latestActivationError: .none).notifyUpdated()
        return droneController.pilotingItfActivationController.activate(pilotingItf: self)
    }

    func stop() -> Bool {
        if connected {
            sendStopFlightPlan()
            return true
        }
        return false
    }

    func uploadFlightPlan(filepath: String, customFlightPlanId: String) {
        self.uploadFpRequested = true
        updateUnavailabilityReasons()
        self.customFlightPlanId = customFlightPlanId
        flightPlanPilotingItf.update(latestUploadState: .uploading)
            .update(latestMissionItemExecuted: nil)
            .update(latestMissionItemSkipped: nil)
        if flightPlanPilotingItf.state != .unavailable {
            notifyUnavailable()
        }
        self.flightPlanPilotingItf.notifyUpdated()

        if !isStopped {
            // stop current flightplan, if any, before uploading the file
            flightPlanPathToUpload = filepath
            sendStopFlightPlan()
        } else {
            flightPlanPathToUpload = nil

            // cancel any previous ongoing upload
            currentUpload?.cancel()
            var uploadHandle: CancelableCore?
            // uses the ftp or http uploader
            uploadHandle = uploader.uploadFlightPlan(filepath: filepath) { [weak self] success, flightPlanUid in
                if let `self` = self {
                    self.uploadFpRequested = false
                    self.currentUpload = nil
                    // if the upload was cancelled then do not update state there should be no
                    // state handling and the completion should be ignored.
                    if let cancellableCoreTask = uploadHandle as? CancelableTaskCore,
                       cancellableCoreTask.canceled {
                        return
                    }

                    if success {
                        self.remoteFlightPlanUid = flightPlanUid
                    } else {
                        self.remoteFlightPlanUid = nil
                    }

                    self.flightPlanPilotingItf.update(latestUploadState: success ? .uploaded : .failed)
                        .update(isPaused: false)
                        .update(flightPlanId: self.remoteFlightPlanUid)
                    self.updateUnavailabilityReasons()

                    if self.canDeactivate {
                        self.requestDeactivation()
                    } else {
                        self.updateAvailability()
                    }
                    self.flightPlanPilotingItf.notifyUpdated()
                }
            }
            currentUpload = uploadHandle
        }
    }

    func cancelPendingUpload() {
        currentUpload?.cancel()
        uploadFpRequested = false
        currentUpload = nil
        flightPlanPilotingItf.update(latestUploadState: .none).notifyUpdated()
    }

    func clearRecoveryInfo() {
        sendClearRecoveryInfo()
        flightPlanPilotingItf.update(recoveryInfo: nil)
            .notifyUpdated()
    }

    func cleanBeforeRecovery(customId: String, resourceId: String,
                             completion: @escaping (CleanBeforeRecoveryResult) -> Void) -> CancelableCore? {
        guard let droneServer = deviceController.droneServer else {
            completion(.failed)
            return nil
        }
        let mediaRestApi = MediaRestApi(server: droneServer)
        return mediaRestApi.deleteResources(customId: customId,
                                            firstResourceId: resourceId) { success, canceled in
            if canceled {
                completion(.canceled)
            } else {
                completion(success ? .success : .failed)
            }
        }
    }
}

// MARK: - Send Commands
/// Extension of FlightPlanPilotingItfController for commands
extension FlightPlanPilotingItfController {
    /// Sends command to start flight plan.
    private func sendStartFlightPlan() {
        if flightPlanPilotingItf.activateAtMissionItemV2Supported,
           let missionItem = startAtMissionItem {
            let type: ArsdkFeatureFlightPlanMavlinkType = flightPlanInterpreter == .legacy
            ? .flightplan
            : .flightplanv2
            let continueOnDisconnect: UInt = disconnectionPolicy == .returnToHome ? 0 : 1
            sendCommand(ArsdkFeatureFlightPlan.startAtV2Encoder(flightplanId: remoteFlightPlanUid,
                                                                customId: customFlightPlanId,
                                                                type: type,
                                                                item: missionItem,
                                                                continueOnDisconnect:
                                                                    continueOnDisconnect))
        } else if let missionItem = startAtMissionItem {
            let type: ArsdkFeatureFlightPlanMavlinkType = flightPlanInterpreter == .legacy
            ? .flightplan
            : .flightplanv2
            sendCommand(ArsdkFeatureFlightPlan.startAtEncoder(flightplanId: remoteFlightPlanUid,
                                                              customId: customFlightPlanId,
                                                              type: type, item: missionItem))
        } else {
            let type: ArsdkFeatureCommonMavlinkStartType =
            flightPlanInterpreter == .legacy ? .flightplan : .flightplanv2
            sendCommand(ArsdkFeatureCommonMavlink.startEncoder(filepath: remoteFlightPlanUid,
                                                               type: type))
        }
    }

    /// Sends command to pause flight plan.
    private func sendPauseFlightPlan() {
        sendCommand(ArsdkFeatureCommonMavlink.pauseEncoder())
    }

    /// Sends command to stop flight plan.
    private func sendStopFlightPlan() {
        sendCommand(ArsdkFeatureCommonMavlink.stopEncoder())
    }

    /// Sends command to clear recovery information.
    private func sendClearRecoveryInfo() {
        sendCommand(ArsdkFeatureFlightPlan.clearRecoveryInfoEncoder())
    }
}

// MARK: - Receive Commands

extension FlightPlanPilotingItfController: ArsdkFeatureCommonFlightplanstateCallback {
    func onAvailabilityStateChanged(availabilitystate: UInt) {
        flightPlanAvailable = (availabilitystate == 1)
        updateUnavailabilityReasons()
        updateAvailability()
    }

    func onComponentStateListChanged(component: ArsdkFeatureCommonFlightplanstateComponentstatelistchangedComponent,
                                     state: UInt) {
        switch component {
        case .calibration:
            modifyDroneUnavailabilityReasons(reason: .droneNotCalibrated, isPresent: state == 0)
            updateUnavailabilityReasons()
        case .gps:
            modifyDroneUnavailabilityReasons(reason: .droneGpsInfoInaccurate, isPresent: state == 0)
            updateUnavailabilityReasons()
        case .takeoff:
            modifyDroneUnavailabilityReasons(reason: .cannotTakeOff, isPresent: state == 0)
            updateUnavailabilityReasons()
        case .mavlinkFile:
            if state == 0 {
                flightPlanPilotingItf.update(latestActivationError: .incorrectFlightPlanFile)
            } else if flightPlanPilotingItf.latestActivationError == .incorrectFlightPlanFile {
                flightPlanPilotingItf.update(latestActivationError: .none)
            }
        case .waypointsbeyondgeofence:
            if state == 0 {
                flightPlanPilotingItf.update(latestActivationError: .waypointBeyondGeofence)
            } else if flightPlanPilotingItf.latestActivationError == .waypointBeyondGeofence {
                flightPlanPilotingItf.update(latestActivationError: .none)
            }
        case .cameraavailable:
            modifyDroneUnavailabilityReasons(reason: .cameraUnavailable, isPresent: state == 0)
            updateUnavailabilityReasons()
        case .sdkCoreUnknown:
            break
        @unknown default:
            break
        }
        flightPlanPilotingItf.notifyUpdated()
    }
}

extension FlightPlanPilotingItfController: ArsdkFeatureCommonMavlinkstateCallback {
    func onMavlinkFilePlayingStateChanged(
        state: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedState,
        filepath: String!, type: ArsdkFeatureCommonMavlinkstateMavlinkfileplayingstatechangedType) {
            isPlaying = state == .playing
            updateFileIsKnown(playingState: state, playedFile: filepath)
            updateUnavailabilityReasons()
            flightPlanPilotingItf.update(flightPlanId: filepath == "" ? nil : filepath)

            switch state {
            case .playing:
                // clear the latest mission items executed and skipped if the previous state was
                // stopped
                if isStopped {
                    flightPlanPilotingItf.update(latestMissionItemExecuted: nil)
                        .update(latestMissionItemSkipped: nil)
                    isStopped = false
                }
                flightPlanPilotingItf.update(isPaused: false)
                notifyActive()

                // check if we have a recovery info available
                if let recoveryInfo = flightPlanPilotingItf.recoveryInfo {
                    // if so try to catch up with the state on the drone
                    catchUpActivePilotingItfIfNeeded(flightplanId: recoveryInfo.id,
                                                     customId: recoveryInfo.customId)
                }
            case .stopped:
                isStopped = true

                flightPlanPilotingItf.update(isPaused: false)
                updateAvailability()

                if shouldRestartFlightPlan {
                    shouldRestartFlightPlan = false
                    sendStartFlightPlan()
                    flightPlanPilotingItf.notifyUpdated()
                }

                // if a flight plan should be uploaded
                if let flightPlanPathToUpload = flightPlanPathToUpload {
                    uploadFlightPlan(filepath: flightPlanPathToUpload,
                                     customFlightPlanId: customFlightPlanId)
                }
            case .paused:
                isStopped = false

                // Only change the isPaused flag if there is no flight plan to upload
                if flightPlanPathToUpload == nil {
                    flightPlanPilotingItf.update(isPaused: true)
                }
                updateAvailability()

                // if a flight plan should be uploaded
                if let flightPlanPathToUpload = flightPlanPathToUpload {
                    uploadFlightPlan(filepath: flightPlanPathToUpload,
                                     customFlightPlanId: customFlightPlanId)
                }
            case .loaded:
                // This case is not handled because it is not supported by Anafi
                break
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                // don't change anything if value is unknown
                ULog.w(.tag, "Unknown mavlink state, skipping this event.")
                return
            }
        }

    func onMissionItemExecuted(idx: UInt) {
        if flightPlanPilotingItf.latestUploadState != .uploading {
            flightPlanPilotingItf.update(latestMissionItemExecuted: idx).notifyUpdated()
        }
    }
}

extension FlightPlanPilotingItfController: ArsdkFeatureFlightPlanCallback {
    func onInfo(missingInputsBitField: UInt) {
        droneUnavailabilityReasons = FlightPlanUnavailabilityReason
            .createSetFrom(bitField: missingInputsBitField)
        flightPlanAvailable = droneUnavailabilityReasons.isEmpty
        updateUnavailabilityReasons()
        updateAvailability()
        flightPlanPilotingItf.notifyUpdated()
    }

    func onRecoveryInfo(flightplanId: String!, customId: String!, item: UInt, runningTime: UInt,
                        resourceId: String!) {
        var flightPlanInfo: RecoveryInfo?
        if !flightplanId.isEmpty {
            flightPlanInfo = RecoveryInfo(id: flightplanId, customId: customId,
                                          latestMissionItemExecuted: item,
                                          runningTime: Double(runningTime),
                                          resourceId: resourceId)
        }
        flightPlanPilotingItf.update(recoveryInfo: flightPlanInfo)
            .notifyUpdated()

        // try to catch up with the state on the drone
        catchUpActivePilotingItfIfNeeded(flightplanId: flightplanId, customId: customId)
    }

    func onCapabilities(supportedCapabilitiesBitField: UInt) {
        let startAtSupported = ArsdkFeatureFlightPlanSupportedCapabilitiesBitField
            .isSet(.startAt, inBitField: supportedCapabilitiesBitField)
        flightPlanPilotingItf
            .update(activateAtMissionItemSupported: startAtSupported)
            .update(isUploadWithCustomIdSupported: startAtSupported)

        let startAtV2Supported = ArsdkFeatureFlightPlanSupportedCapabilitiesBitField
            .isSet(.startAtV2, inBitField: supportedCapabilitiesBitField)
        flightPlanPilotingItf
            .update(activateAtMissionItemV2Supported: startAtV2Supported)
            .update(isUploadWithCustomIdSupported: startAtV2Supported)

        flightPlanPilotingItf.notifyUpdated()
    }

    func onWaypointSkipped(item: UInt) {
        if flightPlanPilotingItf.latestUploadState != .uploading {
            flightPlanPilotingItf.update(latestMissionItemSkipped: item).notifyUpdated()
        }
    }
}

extension FlightPlanPilotingItfController {

    /// Should be called to update the local state when connecting to a drone that has an active
    /// flight plan piloting interface.
    ///
    /// - Parameters:
    ///   - flightplanId: the flight plan id to use for updating local state.
    ///   - customId: the custom id to use for updating local state.
    private func catchUpActivePilotingItfIfNeeded(flightplanId: String, customId: String) {
        // When the application is killed remoteFlightPlanUid & customFlightPlanId are cleared.
        // If there is an active flight plan piloting interface on the drone and remoteFlightPlanUid
        // is `nil` then this means that the app was probably killed/relaunched.
        //
        // When receiving recovery information from the drone and the itf is active then we can
        // update the local state of the controller.
        //
        // This makes the controller recover gracefully and act correctly upon a pause or end of
        // flight plan. With remoteFlightPlanUid == nil, if the controller is asked to pause, or the
        // flight plan arrives to its end, then instead of transitioning to idle it transitions to
        // unavailable.
        //
        // This catch up should only be done during the phase of connecting to the drone.
        if !connected, // if not connected, then we are in a connecting phase
           flightPlanPilotingItf.state == .active, remoteFlightPlanUid == nil {
            remoteFlightPlanUid = flightplanId
            customFlightPlanId = customId
        }
    }
}

extension FlightPlanUnavailabilityReason: ArsdkMappableEnum {

    /// Create set of poi issues from all values set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all poi issues set in bitField
    static func createSetFrom(bitField: UInt) -> Set<FlightPlanUnavailabilityReason> {
        var result = Set<FlightPlanUnavailabilityReason>()
        ArsdkFeatureFlightPlanIndicatorBitField.forAllSet(in: bitField) { arsdkValue in
            if let missing = FlightPlanUnavailabilityReason(fromArsdk: arsdkValue) {
                result.insert(missing)
            }
        }
        return result
    }
    static var arsdkMapper = Mapper<FlightPlanUnavailabilityReason, ArsdkFeatureFlightPlanIndicator>([
        .insufficientBattery: .droneBattery,
        .droneGpsInfoInaccurate: .droneGps,
        .droneNotCalibrated: .droneMagneto,
        .droneInvalidState: .droneState
    ])
}
