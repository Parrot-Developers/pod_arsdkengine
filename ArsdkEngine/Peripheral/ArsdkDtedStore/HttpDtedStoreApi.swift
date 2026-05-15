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

class HttpDtedStoreApi: NSObject, DtedStoreApi {

    private unowned let deviceController: DeviceController
    private var dtedRestApi: DtedRestApi?
    private var dtedWsApi: DtedWsApi?

    weak var delegate: DtedStoreApiDelegate?

    init(deviceController: DeviceController) {
        self.deviceController = deviceController
    }

    func configure() {
        if let droneServer = deviceController.deviceServer {
            dtedRestApi = DtedRestApi(server: droneServer, deviceModel: deviceController.deviceModel)
        }
    }

    func reset() {
        dtedRestApi = nil
    }

    func startWatchingContentChanges() {
        if let droneServer = deviceController.deviceServer {
            dtedWsApi = DtedWsApi(
                server: droneServer,
                deviceModel: deviceController.deviceModel) { [unowned self] event  in
                    self.delegate?.receivedDtedStoreChangedEvent(event)
                }
        }
    }

    func stopWatchingContentChanges() {
        dtedWsApi = nil
    }

    /// Get the list of dted files on the drone
    ///
    /// - Parameters:
    ///   - completion: closure that will be called when browsing did finish
    ///   - files: list of dted files on the device
    /// - Returns: a request that can be canceled
    func browse(completion: @escaping (_ files: [DtedFileCore]) -> Void) -> CancelableCore? {
        dtedRestApi?.getFileList(completion: { files in
            completion(files ?? [])
        })
    }

    /// Requests the DTED file from the store at specified location.
    ///
    /// - Parameters:
    ///   - latitude: latitude of location for which file is requested
    ///   - longitude: longitude of location for which file is requested
    ///   - completion: closure called when the request is terminated
    /// - Returns: a request that can be canceled
    func get(latitude: Double, longitude: Double, completion: @escaping (DtedFileCore?) -> Void) -> CancelableCore? {
        dtedRestApi?.getFile(latitude: latitude, longitude: longitude, completion: { file in
            completion(file)
        })
    }

    /// Uploads a dted file.
    ///
    /// - Parameters:
    ///   - fileUrl: the file to upload
    ///   - progress: progress callback
    ///   - progressValue: the progress value, from 0 to 100
    ///   - completion: completion callback
    /// - Returns: a request that can be canceled
    func upload(fileUrl: URL,
                progress: @escaping (_ progressValue: Int) -> Void,
                completion: @escaping (_ success: Bool) -> Void) -> CancelableCore? {
        dtedRestApi?.upload(fileURL: fileUrl, progress: progress, completion: completion)
    }

    // Delete dted file
    ///
    /// - Parameters:
    ///   - fileName: file name to delete
    ///   - completion: completion callback
    /// - Returns: delete request, or `nil` if the request can't be sent
    func delete(fileName: String, completion: @escaping (Bool) -> Void)
    -> CancelableCore? {
        dtedRestApi?.deleteFile(fileName, completion: completion)
    }
}
