// Copyright (C) 2026 Parrot Drones SAS
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

/// Base controller for vehicle peripheral
class VehicleController: DeviceComponentController, VehicleBackend {
    /// Vehicle component
    private var vehicle: VehicleCore!

    /// Decoder for vehicle events.
    private var arsdkVehicleDecoder: ArsdkVehicleEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        vehicle = VehicleCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkVehicleDecoder = ArsdkVehicleEventDecoder(listener: self)
    }

    /// Drone will connect
    override func willConnect() {
        _ = sendGetStateCommand()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        vehicle.update(missingRequirements: Set())
            .update(improvements: Set())
            .update(preciseCalibration: false)
            .update(relativeGuidance: false)
            .update(isRelativeGuidanceModifiable: false)
            .update(activation: false)
            .update(notifications: Set())
            .update(maxHorizontalDistance: 0.0)
            .update(platformType: .land)
        vehicle.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkVehicleDecoder.decode(command)
    }
}

extension VehicleController {

    func enable(value: Bool) -> Bool {
        return sendEnableCommand(value: value)
    }

    func enable(relativeGuidance: Bool) -> Bool {
        return sendRelativeGuidanceCommand(value: relativeGuidance)
    }

    func enable(preciseCalibration: Bool) -> Bool {
        return sendPreciseCalibrationCommand(value: preciseCalibration)
    }

    func wipePreciseCalibration() -> Bool {
        return sendWipePreciseCalibration()
    }

    func set(platformType: VehiclePlatformType) -> Bool {
        if let platformType = platformType.arsdkValue {
            return sendPlatformTypeCommand(value: platformType)
        }
        return false
    }
}

extension VehicleController {
    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Vehicle_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendVehicleCommand(.getState(getState))
    }

    /// Sends enable vehicle command.
    ///
    /// - Parameter value: `true` to enable vehicle, `false` otherwise
    /// - Returns: `true` if the command has been sent
    func sendEnableCommand(value: Bool) -> Bool {
        var enable = Arsdk_Vehicle_Command.Enable()
        enable.value = value
        return sendVehicleCommand(.enable(enable))
    }

    /// Sends enable relative guidance command.
    ///
    /// - Parameter value: the relative guidance value
    /// - Returns: `true` if the command has been sent
    func sendRelativeGuidanceCommand(value: Bool) -> Bool {
        var enableRelativeGuidance = Arsdk_Vehicle_Command.EnableRelativeGuidance()
        enableRelativeGuidance.value = value
        return sendVehicleCommand(.enableRelativeGuidance(enableRelativeGuidance))
    }

    /// Sends enable precise calibration command.
    ///
    /// - Parameter value: the enable precise calibration value
    /// - Returns: `true` if the command has been sent
    func sendPreciseCalibrationCommand(value: Bool) -> Bool {
        var enablePreciseCalibration = Arsdk_Vehicle_Command.EnablePreciseCalibration()
        enablePreciseCalibration.value = value
        return sendVehicleCommand(.enablePreciseCalibration(enablePreciseCalibration))
    }

    /// Sends wipe precise calibration command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendWipePreciseCalibration() -> Bool {
        return sendVehicleCommand(.wipePreciseCalibration(Google_Protobuf_Empty()))
    }

    /// Sends set platform type command.
    ///
    /// - Parameter value: the platform type value
    /// - Returns: `true` if the command has been sent
    func sendPlatformTypeCommand(value: Arsdk_Vehicle_PlatformType) -> Bool {
        var setPlatformType = Arsdk_Vehicle_Command.SetPlatformType()
        setPlatformType.value = value
        return sendVehicleCommand(.setPlateformType(setPlatformType))
    }

    /// Sends to the drone a Vehicle command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendVehicleCommand(_ command: Arsdk_Vehicle_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkVehicleCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Vehicle decode callback implementation
extension VehicleController: ArsdkVehicleEventDecoderListener {
    func onState(_ state: Arsdk_Vehicle_Event.State) {
        if state.hasDefaultCapabilities {
            vehicle.update(maxHorizontalDistance: state.defaultCapabilities.maxHorizontalDistance)
            let platformTypesSupported = state.defaultCapabilities
                .supportedPlatformTypes.compactMap { VehiclePlatformType(fromArsdk: $0) }
            vehicle.update(supportedPlatformTypes: Set(platformTypesSupported))
        }
        if state.hasIsEnabled {
            vehicle.update(activation: state.isEnabled.value)
        }
        if state.hasRelativeGuidance {
            vehicle.update(relativeGuidance: state.relativeGuidance.isEnabled)
            vehicle.update(isRelativeGuidanceModifiable: state.relativeGuidance.isModifiable)
        }
        if state.hasIsPreciseCalibrationEnabled {
            vehicle.update(preciseCalibration: state.isPreciseCalibrationEnabled.value)
        }
        if state.hasMissingRequirements {
            let missingRequirements = state.missingRequirements.requirements
                .compactMap { VehicleRequirement(fromArsdk: $0) }
            vehicle.update(missingRequirements: Set(missingRequirements))
        }
        if state.hasImprovements {
            let improvements = state.improvements.improvements.compactMap { VehicleImprovement(fromArsdk: $0) }
            vehicle.update(improvements: Set(improvements))
        }
        if state.hasNotifications {
            let notifications = state.notifications.notifications.compactMap { VehicleNotification(fromArsdk: $0) }
            vehicle.update(notifications: Set(notifications))
        }
        if state.hasPlatformType, let type = VehiclePlatformType(fromArsdk: state.platformType.value) {
            vehicle.update(platformType: type)
        }
        vehicle.publish()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension VehiclePlatformType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VehiclePlatformType, Arsdk_Vehicle_PlatformType>([
        .land: .land,
        .water: .water
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension VehicleRequirement: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VehicleRequirement, Arsdk_Vehicle_Requirement>([
        .droneGNSS: .droneGnss,
        .controllerGNSS: .controllerGnss,
        .trustedGNSS: .trustedGnss
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension VehicleImprovement: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VehicleImprovement, Arsdk_Vehicle_Improvement>([
        .droneGNSS: .droneGnss,
        .controllerGNSS: .controllerGnss,
        .trustedGNSS: .trustedGnss,
        .lowVehicleSpeed: .lowVehicleSpeed
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension VehicleNotification: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VehicleNotification, Arsdk_Vehicle_Notification>([
        .computerVisionUsed: .computerVisionUsed,
        .rtvComputerVisionSearching: .rtvComputerVisionSearching,
        .landingComputerVisionSearching: .landingComputerVisionSearching,
        .landingVehicleNotFound: .landingVehicleNotFound,
        .landingZoneNotFound: .landingZoneNotFound
    ])
}
