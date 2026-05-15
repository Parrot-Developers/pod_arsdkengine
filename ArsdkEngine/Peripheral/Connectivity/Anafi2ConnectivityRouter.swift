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

/// Common base for radio component controllers.
protocol RadioComponentController {

    /// Drone is disconnected.
    func didDisconnect()

    /// Processes `State` event.
    ///
    /// - Parameter state: received state
    func processStateEvent(state: Arsdk_Connectivity_Event.State)

    /// Processes `System` event
    ///
    /// - Parameter state: received state
    func processSystemEvent(state: Arsdk_System_Event.State)
}

/// Connectivity router for Anafi 2 family drones.
///
/// This controller monitors the remote device's radios and publish their setup/configuration APIs, such as
/// `WifiAccessPoint`, `WifiStation`, etc.
class Anafi2ConnectivityRouter: DeviceComponentController {

    /// Decoder for connectivity events.
    private var connectivityDecoder: ArsdkConnectivityEventDecoder!

    /// Decoder for system connectivity
    private var systemDecoder: ArsdkSystemEventDecoder!

    /// Known radio types, by radio identifier.
    private var radios: [UInt32: Arsdk_Connectivity_RadioType] = [:]

    /// Radio controllers, by radio identifier.
    private var radioControllers: [UInt32: [any RadioComponentController]] = [:]

    /// Keep the system state if there is no radioController when it is received, and process it when a connectivity
    /// event is received.
    private var systemState: Arsdk_System_Event.State?

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        connectivityDecoder = ArsdkConnectivityEventDecoder(listener: self)
        systemDecoder = ArsdkSystemEventDecoder(listener: self)
    }

    override func willConnect() {
        systemState = nil
        _ = sendListRadiosCommand()
    }

    override func didDisconnect() {
        radios.removeAll()
        for controller in radioControllers.values.flatMap({ $0 }) {
            controller.didDisconnect()
        }
        radioControllers.removeAll()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        connectivityDecoder.decode(command)
        systemDecoder.decode(command)
    }
}

/// Command delegates implementation of all radio components.
extension Anafi2ConnectivityRouter: WifiAccessPointCommandDelegate, WifiStationCommandDelegate,
                                    WifiScannerCommandDelegate, MarsMasterCommandDelegate,
                                    MarsSlaveCommandDelegate {

    func set(radioId: UInt32, mode: Arsdk_Connectivity_Mode) -> Bool {
        var setMode = Arsdk_Connectivity_Command.SetMode()
        setMode.radioID = radioId
        setMode.mode = mode
        return sendConnectivityCommand(.setMode(setMode))
    }

    func configure(radioId: UInt32, config: Arsdk_Connectivity_AccessPointConfig) -> Bool {
        var configure = Arsdk_Connectivity_Command.Configure()
        configure.radioID = radioId
        configure.mode = .accessPointConfig(config)
        return sendConnectivityCommand(.configure(configure))
    }

    func configure(radioId: UInt32, config: Arsdk_Connectivity_StationConfig) -> Bool {
        var configure = Arsdk_Connectivity_Command.Configure()
        configure.radioID = radioId
        configure.mode = .stationConfig(config)
        return sendConnectivityCommand(.configure(configure))
    }

    func scan(radioId: UInt32) -> Bool {
        var scan = Arsdk_Connectivity_Command.Scan()
        scan.radioID = radioId
        return sendConnectivityCommand(.scan(scan))
    }
}

/// Extension for methods to send connectivity commands.
extension Anafi2ConnectivityRouter {

    /// Sends to the drone a connectivity command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendConnectivityCommand(_ command: Arsdk_Connectivity_Command.OneOf_ID) -> Bool {
        if deviceController.backend != nil,
           let encoder = ArsdkConnectivityCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends `ListRadios` command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendListRadiosCommand() -> Bool {
        return sendConnectivityCommand(.listRadios(Arsdk_Connectivity_Command.ListRadios()))
    }

    /// Sends `GetState` command.
    ///
    /// - Parameter radioId: radio identifier
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand(radioId: UInt32) -> Bool {
        var getState = Arsdk_Connectivity_Command.GetState()
        getState.radioID = radioId
        getState.includeDefaultCapabilities = true
        getState.supportsPackedChannels = true
        return sendConnectivityCommand(.getState(getState))
    }
}

/// Extension for events processing.
extension Anafi2ConnectivityRouter: ArsdkConnectivityEventDecoderListener {

    func onRadioList(_ radioList: Arsdk_Connectivity_Event.RadioList) {
        guard radios.isEmpty else {
            ULog.e(.connectivityTag, "Ignoring unsolicited radio list")
            return
        }

        radios = radioList.radios
        for radiosId in radioList.radios.keys {
            _ = sendGetStateCommand(radioId: radiosId)
        }
    }

    func onState(_ state: Arsdk_Connectivity_Event.State) {

        guard let radioType = radios[state.radioID] else {
            ULog.e(.connectivityTag, "Ignoring unknown radio [id: \(state.radioID)]")
            return
        }

        if state.hasDefaultCapabilities {
            if radioControllers.keys.contains(state.radioID) {
                ULog.e(.connectivityTag, "Ignoring unsolicited default capabilities")
            } else if radioType == .wifi {
                var controllers = [any RadioComponentController]()
                if state.defaultCapabilities.supportedModes.contains(.ap) {
                    controllers.append(WifiAccessPointController(store: deviceController.device.peripheralStore,
                                                                 utilities: deviceController.engine.utilities,
                                                                 delegate: self, radioId: state.radioID))
                }
                if state.defaultCapabilities.supportedModes.contains(.sta) {
                    controllers.append(WifiStationController(store: deviceController.device.peripheralStore,
                                                             utilities: deviceController.engine.utilities,
                                                             delegate: self, radioId: state.radioID))
                }
                controllers.append(WifiScannerController(store: deviceController.device.peripheralStore,
                                                         delegate: self, radioId: state.radioID))
                radioControllers[state.radioID] = controllers
            } else if radioType == .mars {
                var controllers = [any RadioComponentController]()
                if state.defaultCapabilities.supportedModes.contains(.ap) {
                    controllers.append(MarsMasterController(store: deviceController.device.peripheralStore,
                                                                utilities: deviceController.engine.utilities,
                                                                delegate: self, radioId: state.radioID))
                }
                if state.defaultCapabilities.supportedModes.contains(.sta) {
                    controllers.append(MarsSlaveController(store: deviceController.device.peripheralStore,
                                                               utilities: deviceController.engine.utilities,
                                                               delegate: self, radioId: state.radioID))
                }
                radioControllers[state.radioID] = controllers
            }
        }

        radioControllers[state.radioID]?.forEach {
            $0.processStateEvent(state: state)
            if let systemState {
                $0.processSystemEvent(state: systemState)
            }
        }
        systemState = nil
    }

    func onConnection(_ connection: Arsdk_Connectivity_Event.Connection) {

    }

    func onScanResult(_ scanResult: Arsdk_Connectivity_Event.ScanResult) {
        radioControllers[scanResult.radioID]?.forEach {
            if let controller = $0 as? WifiScannerController {
                controller.processScanResult(scanResult: scanResult)
            }
        }
    }
}

/// Extension for events processing.
extension Anafi2ConnectivityRouter: ArsdkSystemEventDecoderListener {
    func onState(_ state: Arsdk_System_Event.State) {
        if radioControllers.isEmpty {
            systemState = state
        } else {
            radioControllers.values.flatMap { $0 }.forEach { $0.processSystemEvent(state: state) }
        }
    }
}
