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
import SdkCore

/// ServiceDiscoveryBrowser implementation
class ServiceDiscoveryBrowserCore: ServiceDiscoveryBrowser {

    /// The utility descriptor
    let desc: UtilityCoreDescriptor = Utilities.serviceDiscoveryBrowser

    /// Services discovered
    var services: Set<ArsdkServiceDiscovery> {
        return browsers.reduce(Set<ArsdkServiceDiscovery>()) { services, browser in
            services.union(browser.services)
        }
    }

    /// Array containing the discovered services.
    var discoveredServices: [DiscoveredService] {
        return services.map { DiscoveredService(from: $0) }
    }

    /// Service discovery browsers.
    var browsers = [ArsdkServiceDiscoveryBrowser]()

    /// Adds a service discovery browser as more prioritized than the currents.
    ///
    /// - Parameter browser: browser to add
    public func addPrioritySdkCoreBrowser(_ browser: ArsdkServiceDiscoveryBrowser) {
        browsers.insert(browser, at: 0)
    }

    /// Adds service discovery browser.
    ///
    /// - Parameter browser: browser to add
    public func addSdkCoreBrowser(_ browser: ArsdkServiceDiscoveryBrowser) {
        browsers.append(browser)
    }
}

/// extension to encode  ArsdkServiceDiscovery in json
extension ArsdkServiceDiscovery: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case domain
        case address
        case port
        case recordData
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.domain, forKey: .domain)
        try container.encode(self.address, forKey: .address)
        try container.encode(self.port, forKey: .port)
        try container.encode(self.recordData, forKey: .recordData)
    }
}
