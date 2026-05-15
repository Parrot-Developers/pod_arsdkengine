// Copyright (C) 2023 Parrot Drones SAS
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

/// Backup link component controller for SkyController remote controls.
class BackupLinkController: DeviceComponentController {

    /// Backup link component
    private var backupLink: BackupLinkCore!

    /// Decoder for backup link controller events.
    private var arsdkDecoder: ArsdkControllerbackuplinkEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        backupLink = BackupLinkCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = ArsdkControllerbackuplinkEventDecoder(listener: self)
    }

    override func willConnect() {
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        backupLink.cancelSettingsRollback()
        backupLink.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Backup link backend implementation.
extension BackupLinkController: BackupLinkBackend {
    func set(radioConfiguration: RadioConfiguration) -> Bool {
        var sent = false
        if connected {
            var configure = Arsdk_Controllerbackuplink_Command.Configure()
            configure.config.enabledLinks.value = radioConfiguration.arsdkValue!
            sent = sendControllerBackupLinkCommand(.configure(configure))
        }
        return sent
    }

    func select(frequency: Int) -> Bool {
        var sent = false
        if connected {
            var configure = Arsdk_Controllerbackuplink_Command.Configure()
            configure.config.frequency.value = UInt32(frequency)
            sent = sendControllerBackupLinkCommand(.configure(configure))
        }
        return sent
    }

    func autoSelectFrequency() -> Bool {
        return select(frequency: 0)
    }
}

/// Extension for methods to send controller backup link commands.
extension BackupLinkController {
    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Controllerbackuplink_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendControllerBackupLinkCommand(.getState(getState))
    }

    /// Sends to the remote control a state command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendControllerBackupLinkCommand(_ command: Arsdk_Controllerbackuplink_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkControllerbackuplinkCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension for events processing.
extension BackupLinkController: ArsdkControllerbackuplinkEventDecoderListener {
    func onState(_ state: Arsdk_Controllerbackuplink_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            switch state.defaultCapabilities.frequencySelectionMode {
            case .supportedFrequencies(let frequencies):
                backupLink.update(availableFrequencies:
                        .frequencyList(frequencies: Set(frequencies.frequencies.map { Int($0) })))
            case .supportedBands(let bands):
                backupLink.update(availableFrequencies:
                        .bandList(bands: Set(bands.bands.map { Int($0.minFrequency)...Int($0.maxFrequency) })))
            case .none:
                break
            }
        }

        // state
        if state.hasLinkInfo {
            switch state.linkInfo.state {
            case .off:
                backupLink.update(state: .unsettled)
            case .established:
                backupLink.update(state: .established)
            case .active:
                backupLink.update(
                    state: .active(rxActivity: state.linkInfo.rxActive, txActivity: state.linkInfo.txActive))
            default:
                break
            }
        }

        // config
        if state.hasConfig {
            if state.config.hasEnabledLinks {
                backupLink.update(radioConfiguration: state.config.enabledLinks.value.gsdk)
            }
            if state.config.hasFrequency {
                backupLink.update(frequency: Int(state.config.frequency.value))
            }
        }

        backupLink.publish()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension RadioConfiguration: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<RadioConfiguration, Arsdk_Backuplink_EnabledLinks>([
        .all: .all,
        .backupOnly: .backupOnly,
        .silent: .none])
}

extension Arsdk_Backuplink_EnabledLinks {
    var gsdk: RadioConfiguration {
        RadioConfiguration.arsdkMapper.reverseMap(from: self)!
    }
}
