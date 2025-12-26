# Android Implementation Guide: Voice Refactor Changes

**Date:** 2025-12-26
**Purpose:** Guide for implementing iOS voice selection refactor changes in the Android version of zz-time meditation app

---

## Overview of Changes

The iOS app underwent a major voice selection refactor that removed the "Enhanced Voice" toggle and implemented a unified voice picker with random voice selection for first-time users. This document details the design changes and implementation strategy for Android.

---

## Design Philosophy

### Before the Refactor
- **Enhanced Voice Toggle:** OFF by default
- **First-time user experience:** System default voice only
- **Voice selection:** Hidden behind toggle + gear icon
- **Voice filtering:** Only enhanced/premium voices shown when toggle ON
- **User friction:** Multiple steps to discover and enable enhanced voices

### After the Refactor
- **No toggle:** All voices treated equally
- **First-time user experience:** Random meditation-appropriate voice selected automatically
- **Voice selection:** Single unified voice list accessible via gear icon
- **Voice filtering:** 26 novelty/robotic voices excluded from ALL offerings
- **User experience:** Zero-friction voice selection, cleaner UI

---

## Key Components

### 2. Random Voice Selection for First-Time Users

**Purpose:** Automatically select a meditation-appropriate voice on first app launch

**Implementation Strategy:**

```kotlin
fun getPreferredVoice(): Voice? {
    // Check if user explicitly selected system default
    val identifier = preferredVoiceIdentifier
    if (identifier == "SYSTEM_DEFAULT") {
        return getSystemDefaultVoice()
    }

    // Try to get user's saved preferred voice
    if (identifier != null) {
        val voice = getVoiceByIdentifier(identifier)
        if (voice != null) {
            return voice
        }
    }

    // For first-time users: randomly select from meditation-appropriate voices
    val meditationVoices = getMeditationAppropriateVoices()

    if (meditationVoices.isNotEmpty()) {
        // SHUFFLE the array to ensure true randomness across app reinstalls
        val randomVoice = meditationVoices.shuffled().first()

        // Save this as the user's preferred voice for consistency
        preferredVoiceIdentifier = randomVoice.identifier

        return randomVoice
    }

    // Final fallback to system default if no voices available
    preferredVoiceIdentifier = "SYSTEM_DEFAULT"
    return getSystemDefaultVoice()
}
```

**Critical Implementation Notes:**

1. **Shuffle the array** - Android's `TextToSpeech.getVoices()` returns voices in consistent order
2. **Save the selection** - Store `preferredVoiceIdentifier` immediately so user gets same voice next time
3. **Use SharedPreferences** - Store voice preference persistently

---

### 3. Meditation-Appropriate Voice Discovery

**Purpose:** Get all English voices suitable for meditation (excludes novelty voices)

**Implementation:**

```kotlin
fun getMeditationAppropriateVoices(): List<Voice> {
    val tts = TextToSpeech(context, null)

    // Get ALL English voices (includes default, enhanced, and premium quality)
    val allEnglishVoices = tts.voices.filter {
        it.locale.language == "en"
    }

    // Filter out excluded novelty voices
    val meditationVoices = allEnglishVoices.filter {
        !isVoiceExcluded(it)
    }

    return meditationVoices
}
```

**Quality Levels:**
- Include ALL quality levels (not just enhanced/premium)
- User might only have default quality voices on their device
- Falling back to system default should only happen if NO voices are available

---

### 4. Voice Settings UI Redesign

**Purpose:** Unified voice picker without toggle friction

### Remove Enhanced Voice Toggle

**Before:**
```xml
<!-- Remove this entire section -->
<Switch
    android:id="@+id/enhancedVoiceToggle"
    android:text="Enhanced Voice"
    android:checked="false" />
```

**After:**
```
No toggle - directly show voice list
```

### "About Voices" Section - Move to Top

**Purpose:** Educate users BEFORE they see the voice list

**Location:** First item in Voice Settings screen, ABOVE the voice selection list

**Content:**
```xml
<LinearLayout>
    <TextView
        android:text="About Voices"
        android:textStyle="bold" />

    <TextView android:text="• Many enhanced voices come pre-installed on newer devices" />
    <TextView android:text="• Some voices may require download (100-500MB each)" />
    <TextView android:text="To download or delete voices:" />
    <TextView android:text="Settings → Accessibility → Text-to-speech → Preferred engine → Settings" />
</LinearLayout>
```

### Voice List Structure

**Display Order:**
1. Enhanced/Premium voices (sorted by quality, then name)
2. Default quality voices (if no enhanced voices available)
3. System Default option (at bottom with special badge)

**Voice Row Components:**
```xml
<LinearLayout>
    <!-- Voice name with region -->
    <TextView text="Samantha (US)" />

    <!-- Quality badge -->
    <Chip
        text="Enhanced"
        backgroundColor="@color/green" />

    <!-- Download status (for non-default voices) -->
    <TextView
        text="May need download"
        textColor="@color/orange" />

    <!-- Preview button -->
    <ImageButton
        src="@drawable/ic_play"
        contentDescription="Preview voice" />

    <!-- Selection indicator -->
    <ImageView
        src="@drawable/ic_checkmark"
        visibility="visible|gone" />
</LinearLayout>
```

### System Default Voice Row

**Purpose:** Explicit option to use system default voice

**Implementation:**
```xml
<LinearLayout>
    <TextView text="System Default" />

    <Chip
        text="Built-in"
        backgroundColor="@color/gray" />

    <TextView text="Always available" />

    <ImageButton
        src="@drawable/ic_play"
        contentDescription="Preview voice" />

    <ImageView
        src="@drawable/ic_checkmark"
        visibility="visible|gone" />
</LinearLayout>
```

**Special Identifier:** Use `"SYSTEM_DEFAULT"` string instead of voice identifier

---

### 5. Voice Preview Functionality

**Purpose:** Let users hear voice samples before selecting

**Implementation:**

```kotlin
private var previewTts: TextToSpeech? = null
private var previewingVoiceId: String? = null

fun previewVoice(voice: Voice) {
    // Stop any currently playing preview
    previewTts?.stop()
    previewTts?.shutdown()

    // Pause meditation if it's playing
    val wasMeditationPlaying = meditationTts.isSpeaking
    if (wasMeditationPlaying) {
        meditationTts.stop()
    }

    previewingVoiceId = voice.identifier

    // Create new TTS instance for preview
    previewTts = TextToSpeech(context) { status ->
        if (status == TextToSpeech.SUCCESS) {
            previewTts?.voice = voice

            // Use same speech rate logic as meditation
            val speechRate = getSpeechRateMultiplier(voice)
            previewTts?.setSpeechRate(speechRate)

            // Use same volume as meditation
            val params = Bundle()
            params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, meditationVolume)

            previewTts?.speak(
                "Welcome to your meditation practice. Find a comfortable position and take a deep breath.",
                TextToSpeech.QUEUE_FLUSH,
                params,
                "preview"
            )
        }
    }
}

fun stopPreview() {
    previewTts?.stop()
    previewTts?.shutdown()
    previewTts = null
    previewingVoiceId = null

    // Resume meditation if it was playing before preview
    // (implementation depends on your meditation playback system)
}
```

**Preview Button States:**
- Play icon (blue) when not previewing
- Stop icon (red) when currently previewing that voice
- Clicking stop immediately halts preview

---

### 6. Speech Rate Logic

**Purpose:** Different voice qualities sound best at different speeds

**Implementation:**

```kotlin
fun getSpeechRateMultiplier(voice: Voice?): Float {
    if (voice == null) {
        return 0.8f  // Default for null voice
    }

    // Enhanced and Premium voices sound better at normal speed
    return when (voice.quality) {
        Voice.QUALITY_VERY_HIGH, // Premium
        Voice.QUALITY_HIGH ->     // Enhanced
            1.0f
        else ->                   // Default quality
            0.8f
    }
}
```

**Usage:**
```kotlin
val voice = getPreferredVoice()
val speechRate = getSpeechRateMultiplier(voice)
tts.setSpeechRate(speechRate)
```

---

## Android-Specific Considerations

### 1. Voice Quality Mapping

Android uses different quality constants than iOS:

| iOS Quality | Android Quality |
|------------|----------------|
| `.default` | `Voice.QUALITY_NORMAL` |
| `.enhanced` | `Voice.QUALITY_HIGH` |
| `.premium` | `Voice.QUALITY_VERY_HIGH` |

### 2. Voice Availability Detection

Android doesn't provide a direct API to check if a voice is downloaded:

```kotlin
fun isVoiceAvailable(voice: Voice): Boolean {
    // Default quality voices are always available
    if (voice.quality == Voice.QUALITY_NORMAL) {
        return true
    }

    // For enhanced/premium voices, Android will automatically prompt
    // to download when first used
    return false  // Assume may need download
}
```

### 3. Voice Download Prompts

Android handles voice downloads differently than iOS:
- System prompts user to download via Google Play or TTS engine settings
- No in-app download UI needed
- User directed to: Settings → Accessibility → Text-to-speech

### 4. SharedPreferences Keys

**Voice preference storage:**
```kotlin
private val PREFS_NAME = "VoicePreferences"
private val KEY_PREFERRED_VOICE_IDENTIFIER = "preferredVoiceIdentifier"

fun saveVoicePreference(identifier: String) {
    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    prefs.edit().putString(KEY_PREFERRED_VOICE_IDENTIFIER, identifier).apply()
}

fun loadVoicePreference(): String? {
    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    return prefs.getString(KEY_PREFERRED_VOICE_IDENTIFIER, null)
}
```

---

## Implementation Checklist

### Phase 1: Voice Manager Setup
- [ ] Create `VoiceManager.kt` singleton class
- [ ] Implement voice exclusion list (26 voices)
- [ ] Implement `isVoiceExcluded()` method
- [ ] Implement `getMeditationAppropriateVoices()` method
- [ ] Implement `getPreferredVoice()` with random selection logic
- [ ] Implement `getSpeechRateMultiplier()` method
- [ ] Add SharedPreferences for voice preference persistence

### Phase 2: UI Refactor
- [ ] Remove Enhanced Voice toggle from Voice Settings
- [ ] Move "About Voices" section to TOP of Voice Settings
- [ ] Update "About Voices" content for Android paths
- [ ] Redesign voice list to show all voices
- [ ] Add System Default voice row at bottom
- [ ] Implement quality badges (Default/Enhanced/Premium)
- [ ] Add download status indicators

### Phase 3: Voice Preview
- [ ] Implement preview TTS instance (separate from meditation)
- [ ] Add preview/stop button functionality
- [ ] Implement meditation pause during preview
- [ ] Implement meditation resume after preview
- [ ] Use same speech rate and volume as meditation

### Phase 4: Integration
- [ ] Update meditation playback to use `VoiceManager.getPreferredVoice()`
- [ ] Apply speech rate multiplier to meditation TTS
- [ ] Test random voice selection on fresh install
- [ ] Test voice persistence across app restarts
- [ ] Test voice preview functionality

### Phase 5: Testing
- [ ] Test with devices that have only default voices
- [ ] Test with devices that have enhanced voices
- [ ] Test voice exclusion (verify novelty voices are hidden)
- [ ] Test random voice selection on fresh install
- [ ] Test voice preview pause/resume
- [ ] Test System Default selection

---

## File Structure

**New Files to Create:**
```
app/src/main/java/com/yourapp/
├── managers/
│   └── VoiceManager.kt
└── ui/
    └── VoiceSettingsActivity.kt (or Fragment)
```

**Existing Files to Modify:**
```
app/src/main/java/com/yourapp/
├── managers/
│   └── TextToSpeechManager.kt
└── ui/
    └── MainActivity.kt
```

**Layout Files:**
```
app/src/main/res/layout/
├── activity_voice_settings.xml
├── item_voice_row.xml
└── item_system_default_voice.xml
```

---

## Critical Implementation Notes

### 1. MUST Include All Voice Qualities

**Do NOT filter for only enhanced/premium voices**

```kotlin
// ❌ WRONG - This breaks for users without enhanced voices
fun getMeditationAppropriateVoices(): List<Voice> {
    return tts.voices.filter {
        it.locale.language == "en" &&
        (it.quality == Voice.QUALITY_HIGH || it.quality == Voice.QUALITY_VERY_HIGH)
    }
}

// ✅ CORRECT - Include ALL qualities
fun getMeditationAppropriateVoices(): List<Voice> {
    return tts.voices.filter {
        it.locale.language == "en" && !isVoiceExcluded(it)
    }
}
```

**Why:** Users might only have default quality voices on their device. Filtering out default quality voices results in empty array, falling back to system default without randomness.

### 2. MUST Shuffle the Voice Array

**Do NOT use `.random()` directly**

```kotlin
// ❌ WRONG - May not be truly random across reinstalls
val randomVoice = meditationVoices.random()

// ✅ CORRECT - Shuffle ensures randomness
val randomVoice = meditationVoices.shuffled().first()
```

**Why:** `TextToSpeech.getVoices()` returns voices in consistent order. Using `.random()` or `Random().nextInt()` might use deterministic seeding, causing same voice to be selected on each fresh install.

### 3. MUST Save Voice Preference Immediately

```kotlin
// Save preference right after random selection
val randomVoice = meditationVoices.shuffled().first()
preferredVoiceIdentifier = randomVoice.identifier  // Save immediately
return randomVoice
```

**Why:** If preference isn't saved, next meditation will re-run random selection, causing inconsistent voice usage.

### 4. "About Voices" MUST Be at Top

**Location:** First item in Voice Settings, ABOVE voice list

**Why:** Users need to understand voice download requirements BEFORE they see the voice list. This reduces confusion about "May need download" indicators.

---

## Testing Strategy

### Test Case 1: Fresh Install (No Voices Downloaded)
**Steps:**
1. Uninstall app completely
2. Clear app data
3. Reinstall app
4. Start meditation without opening Voice Settings

**Expected:**
- Random voice selected from available default quality voices
- Meditation plays with selected voice
- Voice Settings shows selected voice with checkmark
- NO system default unless it was randomly selected

### Test Case 2: Fresh Install (Enhanced Voices Available)
**Steps:**
1. Uninstall app
2. Download enhanced voices via Android TTS settings
3. Reinstall app
4. Start meditation

**Expected:**
- Random voice selected from ALL meditation-appropriate voices (including enhanced)
- Higher probability of enhanced voice being selected (more voices in pool)

### Test Case 3: Voice Persistence
**Steps:**
1. Open Voice Settings
2. Select a specific voice
3. Close app completely
4. Reopen app
5. Start meditation

**Expected:**
- Same voice used as previously selected
- Voice Settings shows checkmark on previously selected voice

### Test Case 4: Preview Functionality
**Steps:**
1. Start meditation
2. Open Voice Settings during meditation
3. Click preview on different voice
4. Click stop on preview
5. Close Voice Settings

**Expected:**
- Meditation pauses when preview starts
- Preview plays sample text
- Preview stops when stop button clicked
- Meditation resumes after preview stops

### Test Case 5: Voice Exclusion
**Steps:**
1. Install Android TTS engine that includes novelty voices
2. Open Voice Settings
3. Scroll through voice list

**Expected:**
- NO novelty voices visible (Albert, Bad News, Bells, Boing, etc.)
- Only meditation-appropriate voices shown

---

## Migration Notes

**User Experience Impact:**

**For existing users who had Enhanced Voice toggle OFF:**
- First app launch after update → random voice selected
- Might be different from system default they were used to
- Acceptable trade-off for better UX

**For existing users who had Enhanced Voice toggle ON:**
- Their selected voice preference should be preserved
- No change to their experience

**For all users:**
- "About Voices" now visible at top (was previously buried)
- No toggle to manage
- Cleaner, simpler UI

---

## Common Pitfalls to Avoid

### ❌ Pitfall #1: Filtering Out Default Quality Voices
```kotlin
// DON'T DO THIS
val voices = allVoices.filter {
    it.quality == Voice.QUALITY_HIGH || it.quality == Voice.QUALITY_VERY_HIGH
}
```
**Result:** Empty array on devices without enhanced voices, breaks random selection

### ❌ Pitfall #2: Not Shuffling the Array
```kotlin
// DON'T DO THIS
val randomVoice = meditationVoices.random()
```
**Result:** May select same voice on every fresh install

### ❌ Pitfall #3: Saving Preference Later
```kotlin
// DON'T DO THIS
val randomVoice = meditationVoices.shuffled().first()
return randomVoice
// Save preference somewhere else later
```
**Result:** Preference might not be saved, causing inconsistent voice selection

### ❌ Pitfall #4: Forgetting to Exclude Novelty Voices
```kotlin
// DON'T DO THIS
val voices = tts.voices.filter { it.locale.language == "en" }
```
**Result:** Users see and can select inappropriate voices like "Bad News" or "Boing"

### ❌ Pitfall #5: Using Same TTS Instance for Preview
```kotlin
// DON'T DO THIS
fun previewVoice(voice: Voice) {
    meditationTts.voice = voice  // Changes meditation voice!
    meditationTts.speak(...)
}
```
**Result:** Changes meditation voice mid-session, might crash or cause audio overlap

---

## Summary

**Key Changes for Android:**
1. ✅ Remove Enhanced Voice toggle entirely
2. ✅ Move "About Voices" section to TOP of Voice Settings
3. ✅ Implement centralized voice exclusion (26 novelty voices)
4. ✅ Random voice selection for first-time users (ALL qualities)
5. ✅ Shuffle voice array for true randomness
6. ✅ Add System Default as explicit option at bottom
7. ✅ Implement voice preview with pause/resume
8. ✅ Use quality-based speech rate multipliers

**Benefits:**
- Cleaner, simpler UI
- Better first-time user experience
- No hidden features behind toggles
- Consistent voice selection across sessions
- Filtered voice list (no novelty voices)

**Files to Create:**
- `VoiceManager.kt`
- `VoiceSettingsActivity.kt` (or Fragment)
- Layout XMLs for voice picker UI

**Files to Modify:**
- `TextToSpeechManager.kt` (use VoiceManager)
- Existing meditation playback code
- Voice Settings UI layouts
