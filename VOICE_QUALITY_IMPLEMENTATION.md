# High-Quality Voice Implementation Guide

## Overview

This document outlines the implementation strategy for adding optional high-quality voice downloads to the z rooms meditation app on both iOS and Android platforms. This feature allows users to optionally use enhanced, more natural-sounding voices while maintaining the current artificial voice aesthetic as the default.

---

## iOS Implementation

### Technical Foundation

**Framework**: `AVSpeechSynthesizer` (AVFoundation)

**Voice Quality Tiers**:
- **Compact** (~50-100MB) - Basic quality, pre-installed on all devices
- **Enhanced** (~100-300MB) - Improved quality, downloadable
- **Premium/Neural** (~300-500MB+) - Highest quality with neural TTS, downloadable

**Key Advantage**: Voice downloads are managed by iOS as system-level assets, **not** bundled with the app. They don't count against app size and are stored in shared system space.

### Architecture Changes

#### 1. Voice Management Module

**New File**: `VoiceManager.swift`

**Responsibilities**:
- Discover available voices on device
- Check voice quality and download status
- Provide voice selection logic with fallback
- Handle voice preference persistence

**Key APIs**:
```swift
// Discover all voices
AVSpeechSynthesisVoice.speechVoices()

// Check voice quality
voice.quality // Returns: .default, .enhanced, or .premium

// Voice properties
voice.name          // "Samantha", "Alex", etc.
voice.identifier    // Unique identifier for persistence
voice.language      // "en-US", "en-GB", etc.
```

#### 2. Settings UI

**New File**: `VoiceSettingsView.swift`

**Components**:
- Toggle: "Use Enhanced Voice" (off by default)
- Voice picker: Shows available enhanced/premium voices when toggle is on
- Quality indicators: Show which voices are downloaded vs. need download
- Preview button: Test selected voice with sample phrase
- Storage info: Estimated size for each voice option

**Access Method**:
- Add gear/settings icon to main grid view (bottom-left or top-right corner)
- Or: Long-press gesture on "z rooms" title text
- Or: Three-finger tap gesture (hidden feature)

#### 3. Modified Files

**`TextToSpeechManager.swift`**:

**Changes Needed** (4 locations):
- Line 90: `startSpeakingCustomText(_:)`
- Line 149: `startSpeakingRandomMeditation()`
- Line 307: `startSpeakingWithPauses(_:)`
- Line 448: `speakWakeUpGreeting()`

**Modification Pattern**:
```swift
// Current code:
if let voice = AVSpeechSynthesisVoice(language: "en-US") {
    utterance.voice = voice
}

// New code:
utterance.voice = VoiceManager.shared.getPreferredVoice()
```

**`ContentView.swift`**:
- Add navigation to settings view
- No changes to TTS functionality (handled by TextToSpeechManager)

#### 4. Persistence

**UserDefaults Keys**:
- `useEnhancedVoice`: Bool (default: false)
- `preferredVoiceIdentifier`: String? (voice.identifier)
- `preferredVoiceLanguage`: String? (for display purposes)

#### 5. Fallback Logic

**Priority Order**:
1. User's selected enhanced/premium voice (if enabled and available)
2. Any downloaded enhanced voice for "en-US" (if enhanced setting is on)
3. Default compact system voice (current behavior)

**Implementation**:
```swift
func getPreferredVoice() -> AVSpeechSynthesisVoice? {
    guard useEnhancedVoice else {
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    // Try user's preferred voice
    if let identifier = preferredVoiceIdentifier,
       let voice = AVSpeechSynthesisVoice(identifier: identifier) {
        return voice
    }

    // Fallback to any enhanced voice
    let enhancedVoices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("en-") &&
                  $0.quality != .default }

    if let voice = enhancedVoices.first {
        return voice
    }

    // Final fallback to default
    return AVSpeechSynthesisVoice(language: "en-US")
}
```

### User Experience Flow

**First-Time User**:
1. App works exactly as it does now (default voice)
2. User discovers settings icon/gesture
3. Opens voice settings, sees "Use Enhanced Voice" toggle (off)
4. Toggles on, sees list of available voices with quality indicators
5. Selects a voice → iOS automatically downloads if needed (system handles this)
6. Tests voice with preview button
7. Returns to app, meditation now uses enhanced voice

**System Voice Download**:
- iOS presents system download prompt when voice is first used
- Download happens in background
- If download fails/cancelled, app falls back to default voice
- Users can also pre-download voices via Settings → Accessibility → Spoken Content → Voices

### Implementation Estimate

**Complexity**: Low-Medium

**Estimated Changes**:
- New files: 2 (~300 lines total)
  - `VoiceManager.swift` (~150 lines)
  - `VoiceSettingsView.swift` (~150 lines)
- Modified files: 2
  - `TextToSpeechManager.swift` (~10 lines changed)
  - `ContentView.swift` (~30 lines for settings navigation)
- Total new/modified code: ~340 lines

**Development Time**: 4-6 hours

**Testing Requirements**:
- Test with no enhanced voices downloaded
- Test with multiple enhanced voices available
- Test voice download cancellation
- Test app behavior when preferred voice is deleted from system
- Test with VoiceOver enabled (accessibility)

---

## Android Implementation

### Technical Foundation

**Framework**: `android.speech.tts.TextToSpeech` (Android TTS API)

**Voice Quality Tiers**:
- **Standard voices** - Basic quality, pre-installed
- **High-quality voices** - Enhanced neural voices, downloadable via Google Play Services
- **WaveNet voices** (Google Cloud TTS) - Premium quality, requires internet + API billing

**Android Voice Sources**:
1. **System TTS Engine** (usually Google Text-to-Speech)
2. **Third-party TTS engines** (Samsung, etc.)
3. **Google Cloud Text-to-Speech API** (requires internet, not suitable for offline app)

### Feasibility Comparison

| Aspect | iOS | Android |
|--------|-----|---------|
| **Offline Voices** | ✅ Yes | ✅ Yes |
| **System-Managed Downloads** | ✅ Yes | ✅ Yes (via Google TTS app) |
| **App Size Impact** | ✅ None | ✅ None |
| **Free Enhanced Voices** | ✅ Yes | ⚠️ Limited |
| **API Complexity** | ✅ Simple | ⚠️ Moderate |
| **Voice Quality Control** | ✅ High | ⚠️ Variable (engine-dependent) |

### Architecture Changes (Android)

#### 1. Voice Management Module

**New File**: `VoiceManager.kt` or `VoiceManager.java`

**Key APIs**:
```kotlin
// Initialize TTS
textToSpeech = TextToSpeech(context) { status ->
    if (status == TextToSpeech.SUCCESS) {
        // Get available voices
        val voices = textToSpeech.voices

        // Filter for quality
        val enhancedVoices = voices.filter { voice ->
            voice.quality >= Voice.QUALITY_HIGH
        }
    }
}

// Voice properties
voice.name           // "en-us-x-sfg#male_1-local"
voice.locale         // Locale.US
voice.quality        // QUALITY_VERY_LOW to QUALITY_VERY_HIGH
voice.latency        // LATENCY_VERY_LOW to LATENCY_VERY_HIGH
voice.isNetworkConnectionRequired  // false for offline voices
```

#### 2. Settings UI

**New File**: `VoiceSettingsActivity.kt` or Fragment/Composable

**Components**:
- Toggle: "Use Enhanced Voice"
- Voice picker: Shows available high-quality voices
- Quality indicators: QUALITY_HIGH, QUALITY_VERY_HIGH, QUALITY_NORMAL
- Preview button: Test voice
- "Get More Voices" button: Deep-link to Google TTS app settings

**Deep-link to Google TTS**:
```kotlin
val intent = Intent()
intent.action = "com.android.settings.TTS_SETTINGS"
startActivity(intent)
```

#### 3. Voice Download Handling

**Challenge**: Unlike iOS, Android doesn't automatically prompt for voice downloads when a voice is selected. Users must manually download voices through the Google Text-to-Speech app.

**Solution**:
1. Detect when selected voice is not available
2. Show in-app dialog: "This voice requires download. Open Google Text-to-Speech settings?"
3. Provide button to open TTS settings
4. Show tutorial/help text with screenshots

**Code Example**:
```kotlin
fun checkVoiceAvailable(voice: Voice): Boolean {
    val result = textToSpeech.setVoice(voice)
    return result == TextToSpeech.SUCCESS
}

fun promptVoiceDownload(voiceName: String) {
    AlertDialog.Builder(context)
        .setTitle("Voice Download Required")
        .setMessage("$voiceName needs to be downloaded. Open voice settings?")
        .setPositiveButton("Open Settings") { _, _ ->
            openTTSSettings()
        }
        .setNegativeButton("Cancel", null)
        .show()
}
```

#### 4. Modified Files

**`MeditationSpeechManager.kt`** (or equivalent):
- Replace hardcoded locale/voice with `VoiceManager.getPreferredVoice()`
- Add fallback handling for unavailable voices

**Modification Pattern**:
```kotlin
// Current code:
textToSpeech.language = Locale.US

// New code:
val voice = VoiceManager.getInstance().getPreferredVoice()
if (voice != null) {
    textToSpeech.setVoice(voice)
} else {
    textToSpeech.language = Locale.US  // Fallback
}
```

#### 5. Persistence

**SharedPreferences Keys**:
- `use_enhanced_voice`: Boolean (default: false)
- `preferred_voice_name`: String? (voice.name)
- `preferred_voice_locale`: String? (voice.locale.toString())

#### 6. Fallback Logic

**Priority Order**:
1. User's selected enhanced voice (if enabled and available)
2. Any QUALITY_HIGH or QUALITY_VERY_HIGH voice for current locale
3. Default system voice (current behavior)

### Android-Specific Challenges

**1. TTS Engine Variability**
- Different devices may have different TTS engines installed
- Voice availability varies by manufacturer (Samsung, Xiaomi, etc.)
- Quality standards not uniform across engines

**Solution**:
- Filter voices by Google TTS engine when possible
- Provide clear messaging about voice availability
- Robust fallback to system default

**2. Voice Naming Inconsistency**
- Voice names are often cryptic (e.g., "en-us-x-sfg#male_2-local")
- No friendly display names in API

**Solution**:
- Create mapping of common voice names to friendly names
- Display locale + quality level if friendly name unavailable
- Group voices by language/accent

**3. Manual Download Process**
- Users must leave app to download voices
- No programmatic download trigger

**Solution**:
- Excellent UX design for guiding users
- Consider in-app tutorial/help screen with screenshots
- Option to show "Available Now" vs. "Requires Download" sections

### Android Implementation Estimate

**Complexity**: Medium (higher than iOS due to API limitations)

**Estimated Changes**:
- New files: 3 (~500 lines total)
  - `VoiceManager.kt` (~200 lines)
  - `VoiceSettingsActivity.kt` (~200 lines)
  - `VoiceNameMapper.kt` (~100 lines - friendly name mappings)
- Modified files: 2-3
  - Meditation TTS manager (~20 lines)
  - Settings navigation (~40 lines)
  - Potentially MainActivity for settings launch
- Total new/modified code: ~560 lines

**Development Time**: 6-8 hours (extra time for UX polish around manual downloads)

**Testing Requirements**:
- Test on multiple Android versions (8.0+)
- Test with different TTS engines (Google, Samsung)
- Test with no Google TTS app installed
- Test voice unavailability scenarios
- Test TalkBack compatibility (accessibility)

---

## Comparative Summary

### iOS: **Highly Feasible** ✅

**Strengths**:
- Seamless voice download experience
- Consistent API across devices
- System manages downloads automatically
- No additional user education needed
- Clean, simple implementation

**Recommendation**: **Implement immediately** - straightforward enhancement with minimal risk

### Android: **Feasible with Caveats** ⚠️

**Strengths**:
- Offline voices available
- No app size impact
- Free enhanced voices exist

**Challenges**:
- Manual download process (UX friction)
- Voice availability varies by device
- Requires more user education
- More complex implementation

**Recommendation**: **Implement with enhanced UX guidance** - feasible but requires careful UX design around voice discovery and download process

---

## Cross-Platform Strategy

### Phase 1: iOS Implementation
- Simpler implementation
- Proves concept value
- Gather user feedback
- Refine settings UI/UX

### Phase 2: Android Implementation
- Apply learnings from iOS version
- Enhanced onboarding/tutorial for voice downloads
- Consider creating help documentation/video

### Phase 3: Iteration
- Monitor user adoption rates
- Collect feedback on voice preferences
- Consider adding voice packs/themes in future
- Potential for custom voice samples (advanced users)

---

## Design Recommendations

### Settings Screen Layout

**iOS & Android (Consistent Design)**:

```
┌─────────────────────────────────────┐
│  ← Voice Settings                   │
├─────────────────────────────────────┤
│                                     │
│  [🔊] Enhanced Voice        [○]     │
│  Use higher-quality meditation      │
│  voice (downloaded separately)      │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  Voice Selection                    │
│  ┌───────────────────────────────┐ │
│  │ ◉ Samantha (US)      ✓ High  │ │
│  │ ○ Alex (US)          ✓ High  │ │
│  │ ○ Karen (AU)         ↓ Needs │ │
│  │                       Download│ │
│  └───────────────────────────────┘ │
│                                     │
│  [▶ Preview Voice]                  │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  ℹ️ About Enhanced Voices            │
│  Higher quality voices are          │
│  downloaded by your device and      │
│  stored in system settings.         │
│  They do not increase app size.     │
│                                     │
│  [Get More Voices] (Android only)   │
│                                     │
└─────────────────────────────────────┘
```

### Meditation Text Preparation Note

**Current Implementation Compatibility**:
- Feature works seamlessly with existing pause system `(2s)`, `(1.5m)`
- No changes needed to 35 preset meditations
- Custom meditation editor remains unchanged
- Closed captioning continues to work identically
- Voice balance slider continues to function

**Voice Characteristics**:
- Speech rate: Already optimized at 0.55 (line 16)
- Pitch multiplier: Already lowered to 0.6 (line 24)
- These settings work equally well with default and enhanced voices
- Enhanced voices will sound more natural but maintain calming, slower pace

---

## Maintenance Considerations

### iOS
- **OS Updates**: Apple occasionally adds new voices - minimal maintenance
- **API Stability**: AVSpeechSynthesizer is mature, stable API
- **Deprecation Risk**: Very low

### Android
- **TTS Engine Updates**: Google TTS app updates independently
- **API Stability**: Android TTS API stable since API 21
- **Fragmentation**: Some testing needed for new Android versions
- **Deprecation Risk**: Low (mature API)

---

## Alternative Approaches (Future Considerations)

### Custom Voice Integration
**Not recommended for v1** due to:
- Significant app size increase (200MB+ per voice)
- Licensing complexity
- Breaks offline-first, free model
- Development complexity much higher

### Third-Party TTS Services
**Not recommended** due to:
- Requires internet connection
- Subscription/API costs
- Against app philosophy
- Privacy concerns

### User-Recorded Voices
**Interesting future possibility**:
- Users record their own meditation voice
- Could be v2 or v3 feature
- Requires audio processing/normalization
- Storage considerations

---

## Success Metrics

**User Adoption**:
- % of users who enable enhanced voice
- % who download multiple voices
- Voice preference distribution

**Quality Metrics**:
- Meditation completion rates (enhanced vs. default)
- User ratings/reviews mentioning voice quality
- Support requests related to voice feature

**Technical Metrics**:
- Voice fallback frequency (indicates availability issues)
- Settings screen engagement
- Voice preview usage

---

## Conclusion

This feature is **highly feasible** on both platforms and aligns perfectly with the app's philosophy:

✅ Maintains free, offline, ad-free model
✅ Keeps app size under control
✅ Preserves default "artificial" aesthetic
✅ Gives power users professional quality
✅ Platform-native implementation
✅ Relatively simple to implement

**Recommendation**: Implement on iOS first (simpler), then Android with enhanced UX guidance.
