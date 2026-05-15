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
extension Environment: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Environment, Arsdk_Connectivity_Environment>([
        .indoor: .indoor,
        .outdoor: .outdoor])
}

/// Extension that adds conversion from/to arsdk enum.
extension Band: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Band, Arsdk_Connectivity_Band>([
        .band_2_4_Ghz: .band24Ghz,
        .band_5_Ghz: .band50Ghz])
}

/// Extension that adds conversion from/to arsdk enum.
extension MarsBand: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<MarsBand, Arsdk_Connectivity_Band>([
        .band_1_6_Ghz: .band16Ghz,
        .band_1_8_Ghz: .band18Ghz,
        .band_2_0_Ghz: .band20Ghz,
        .band_2_2_Ghz: .band22Ghz,
        .band_2_3_Ghz: .band23Ghz,
        .band_2_4_Ghz: .band24Ghz,
        .band_2_5_Ghz: .band25Ghz,
        .band_3_5_Ghz: .band35Ghz,
        .band_4_5_Ghz: .band45Ghz,
        .band_5_0_Ghz: .band50Ghz
    ])
}

/// Extension that adds constructor.
extension Arsdk_Connectivity_RadioChannel {
    init(band: Arsdk_Connectivity_Band, id: UInt32) {
        self.band = band
        self.id = id
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension WifiChannel: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<WifiChannel, Arsdk_Connectivity_RadioChannel>([
        .band_2_4_channel1: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 1),
        .band_2_4_channel2: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 2),
        .band_2_4_channel3: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 3),
        .band_2_4_channel4: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 4),
        .band_2_4_channel5: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 5),
        .band_2_4_channel6: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 6),
        .band_2_4_channel7: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 7),
        .band_2_4_channel8: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 8),
        .band_2_4_channel9: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 9),
        .band_2_4_channel10: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 10),
        .band_2_4_channel11: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 11),
        .band_2_4_channel12: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 12),
        .band_2_4_channel13: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 13),
        .band_2_4_channel14: Arsdk_Connectivity_RadioChannel(band: .band24Ghz, id: 14),
        .band_5_channel34: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 34),
        .band_5_channel36: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 36),
        .band_5_channel38: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 38),
        .band_5_channel40: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 40),
        .band_5_channel42: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 42),
        .band_5_channel44: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 44),
        .band_5_channel46: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 46),
        .band_5_channel48: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 48),
        .band_5_channel50: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 50),
        .band_5_channel52: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 52),
        .band_5_channel54: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 54),
        .band_5_channel56: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 56),
        .band_5_channel58: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 58),
        .band_5_channel60: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 60),
        .band_5_channel62: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 62),
        .band_5_channel64: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 64),
        .band_5_channel100: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 100),
        .band_5_channel102: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 102),
        .band_5_channel104: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 104),
        .band_5_channel106: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 106),
        .band_5_channel108: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 108),
        .band_5_channel110: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 110),
        .band_5_channel112: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 112),
        .band_5_channel114: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 114),
        .band_5_channel116: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 116),
        .band_5_channel118: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 118),
        .band_5_channel120: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 120),
        .band_5_channel122: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 122),
        .band_5_channel124: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 124),
        .band_5_channel126: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 126),
        .band_5_channel128: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 128),
        .band_5_channel132: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 132),
        .band_5_channel134: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 134),
        .band_5_channel136: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 136),
        .band_5_channel138: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 138),
        .band_5_channel140: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 140),
        .band_5_channel142: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 142),
        .band_5_channel144: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 144),
        .band_5_channel149: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 149),
        .band_5_channel151: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 151),
        .band_5_channel153: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 153),
        .band_5_channel155: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 155),
        .band_5_channel157: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 157),
        .band_5_channel159: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 159),
        .band_5_channel161: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 161),
        .band_5_channel165: Arsdk_Connectivity_RadioChannel(band: .band50Ghz, id: 165)])
}

/// Extension that adds conversion from arsdk enum.
extension WifiChannel {
    static func fromArsdk(_ arsdkValue: Arsdk_Connectivity_PackedChannelDescriptor) -> [WifiChannel] {
        var array = Array<WifiChannel>()
        var cnt = 0
        var id = arsdkValue.firstID
        let idStep = if (arsdkValue.idStep > 0) { arsdkValue.idStep } else { UInt32(1) }
        while (cnt < arsdkValue.numberOfChannels) {
            var radioChannel = Arsdk_Connectivity_RadioChannel()
            radioChannel.band = arsdkValue.band
            radioChannel.id = id
            if let wifiChannel = WifiChannel(fromArsdk: radioChannel) {
                array.append(wifiChannel)
            }
            id += idStep
            cnt += 1
        }
        return array
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension MarsChannel {
    init?(fromArsdk arsdkValue: Arsdk_Connectivity_Channel) {
        if case .radioChannel(let channel) = arsdkValue.type,
           let band = MarsBand(fromArsdk: channel.band) {
            self.init(band: band, id: UInt(channel.id))
        } else {
            return nil
        }
    }

    /// Arsdk value corresponding to this channel.
    var arsdkValue: Arsdk_Connectivity_Channel? {
        guard let arsdkBand = band.arsdkValue else { return nil }

        let radioChannel = Arsdk_Connectivity_RadioChannel(band: arsdkBand, id: UInt32(id))
        var arsdkChannel = Arsdk_Connectivity_Channel()
        arsdkChannel.type = .radioChannel(radioChannel)
        return arsdkChannel
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension MarsChannel {
    init?(fromArsdk arsdkValue: Arsdk_Connectivity_ChannelDescriptor) {
        if arsdkValue.hasChannel,
           case .radioChannel(let channel) = arsdkValue.channel.type,
           let band = MarsBand(fromArsdk: channel.band) {
            self.init(band: band, id: UInt(channel.id), frequency: UInt(arsdkValue.frequency))
        } else {
            return nil
        }
    }

    static func fromArsdk(_ arsdkValue: Arsdk_Connectivity_PackedChannelDescriptor) -> [MarsChannel] {
        var array = Array<MarsChannel>()
        guard let band = MarsBand(fromArsdk: arsdkValue.band) else {
            return array
        }
        let idStep = if (arsdkValue.idStep > 0) { arsdkValue.idStep } else { UInt32(1) }
        let frequencyStep = if (arsdkValue.frequencyStep > 0) { arsdkValue.frequencyStep } else { UInt32(1) }
        var cnt = 0
        var freq = arsdkValue.firstFrequency
        var id = arsdkValue.firstID
        while (cnt < arsdkValue.numberOfChannels) {
            array.append(MarsChannel(band: band, id: UInt(id), frequency: UInt(freq)))
            id += idStep
            freq += frequencyStep
            cnt += 1
        }
        return array
    }
}

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
extension MarsSecurityMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<MarsSecurityMode, Arsdk_Connectivity_EncryptionType>([
        .open: .open,
        .aes128: .aes128,
        .aes256: .aes256])
}
