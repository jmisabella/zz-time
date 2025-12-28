# NEW BUGS

## 2025-12-28, 10:37

### Title
Rapid Changing Meditations Causes Subsequent Meditations To Stop Loading/Playing, Either Via Toggling On/Off/On Or Long-Pressing of Leaf Button

### Description
Desired use case is that a user toggles on the Leaf button to play a random meditation but dislikes the initially selected meditation and wishes for a different random meditation to play. User either toggles off the Leaf button and toggles it back on to play a different random meditation, or uses the long-press feature on the Leaf button to play a new random meditation without needing to toggle the Leaf off and back on. 

For both of these methods, there is a bug. After the first meditation, sometimes on the 2nd, 3rd, or even 5th attempt at a different meditation, be it via retoggling the Leaf or by long-pressing the Leaf, eventually a new random meditation does not play, causing the closed captioning modal window to display and the Leaf button to be toggled on (green) but with no meditation playing. 

We actually had attempted to resolve this issue before but failed at several attempts. Actually this is why we added the long-press feature: it was a futile attempt to allow the desired use case from a different means of toggline on/off/on, however the same bug appears to be affecting both the toggling on/off/on as well as the long-press methods of playing new random meditations. However, before we were having issues seeing the debug logging output in XCode, an issue we have since resolved and now have ability to use debug logging to troubleshoot this issue. Also, we added a feature to prevent the same meditation from ever playing twice in a row. I wonder if this feature may be unnecessarily adding additional surface area to our problem and whether we should consider removing that feature while we work through this bug which I feel is more important to solve than that we prevent same meditation from being able to play twice in a row. 

---

# OLD BUGS

OLD OR ABANDONED BUGS ARE BELOW, PLEASE IGNORE THESE UNLESS EXPLICITLY TOLD TO INVESTIGATE THESE:

# Bug Report: Voice Selection Issues

## Bug #-1: Meditation Replay Bug (SHELVED - Low Priority)

**Reported:** 2025-12-27
**Status:** SHELVED - Occurs infrequently (around 5th toggle), low priority

### Description
After toggling the Leaf button on/off multiple times (approximately 5 times), the meditation occasionally fails to play when re-toggling the Leaf button on.

### Steps to Reproduce
1. Click Leaf button to play meditation → works ✓
2. Click Leaf button to stop meditation → works ✓
3. Click Leaf button to play meditation → works ✓
4. Repeat steps 2-3 several more times
5. On approximately the 5th toggle, meditation fails to play

### Frequency
Intermittent - does not occur on 1st or 2nd toggle, typically appears around the 5th toggle

### Impact
**LOW** - Bug occurs infrequently and only after multiple toggles. Users can typically work around it by clicking the Leaf button again.

### Notes
- This is a recurring regression bug that has been fixed multiple times (see change_log.md entries from 2025-12-25 and 2025-12-26)
- The fix from 2025-12-25 16:00 (checking `isSpeaking` instead of `isPlayingMeditation`) is in place
- May be related to race conditions or delayed callbacks from AVSpeechSynthesizer
- Shelved for now to focus on higher priority features and more reproducible bugs

---

## Historical Bug Report (2025-12-26)

2025-12-27
Please check the context.md and change_log.md and README.md. There is a bug: from ExpandingView, I click the Leaf button to play a random meditation. Then I untoggle the Leaf button to disable meditation. I then re-toggle the Leaf button, expecing a different random meditation but when retoggling the Leaf button, usually the meditation does not play and then stops working from then onwards. If I retoggle the Leaf button too many times, often only a 2nd time, then it seems to stop working at triggering the meditation voice. Please check this. Now, specifically, I believe this is a bug we solved at least once or twice in the change_log.md but it seems to keep coming bacvk as we do further edeevelopment, apparently a regression. We had solved this before, but somehow I believe that work we did on 12/25 and 12/26 may have reintroduced this bug. Please help me with this.

**Date:** 2025-12-26
**Platform:** iOS
**App:** zz-time meditation app

---

## Bug #0: Voice Selection Not Persisting (CRITICAL)

**Reported:** 2025-12-26 15:57

### Description
Voice selection in Voice Settings is **completely broken**. When user selects a voice, it does not persist. The selection immediately disappears and meditations always play in Samantha's voice.

### Exact Steps to Reproduce
1. Open Voice Settings
2. Select a voice (e.g., Aaron)
3. Click "Done" to exit Voice Settings
4. Observation: When reopening Voice Settings, **NO voice is selected** (checkmark is gone)
5. Click the green Leaf button to play a meditation
6. Observation: Meditation plays in **Samantha's voice**, not the selected voice

### Additional Observations
- The voice selection does NOT persist even momentarily
- Going back into Voice Settings immediately after selecting shows no selection
- Multiple app reinstalls, cache clears, and rebuilds do not fix the issue
- This bug did NOT occur earlier in the evening - something changed

### Impact
**CRITICAL** - Voice selection feature is completely non-functional. Users cannot select their preferred meditation voice.

### Context
This bug appeared after removing debug popups from the codebase. Prior to removing debug code, voice selection was working correctly (after fixing the Xcode scheme command-line arguments issue).

---

## Bug #1: Random Voice Selection Always Returns Samantha

### Description
After deleting and reinstalling the app, the random voice selection feature **always** selects the same voice (Samantha - `com.apple.voice.compact.en-US.Samantha`) instead of randomly selecting from the available meditation-appropriate voices.

### Expected Behavior
On fresh install (first-time user with no saved voice preference), the app should randomly select a voice from all available meditation-appropriate English voices (excluding 26 novelty/robotic voices from the exclusion list).

### Actual Behavior
Every fresh install consistently selects Samantha (system default voice), never any other voice.

### User Environment
- User has **0 enhanced/premium voices** downloaded
- User has approximately **47 compact/default quality voices** available
- Testing performed in iOS Simulator via Xcode

### Attempted Fixes (All Failed)

#### Fix Attempt #1: Include All Voice Qualities
**Change:** Modified `getMeditationAppropriateVoices()` to include ALL voice qualities (compact, enhanced, premium) instead of filtering for only enhanced/premium.

**Reasoning:** User had no enhanced/premium voices, so filtering was returning empty array, causing fallback to system default.

**Result:** FAILED - Still returns Samantha every time.

#### Fix Attempt #2: Array Shuffling
**Change:** Changed random selection from `randomElement()` to `shuffled()[0]`

**Reasoning:** `AVSpeechSynthesisVoice.speechVoices()` returns voices in consistent order. Using `randomElement()` or `Int.random(in: range)` might not provide true randomness across app reinstalls.

**Code:**
```swift
let shuffledVoices = meditationVoices.shuffled()
let randomVoice = shuffledVoices[0]
```

**Result:** FAILED - Still returns Samantha every time.

### Technical Details

**Current Implementation (VoiceManager.swift:65-96):**
```swift
func getPreferredVoice() -> AVSpeechSynthesisVoice? {
    // Check if user explicitly selected system default
    if let identifier = preferredVoiceIdentifier {
        if identifier == "SYSTEM_DEFAULT" {
            return AVSpeechSynthesisVoice(language: "en-US")
        }

        // Try to get the user's preferred voice
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
    }

    // For first-time users: randomly select from meditation-appropriate voices
    let meditationVoices = getMeditationAppropriateVoices()

    if !meditationVoices.isEmpty {
        // SHUFFLE the array to ensure true randomness across app reinstalls
        // The voices are always returned in the same order, so we must shuffle
        let shuffledVoices = meditationVoices.shuffled()
        let randomVoice = shuffledVoices[0]

        // Save this as the user's preferred voice so they get consistency
        preferredVoiceIdentifier = randomVoice.identifier

        return randomVoice
    }

    // Final fallback to system default if no voices available (should never happen)
    preferredVoiceIdentifier = "SYSTEM_DEFAULT"
    return AVSpeechSynthesisVoice(language: "en-US")
}
```

### Possible Root Causes (Not Yet Explored)

1. **UserDefaults Persistence in Simulator:** UserDefaults might persist across "delete and reinstall" in iOS Simulator, preventing true fresh install testing.

2. **Random Seed Determinism:** Swift's random number generator might use a deterministic seed in the simulator environment, causing `shuffled()` to produce the same shuffle order on each app launch.

3. **Timing/Lifecycle Issue:** Voice selection might be happening at the wrong point in the app lifecycle, potentially before the voice list is fully populated.

4. **Saved Preference Not Clearing:** The `preferredVoiceIdentifier` UserDefaults value might not actually be getting cleared on app deletion in the simulator.

5. **Array Order Issue:** The array might already be in a specific order where Samantha is consistently at a certain position, and the shuffle isn't working as expected.

### Debug Data from User Test
```
VOICE DEBUG INFO

Saved Preference:

Current Voice: Samantha
ID: com.apple.voice.compact.en-US.Samantha
Quality: 1

Total English voices: 47

Enhanced/Premium: 0

Meditation-appropriate: 47
```

### Recommendations for Next Debugging Session

1. **Test UserDefaults clearing:** Manually clear all UserDefaults in the app to ensure truly fresh state
2. **Add logging for shuffle results:** Log the first 10 voices before and after shuffle to verify shuffle is working
3. **Test on physical device:** Verify behavior on actual iOS device vs simulator
4. **Seed randomness explicitly:** Try explicitly seeding the random number generator
5. **Verify array contents:** Confirm all 47 voices are in the meditation-appropriate array and Samantha's position
6. **Check UserDefaults before selection:** Verify that `preferredVoiceIdentifier` is actually `nil` before random selection occurs

---

## Bug #2: Meditation Replay Bug (Intermittent)

### Description
After starting a meditation (clicking the Leaf button), then stopping it (clicking Leaf again), clicking the Leaf button a third time to start a new meditation fails approximately 50% of the time. The meditation doesn't play, but sometimes it does work correctly.

### Expected Behavior
User should be able to:
1. Click Leaf → meditation starts
2. Click Leaf → meditation stops
3. Click Leaf → NEW meditation starts (random selection)

This cycle should work reliably 100% of the time.

### Actual Behavior
Step 3 fails approximately 50% of the time - clicking Leaf does nothing, meditation doesn't start. Other times, it works correctly and plays a new random meditation.

### Attempted Fix (Failed)

**Change:** Modified Leaf button logic to check `ttsManager.isSpeaking` instead of `ttsManager.isPlayingMeditation`

**Reasoning:**
- `isPlayingMeditation` flag stays `true` after meditation completes naturally
- Button was checking `isPlayingMeditation`, so it would call `stopSpeaking()` instead of starting new meditation
- Calling `stopSpeaking()` when nothing is playing does nothing

**Code Change (ExpandingView.swift:190-199):**
```swift
Button {
    // Check if actually speaking - if not, start new meditation
    // (isPlayingMeditation can be true after completion while isSpeaking is false)
    if ttsManager.isSpeaking {
        ttsManager.stopSpeaking()
    } else {
        guard let text = ttsManager.getRandomMeditation()
        else { return }

        ttsManager.startSpeakingWithPauses(text)
    }
} label: {
```

**Result:** FAILED - Still intermittent, works ~50% of the time.

### Technical Details

**State Management (TextToSpeechManager.swift:541-554):**
```swift
// Only stop when all utterances are done
if queuedUtteranceCount <= 0 {
    isSpeaking = false
    // Keep isPlayingMeditation = true so the leaf stays green after completion
    // This allows user to see that meditation completed successfully
    // User can manually toggle leaf off if desired
    isCustomMode = false
    queuedUtterance = 0
    currentPhrase = ""
    previousPhrase = ""

    // Mark that a meditation completed successfully (for wake-up greeting feature)
    UserDefaults.standard.set(true, forKey: "meditationCompletedSuccessfully")
}
```

**Flag States:**
- `isSpeaking`: Set to `true` when TTS starts, `false` when TTS actually stops
- `isPlayingMeditation`: Set to `true` when meditation starts, **stays true** after completion

### Possible Root Causes (Not Yet Explored)

1. **Race Condition:** There may be a timing issue between button clicks and state updates. The `isSpeaking` flag might not be updated immediately when stopping, causing the button to think speech is still active.

2. **Synthesizer State Mismatch:** The `AVSpeechSynthesizer` internal state might not match our tracked `isSpeaking` flag, possibly due to asynchronous delegate callbacks.

3. **Delegate Callback Timing:** The `didFinish` delegate callback that sets `isSpeaking = false` might not have fired yet when the user clicks the button again.

4. **Queue Count Issues:** The `queuedUtteranceCount` might not be properly reset to 0, causing `isSpeaking` to remain true even when nothing is playing.

5. **Multiple Synthesizer Instances:** If there are multiple synthesizer instances (main meditation + preview), they might be interfering with each other's state.

### Recommendations for Next Debugging Session

1. **Add state logging:** Log `isSpeaking`, `isPlayingMeditation`, and `queuedUtteranceCount` values on each button click
2. **Add delegate logging:** Log all synthesizer delegate callbacks (`didStart`, `didFinish`, `didCancel`) to track state changes
3. **Test stop completion:** Verify that `stopSpeaking()` actually completes before allowing next start
4. **Add synchronization:** Consider using a dispatch queue or semaphore to ensure state updates complete before next action
5. **Reset state explicitly:** On stop, explicitly reset ALL state flags to known values
6. **Check for hanging utterances:** Verify `queuedUtteranceCount` is actually reaching 0

---

## Files Modified During Debugging

### VoiceManager.swift
**Path:** `zz-time/Views/Components/VoiceManager.swift`

**Changes:**
- Modified `getMeditationAppropriateVoices()` to include all voice qualities
- Changed random selection from `randomElement()` to `shuffled()[0]`
- Removed all debug logging (print statements)

### VoiceSettingsView.swift
**Path:** `zz-time/Views/VoiceSettingsView.swift`

**Changes:**
- Removed debug button from toolbar
- Removed `generateDebugInfo()` function
- Removed debug alert and state variables

### ExpandingView.swift
**Path:** `zz-time/Views/ExpandingView.swift`

**Changes:**
- Changed Leaf button logic from `isPlayingMeditation` to `isSpeaking`
- Removed debug alert showing voice selection info
- Removed debug state variables

---

## Summary

Both bugs remain **UNSOLVED** after multiple debugging attempts. The root causes have not been definitively identified. Fresh debugging session recommended with focus on:

1. **Bug #1:** UserDefaults persistence, random seed initialization, and array shuffling verification
2. **Bug #2:** State synchronization, delegate callback timing, and race condition analysis

All debugging code has been removed from the codebase. The attempted fixes remain in place as they were logical improvements, even though they did not solve the issues.
