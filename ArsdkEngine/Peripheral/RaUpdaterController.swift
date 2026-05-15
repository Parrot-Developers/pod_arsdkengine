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

/// Updater component controller for remote antennas.
class RaUpdaterController: UpdaterController {

    /// Decoder for remote antenna events.
    private var remoteAntennaDecoder: ArsdkRemoteantennaEventDecoder!

    /// Device tcp proxy
    private var proxy: ArsdkTcpProxy?

    /// The connected remote antenna.
    private var remoteAntenna: RCController.RemoteAntenna {
        (deviceController as! RCController).remoteAntenna
    }

    init(deviceController: RCController, config: Config,
         firmwareStore: FirmwareStoreCore, firmwareDownloader: FirmwareDownloaderCore) {

        super.init(desc: Peripherals.remoteAntennaUpdater, deviceController: deviceController, config: config,
                   firmwareStore: firmwareStore, firmwareDownloader: firmwareDownloader)

        remoteAntennaDecoder = ArsdkRemoteantennaEventDecoder(listener: self)
    }

    override func remoteAntennaDidConnect() {
        processFirmwareInfos()
        deviceDidConnect(deviceServer: remoteAntenna.deviceServer)
    }

    override func remoteAntennaDidDisconnect() {
        deviceDidDisconnect()

        if updateQueue.isEmpty {
            firmwareUpdater.unpublish()
        } else {
            firmwareUpdater.notifyUpdated()
        }
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            remoteAntennaDecoder.decode(command)
        }
    }

    override func firmwareIdentifier() -> FirmwareIdentifier? {
        guard let version = remoteAntenna.firmwareVersion, let model = remoteAntenna.model else { return nil }

        return FirmwareIdentifier(deviceModel: model, version: version)
    }
}

/// Extension for event processing.
extension RaUpdaterController: ArsdkRemoteantennaEventDecoderListener {
    func onState(_ state: Arsdk_Remoteantenna_Event.State) {
        if state.hasAntennaBatteryLevel {
            if state.antennaBatteryLevel.value < 10 {
                updateUnavailabilityReasons.insert(.notEnoughBattery)
            } else {
                updateUnavailabilityReasons.remove(.notEnoughBattery)
            }
        }
        firmwareUpdater.notifyUpdated()
    }

    func onDiscoveredCloudAntennas(_ discoveredCloudAntennas: Arsdk_Remoteantenna_Event.DiscoveredCloudAntennas) {
        // nothing to do
    }

    func onHeading(_ heading: Arsdk_Remoteantenna_Event.Heading) {
        // nothing to do
    }
}
