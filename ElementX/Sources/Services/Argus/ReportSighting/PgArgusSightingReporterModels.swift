//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

//
// Mirrors backend types. Enum cases use explicit `String` raw values matching the Argus
// backend's JSON-string enum representation, so the wire decoding is independent of
// declaration order and case naming.
//
// Each wire enum has a `matrixRustValue` mapping to the matching `MatrixRustSDK` FFI enum
// case; the FFI types are not `Decodable`, so this thin wire layer is the seam where
// brownfield JSON becomes typed Rust SDK calls.

struct PgArgusReportSightingPayload: Decodable {
    let date: String?
    let comment: String?
    let amount: PgArgusDroneAmountPayload
    let types: [PgArgusDroneTypePayload]?
    let soundType: PgArgusDroneSoundTypePayload?
    let position: PgArgusDronePositionPayload
    let lights: PgArgusDroneLightsPayload?
    let fileIds: [String]
    let weatherCondition: PgArgusWeatherConditionPayload?
    let weatherWindCondition: PgArgusWindConditionPayload?
    let observationMethods: [PgArgusObservationMethodPayload]
    let duration: PgArgusSightingDurationPayload?
    
    func matrixRustValue() -> CreateSightingRequest {
        CreateSightingRequest(date: date,
                              comment: comment,
                              amount: amount.matrixRustValue,
                              types: types?.map(\.matrixRustValue),
                              soundType: soundType?.matrixRustValue,
                              position: position.matrixRustValue(),
                              lights: lights?.matrixRustValue(),
                              fileIds: fileIds,
                              weatherCondition: weatherCondition?.matrixRustValue,
                              weatherWindCondition: weatherWindCondition?.matrixRustValue,
                              observationMethods: observationMethods.map(\.matrixRustValue),
                              duration: duration?.matrixRustValue)
    }
}

struct PgArgusDronePositionPayload: Decodable {
    let userLocation: PgArgusPointPayload?
    let droneLocationStart: PgArgusPointPayload?
    let droneLocationEnd: PgArgusPointPayload?
    let angleToUser: Int32?
    let trajectories: [PgArgusDroneTrajectoryPayload]?
    let isInFormation: Bool?
    let formationDescription: String?
    let outOfSightReason: PgArgusOutOfSightReasonPayload?
    let outOfSightReasonDescription: String?
    
    func matrixRustValue() -> CreateSightingDroneInfoPosition {
        CreateSightingDroneInfoPosition(userLocation: userLocation?.matrixRustValue(),
                                        droneLocationStart: droneLocationStart?.matrixRustValue(),
                                        droneLocationEnd: droneLocationEnd?.matrixRustValue(),
                                        angleToUser: angleToUser,
                                        trajectories: trajectories?.map(\.matrixRustValue) ?? [],
                                        isInFormation: isInFormation,
                                        formationDescription: formationDescription,
                                        outOfSightReason: outOfSightReason?.matrixRustValue,
                                        outOfSightReasonDescription: outOfSightReasonDescription)
    }
}

struct PgArgusDroneLightsPayload: Decodable {
    let didObserveLights: Bool?
    let amount: UInt8?
    let flashing: PgArgusLightFlashingPayload?
    let colours: [PgArgusLightColourPayload]?
    
    func matrixRustValue() -> CreateSightingDroneInfoLights {
        CreateSightingDroneInfoLights(didObserveLights: didObserveLights,
                                      amount: amount,
                                      flashing: flashing?.matrixRustValue,
                                      colours: colours?.map(\.matrixRustValue))
    }
}

struct PgArgusPointPayload: Decodable {
    let lat: Double?
    let lon: Double?
    
    func matrixRustValue() -> CreateSightingPoint {
        CreateSightingPoint(lat: lat, lon: lon)
    }
}

enum PgArgusDroneAmountPayload: String, Decodable {
    case one = "One"
    case two = "Two"
    case three = "Three"
    case four = "Four"
    case five = "Five"
    case six = "Six"
    case sixOrMore = "SixOrMore"
    
    var matrixRustValue: DroneAmount {
        switch self {
        case .one: .one
        case .two: .two
        case .three: .three
        case .four: .four
        case .five: .five
        case .six: .six
        case .sixOrMore: .sixOrMore
        }
    }
}

enum PgArgusSightingDurationPayload: String, Decodable {
    case ongoing = "Ongoing"
    case zeroToFiveMin = "ZeroToFiveMin"
    case fiveToTenMin = "FiveToTenMin"
    case tenToTwentyMin = "TenToTwentyMin"
    case twentyToThirtyMin = "TwentyToThirtyMin"
    case thirtyPlusMin = "ThirtyPlusMin"
    
    var matrixRustValue: SightingDuration {
        switch self {
        case .ongoing: .ongoing
        case .zeroToFiveMin: .zeroToFiveMin
        case .fiveToTenMin: .fiveToTenMin
        case .tenToTwentyMin: .tenToTwentyMin
        case .twentyToThirtyMin: .twentyToThirtyMin
        case .thirtyPlusMin: .thirtyPlusMin
        }
    }
}

enum PgArgusDroneTypePayload: String, Decodable {
    case none = "None"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case rwSingleRotor = "RWSingleRotor"
    case fwDeltaWing = "FWDeltaWing"
    case rwQuadMulticopter = "RWQuadMulticopter"
    case rwHexaMulticopter = "RWHexaMulticopter"
    case fw = "FW"
    case fwvtol = "FWVTOL"
    
    var matrixRustValue: DroneType {
        switch self {
        case .none: .none
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .rwSingleRotor: .rwSingleRotor
        case .fwDeltaWing: .fwDeltaWing
        case .rwQuadMulticopter: .rwQuadMulticopter
        case .rwHexaMulticopter: .rwHexaMulticopter
        case .fw: .fw
        case .fwvtol: .fwvtol
        }
    }
}

enum PgArgusDroneSoundTypePayload: String, Decodable {
    case none = "None"
    case electric = "Electric"
    case thermal = "Thermal"
    
    var matrixRustValue: DroneInfoSoundType {
        switch self {
        case .none: .none
        case .electric: .electric
        case .thermal: .thermal
        }
    }
}

enum PgArgusDroneTrajectoryPayload: String, Decodable {
    case straight = "Straight"
    case zigZag = "ZigZag"
    case hovering = "Hovering"
    
    var matrixRustValue: DroneInfoPositionTrajectory {
        switch self {
        case .straight: .straight
        case .zigZag: .zigZag
        case .hovering: .hovering
        }
    }
}

enum PgArgusOutOfSightReasonPayload: String, Decodable {
    case none = "None"
    case behindObject = "BehindObject"
    case clouds = "Clouds"
    case other = "Other"
    
    var matrixRustValue: DroneInfoPositionOutOfSightReason {
        switch self {
        case .none: .none
        case .behindObject: .behindObject
        case .clouds: .clouds
        case .other: .other
        }
    }
}

enum PgArgusLightFlashingPayload: String, Decodable {
    case no = "No"
    case slow = "Slow"
    case fast = "Fast"
    
    var matrixRustValue: DroneInfoLightFlashing {
        switch self {
        case .no: .no
        case .slow: .slow
        case .fast: .fast
        }
    }
}

enum PgArgusLightColourPayload: String, Decodable {
    case white = "White"
    case red = "Red"
    case green = "Green"
    case blue = "Blue"
    
    var matrixRustValue: DroneInfoLightColour {
        switch self {
        case .white: .white
        case .red: .red
        case .green: .green
        case .blue: .blue
        }
    }
}

enum PgArgusWeatherConditionPayload: String, Decodable {
    case none = "None"
    case clear = "Clear"
    case cloudy = "Cloudy"
    case veryCloudy = "VeryCloudy"
    case lightRain = "LightRain"
    case moderateRain = "ModerateRain"
    case heavyRain = "HeavyRain"
    case fog = "Fog"
    
    var matrixRustValue: WeatherCondition {
        switch self {
        case .none: .none
        case .clear: .clear
        case .cloudy: .cloudy
        case .veryCloudy: .veryCloudy
        case .lightRain: .lightRain
        case .moderateRain: .moderateRain
        case .heavyRain: .heavyRain
        case .fog: .fog
        }
    }
}

enum PgArgusWindConditionPayload: String, Decodable {
    case no = "No"
    case moderate = "Moderate"
    case heavy = "Heavy"
    
    var matrixRustValue: WeatherWindCondition {
        switch self {
        case .no: .no
        case .moderate: .moderate
        case .heavy: .heavy
        }
    }
}

enum PgArgusObservationMethodPayload: String, Decodable {
    case visually = "Visually"
    case binoculars = "Binoculars"
    case thermal = "Thermal"
    case sound = "Sound"
    case radio = "Radio"
    case radar = "Radar"
    
    var matrixRustValue: ObservationMethod {
        switch self {
        case .visually: .visually
        case .binoculars: .binoculars
        case .thermal: .thermal
        case .sound: .sound
        case .radio: .radio
        case .radar: .radar
        }
    }
}
