//
//  AudioConstants.swift
//  zz-time
//
//  Central configuration for all audio-related constants and volume settings.
//

import Foundation

struct AudioConstants {
    // MARK: - Volume Boost Configuration

    /// Master volume boost in decibels (dB)
    /// 12 dB boost = ~4x volume multiplier (10^(12/20) = 3.98)
    /// Adjust this value to change the global volume boost for all audio
    /// Common values: 0 (no boost), 6 (2x), 12 (4x), 18 (8x)
    static let volumeBoostDB: Float = 12.0

    /// Computed volume multiplier from dB boost
    /// Formula: multiplier = 10^(dB/20)
    static var volumeBoostMultiplier: Float {
        pow(10.0, volumeBoostDB / 20.0)
    }

    // MARK: - Base Volume Levels (before boost)

    /// Base maximum ambient audio volume (0.0 to 1.0)
    static let baseAmbientMaxVolume: Float = 0.6

    /// Base TTS narration volume (0.0 to 1.0)
    static let baseTTSVolume: Float = 0.1

    /// Base alarm preview volume (0.0 to 1.0)
    static let basePreviewVolume: Float = 0.5

    /// Base alarm volume (0.0 to 1.0)
    static let baseAlarmVolume: Float = 1.0

    // MARK: - Boosted Volume Levels (computed)

    /// Boosted ambient audio maximum (capped at 1.0)
    static var ambientMaxVolume: Float {
        min(baseAmbientMaxVolume * volumeBoostMultiplier, 1.0)
    }

    /// Boosted TTS narration volume (capped at 1.0)
    static var ttsVolume: Float {
        min(baseTTSVolume * volumeBoostMultiplier, 1.0)
    }

    /// Boosted alarm preview volume (capped at 1.0)
    static var previewVolume: Float {
        min(basePreviewVolume * volumeBoostMultiplier, 1.0)
    }

    /// Boosted alarm volume (always capped at 1.0)
    static var alarmVolume: Float {
        min(baseAlarmVolume * volumeBoostMultiplier, 1.0)
    }
}
