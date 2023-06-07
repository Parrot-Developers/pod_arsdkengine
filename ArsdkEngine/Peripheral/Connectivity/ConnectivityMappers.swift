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

/// Extension that adds conversion from/to arsdk enum.
extension SecurityMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<SecurityMode, Arsdk_Connectivity_EncryptionType>([
        .open: .open,
        .wepSecured: .wep,
        .wpaSecured: .wpa,
        .wpa2Secured: .wpa2,
        .wpa3Secured: .wpa3])
}

/// Extension that adds conversion from/to arsdk enum.
extension Environment: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Environment, Arsdk_Connectivity_Environment>([
        .indoor: .indoor,
        .outdoor: .outdoor])
}

/// Extension that adds conversion from/to arsdk enum.
extension Band: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Band, Arsdk_Connectivity_WifiBand>([
        .band_2_4_Ghz: .wifiBand24Ghz,
        .band_5_Ghz: .wifiBand5Ghz])
}

/// Extension that adds constructor.
extension Arsdk_Connectivity_WifiChannel {
    init(band: Arsdk_Connectivity_WifiBand, channel: UInt32) {
        self.band = band
        self.channel = channel
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension WifiChannel: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<WifiChannel, Arsdk_Connectivity_WifiChannel>([
        .band_2_4_channel1: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 1),
        .band_2_4_channel2: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 2),
        .band_2_4_channel3: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 3),
        .band_2_4_channel4: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 4),
        .band_2_4_channel5: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 5),
        .band_2_4_channel6: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 6),
        .band_2_4_channel7: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 7),
        .band_2_4_channel8: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 8),
        .band_2_4_channel9: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 9),
        .band_2_4_channel10: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 10),
        .band_2_4_channel11: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 11),
        .band_2_4_channel12: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 12),
        .band_2_4_channel13: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 13),
        .band_2_4_channel14: Arsdk_Connectivity_WifiChannel(band: .wifiBand24Ghz, channel: 14),
        .band_5_channel34: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 34),
        .band_5_channel36: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 36),
        .band_5_channel38: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 38),
        .band_5_channel40: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 40),
        .band_5_channel42: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 42),
        .band_5_channel44: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 44),
        .band_5_channel46: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 46),
        .band_5_channel48: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 48),
        .band_5_channel50: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 50),
        .band_5_channel52: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 52),
        .band_5_channel54: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 54),
        .band_5_channel56: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 56),
        .band_5_channel58: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 58),
        .band_5_channel60: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 60),
        .band_5_channel62: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 62),
        .band_5_channel64: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 64),
        .band_5_channel100: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 100),
        .band_5_channel102: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 102),
        .band_5_channel104: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 104),
        .band_5_channel106: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 106),
        .band_5_channel108: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 108),
        .band_5_channel110: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 110),
        .band_5_channel112: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 112),
        .band_5_channel114: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 114),
        .band_5_channel116: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 116),
        .band_5_channel118: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 118),
        .band_5_channel120: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 120),
        .band_5_channel122: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 122),
        .band_5_channel124: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 124),
        .band_5_channel126: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 126),
        .band_5_channel128: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 128),
        .band_5_channel132: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 132),
        .band_5_channel134: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 134),
        .band_5_channel136: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 136),
        .band_5_channel138: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 138),
        .band_5_channel140: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 140),
        .band_5_channel142: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 142),
        .band_5_channel144: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 144),
        .band_5_channel149: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 149),
        .band_5_channel151: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 151),
        .band_5_channel153: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 153),
        .band_5_channel155: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 155),
        .band_5_channel157: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 157),
        .band_5_channel159: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 159),
        .band_5_channel161: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 161),
        .band_5_channel165: Arsdk_Connectivity_WifiChannel(band: .wifiBand5Ghz, channel: 165)])
}
