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

/// Base controller for eSIM peripheral
class ESimController: DeviceComponentController, ESimBackend {

    /// The eSIM component.
    private var eSim: ESimCore!

    /// Decoder for eSIM events.
    private var eSimDecoder: ArsdkEsimEventDecoder!

    /// Http generic client
    private var httpGenericClient: HttpGenericClient?

    /// Cancellable request
    private var cancellable: CancelableCore?

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        eSim = ESimCore(store: deviceController.device.peripheralStore, backend: self)
        eSimDecoder = ArsdkEsimEventDecoder(listener: self)
    }

    override func willConnect() {
        _ = sendGetStateCommand()
    }

    override func didConnect() {
        let core = HttpSessionCore(sessionConfiguration: URLSessionConfiguration.default)
        httpGenericClient = HttpGenericClient(httpSession: core)
    }

    override func didDisconnect() {
        cancellable?.cancel()
        cancellable = nil
        httpGenericClient = nil
        eSim.update(operationState: nil)
        eSim.cancelRollback()
        eSim.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        eSimDecoder.decode(command)
    }

    func downloadProfile(activationCode: String, confirmationCode: String?) -> Bool {
        var downloadProfile = Arsdk_Esim_Command.DownloadProfile()
        downloadProfile.activationCode = activationCode
        if let confirmationCode {
            downloadProfile.confirmationCode = Google_Protobuf_StringValue(confirmationCode)
        }
        return sendESimCommand(.downloadProfile(downloadProfile))
    }

    func deleteProfile(iccid: String) -> Bool {
        var deleteProfile = Arsdk_Esim_Command.DeleteProfile()
        deleteProfile.iccid = iccid
        return sendESimCommand(.deleteProfile(deleteProfile))
    }

    func enableProfile(iccid: String, enable: Bool) -> Bool {
        var enableProfile = Arsdk_Esim_Command.EnableProfile()
        enableProfile.iccid = iccid
        enableProfile.enable = enable
        return sendESimCommand(.enableProfile(enableProfile))
    }

    func httpCommand(id: UInt32, code: Int?, errorCode: ESimErrorCode?, message: String?, data: Data?) {
        var httpCommand = Arsdk_Esim_Command.HttpResponse()
        httpCommand.id = id
        if let code {
            httpCommand.code = Int32(code)
        }
        if let errorCodeVal = errorCode?.arsdkValue {
            httpCommand.errorCode = errorCodeVal
        }
        if let data {
            httpCommand.data = data
        }
        if let message {
            httpCommand.message = message
        }
        _ = sendESimCommand(.httpResponse(httpCommand))
    }
}

/// Extension for methods to send eSIM commands.
extension ESimController {

    /// Sends to the drone a eSIM command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendESimCommand(_ command: Arsdk_Esim_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkEsimCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends get capabilities command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Esim_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendESimCommand(.getState(getState))
    }
}

/// Extension for events processing.
extension ESimController: ArsdkEsimEventDecoderListener {
    func onHttpRequest(_ httpRequest: Arsdk_Esim_Event.HttpRequest) {
        cancellable = httpGenericClient?.execute(url: httpRequest.url, headers: httpRequest.headers,
                                                 data: httpRequest.data,
                                                 trustAllCertificates: true) { [weak self] code, httpCode, data in
            var errorCode: ESimErrorCode?
            switch httpCode {
            case .canceled:
                errorCode = .httpConnectFailure
            case .failed:
                errorCode = .httpRequestFailure
            case .success:
                errorCode = .ok
            }
            self?.httpCommand(id: httpRequest.id, code: code, errorCode: errorCode, message: nil, data: data)
        }
    }

    func onState(_ state: Arsdk_Esim_Event.State) {
        if state.hasProfileList {
            let profileList = state.profileList.profiles.compactMap { profile in
                ESimProfile(iccid: profile.iccid, provider: profile.provider, enabled: profile.enabled)
            }
            eSim.update(profileList: Set(profileList))
        }

        if state.hasSimStatusValue, let simStatus = ESimStatus(fromArsdk: state.simStatusValue.value) {
            eSim.update(status: simStatus)
        }

        if state.hasEid {
            eSim.update(eID: state.eid.value)
        }
        var receivedProfileStatus = false
        if state.hasProfileOperationStatus {
            receivedProfileStatus = true
            let errorCode = ESimErrorCode(fromArsdk: state.profileOperationStatus.errorCode) ?? .unknown
            switch state.profileOperationStatus.type {
            case .downloadProfileStatus(let status):
                let profile = ESimProfile(iccid: status.profile.iccid,
                                          provider: status.profile.provider,
                                          enabled: status.profile.enabled)
                eSim.update(operationState: OperationState.download(error: errorCode, profile: profile))

            case .enableProfileStatus(let status):
                eSim.update(operationState: OperationState.enable(error: errorCode, iccid: status.iccid,
                                                       enabled: status.enabled))
            case .deleteProfileStatus(let status):
                eSim.update(operationState: OperationState.delete(error: errorCode, iccid: status.iccid))
            default:
                break
            }
        }

        eSim.publish()

        // reset transient status
        if receivedProfileStatus {
            eSim.update(operationState: nil)
            eSim.notifyUpdated()
        }
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension ESimStatus: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<ESimStatus, Arsdk_Esim_SimStatus>([
        .euiccNotSupported: .euiccNotSupported,
        .notPresent: .notPresent,
        .ready: .ready
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension ESimErrorCode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<ESimErrorCode, Arsdk_Esim_ErrorCode>([
        .ok: .ok,
        .internalError: .internal,
        .invalidSim: .invalidSim,
        .invalidICCID: .invalidIccid,
        .invalidProfileState: .invalidProfileState,
        .disallowedByPolicy: .disallowedByPolicy,
        .wrongProfileReenabling: .wrongProfileReenabling,
        .httpConnectFailure: .httpConnectFailure,
        .httpRequestFailure: .httpRequestFailure,
        .invalidActivationCode: .invalidActivationCode,
        .confirmationCodeRequired: .confirmationCodeRequired,
        .serverAuthenticationFailure: .serverAuthenticationFailure,
        .clientAuthenticationFailure: .clientAuthenticationFailure
    ])
}
