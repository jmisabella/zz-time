# Problems and Solutions

## 2025-12-13: App Store Compliance Review for Guided Meditations

### **THE QUESTIONS**
With the app now including 35 preset guided meditations and custom meditation functionality, needed to determine:

1. **Do any meditations violate Apple App Store or Google Play Store guidelines?**
2. **How to answer App Store's Health & Wellness content questions:**
   - Medical or Treatment Information (NONE/INFREQUENT/FREQUENT)
   - Health or Wellness Topics - self-care/lifestyle recommendations (YES/NO)
3. **Does PRIVACY.md need updates to reflect meditation features?**

### **ANALYSIS OF MEDITATIONS**

**Reviewed all 35 preset meditations plus default_custom_meditation.txt for guideline compliance.**

**Key Findings:**
- ✅ **NO medical claims** - Meditations never diagnose, treat, or cure any medical condition
- ✅ **NO medication guidance** - No pharmaceutical or supplement recommendations
- ✅ **NO emergency medical advice** - No instructions for urgent health situations
- ✅ **NO health data collection** - App remains fully offline, stores nothing
- ✅ **General wellness only** - Content focuses on mindfulness, breathing, relaxation
- ✅ **No prohibited health claims** - Anxiety/stress mentioned only as general wellness topics, not medical treatments
- ✅ **Appropriate disclaimers** - Meditations present techniques, not medical interventions

**Specific Content Review:**
- Meditations reference anxiety, stress, worry as **emotional states** (allowed)
- Breathing exercises are **self-care techniques** (allowed)
- Body scans, visualization, gratitude practices are **lifestyle/wellness** (allowed)
- Poetry/quotes from Wordsworth, Marcus Aurelius, Buddha, etc. are **educational** (allowed)
- No claims that meditation "treats" or "cures" medical conditions (compliant)

**Conclusion: All meditation content is App Store and Play Store compliant.**

### **APP STORE HEALTH & WELLNESS QUESTIONS - RECOMMENDED ANSWERS**

#### Question A: Medical or Treatment Information
**RECOMMENDED ANSWER: NONE**

**Rationale:**
- App provides **wellness/self-care content**, not medical treatment
- No diagnoses, no treatment protocols, no medication guidance
- Meditation is presented as a **relaxation technique**, not medical intervention
- Content doesn't replace or substitute for medical care
- No emergency medical information provided

#### Question B: Health or Wellness Topics (Self-care or lifestyle recommendations)
**RECOMMENDED ANSWER: YES**

**Rationale:**
- App **explicitly provides self-care recommendations** through guided meditations
- Content includes lifestyle recommendations: breathing techniques, mindfulness practices, relaxation methods
- This is the **accurate categorization** for meditation/wellness apps
- Similar to apps like Calm, Headspace, Insight Timer (all answer YES here)
- Examples of self-care content in app:
  - Box breathing techniques
  - Body scan meditations
  - Mindfulness practices
  - Stress management through meditation
  - Sleep preparation routines

**Important Distinction:**
- Question A (NONE) = No **medical/treatment** information
- Question B (YES) = Contains **wellness/self-care** information
- These answers are **compatible and correct** for a meditation app

### **PRIVACY POLICY REVIEW & RECOMMENDATIONS**

**Current Status:**
PRIVACY.md currently describes app as "Z Rooms" - ambient audio/white noise app only, with no mention of meditation features.

**RECOMMENDED UPDATES:**

**Update app description to include meditation functionality:**

**Current text (line 7):**
```
Download and use our mobile application (Z Rooms), an ambient audio and white noise app that allows users to select from various "rooms" with distinct color palettes and ambient audio tracks, featuring subtle animations, a duration timer (up to 8 hours), and optional alarms...
```

**RECOMMENDED replacement:**
```
Download and use our mobile application (Z Rooms), an ambient audio, white noise, and guided meditation app that allows users to select from various "rooms" with distinct color palettes and ambient audio tracks, 35 preset guided meditations, custom meditation creation tools, featuring subtle animations, a duration timer (up to 8 hours), and optional alarms...
```

**Add clarification about meditation data storage:**

**RECOMMENDED addition after line 7:**
```
The app includes guided meditation features with preset meditations and the ability to create custom meditations. All custom meditations are stored locally on your device only and are never transmitted, collected, or processed by us. Meditation content does not contain medical advice or treatment information.
```

**Update "Sensitive Information" section (line 55):**

**Current:**
```
We do not process sensitive information. Z Rooms does not collect or process any health-related data, such as sleep patterns, biometric information, or wellness metrics, as its functionality is limited to providing pre-programmed ambient audio and visual experiences.
```

**RECOMMENDED:**
```
We do not process sensitive information. Z Rooms does not collect or process any health-related data, such as sleep patterns, biometric information, or wellness metrics. While the app provides guided meditation and wellness content, all user-created custom meditations are stored locally on your device only and are never transmitted to us or any third party. The app operates entirely offline and does not track, monitor, or collect any data about your meditation practice or usage patterns.
```

**Key Privacy Points to Maintain:**
✅ App remains fully offline
✅ No data collection occurs
✅ Custom meditations stored locally only
✅ No health data tracking
✅ No transmission of user content
✅ No analytics or usage monitoring

### **SUMMARY OF RECOMMENDATIONS**

**1. App Store Guideline Compliance:** ✅ ALL CLEAR
   - No violations found in any meditation content
   - Safe to submit to both Apple App Store and Google Play Store

**2. App Store Health Questions:**
   - Question A (Medical/Treatment): **NONE**
   - Question B (Health/Wellness Topics): **YES**

**3. Privacy Policy Updates:**
   - Update app description to mention meditation features
   - Add clarification about local-only custom meditation storage
   - Emphasize no health data collection
   - Maintain current offline/no-tracking stance

**Files to Update:**
- PRIVACY.md (update lines 7, 55, and add meditation data clarification)

**Confidence Level:** High - Based on industry standards (Calm, Headspace, Insight Timer) and Apple/Google wellness app guidelines.

### **PRIVACY POLICY UPDATES COMPLETED**

**Date:** December 13, 2025

**Files Updated:**
- `PRIVACY.md` (iOS version)
- `PRIVACY_Android.md` (Android version)

**Changes Made:**

1. **App Description Updated (Line 7 in both files):**
   - **Before:** "ambient audio and white noise app"
   - **After:** "ambient audio, white noise, and guided meditation app"
   - **Added:** "35 preset guided meditations, custom meditation creation tools"
   - **Added:** Clarification that custom meditations stored locally only, never transmitted
   - **Added:** Disclaimer that meditation content contains no medical advice

2. **Sensitive Information Section Updated (Line 55 in both files):**
   - **Added:** Explicit statement that app provides guided meditation and wellness content
   - **Added:** Confirmation that user-created custom meditations are local-only storage
   - **Added:** Statement that app operates entirely offline
   - **Added:** Clarification that no data about meditation practice or usage patterns is collected

3. **Platform-Specific Clarifications:**
   - **iOS (PRIVACY.md):** References Background Mode for continuous audio playback
   - **Android (PRIVACY_Android.md):** References foreground services for continuous audio playback
   - **Android:** Added note about local storage permission for app data only

**Privacy Principles Maintained:**
- ✅ No data collection
- ✅ Offline-only operation
- ✅ No health data tracking
- ✅ Local storage only for user content
- ✅ No transmission of user information
- ✅ No analytics or monitoring

**Last Updated Date:** Changed to December 13, 2025 in both files

---

## 2025-12-11: TTS Pause Marker Bug

### **THE PROBLEM**
The iOS app's guided meditation feature was vocalizing pause markers instead of pausing silently. When meditation text contained `(14s)` for a 14-second pause, the TTS engine would speak "PAUSE EQUALS FOURTEEN THOUSAND" very loudly instead of pausing. This only occurred with certain pause durations (like 14 seconds) but not others (like 10 seconds).

### **ROOT CAUSES**
1. **iOS AVSpeechUtterance Bug**: `AVSpeechUtterance.postUtteranceDelay` has an undocumented bug where delay values exceeding approximately 10 seconds cause the TTS engine to vocalize the delay duration instead of pausing silently.

2. **Pause Marker Not Properly Removed**: Although pause extraction logic existed, there were edge cases where pause markers like `(14s)` weren't being completely stripped from the text before being passed to `AVSpeechUtterance`, allowing iOS to attempt to speak them.

### **THE SOLUTION**
**Two-part fix:**

1. **Removed all pause markers from spoken text** with multiple layers of regex cleaning:
   - Primary cleaning during phrase extraction
   - Secondary "ultra-clean" pass before creating utterances
   - Applied regex `\(\d+(?:\.\d+)?[sm]\)` to strip all pause notation

2. **Replaced `postUtteranceDelay` with silent utterances** to create pauses:
   - Don't use `postUtteranceDelay` on main speech utterances
   - After each phrase, queue silent utterances (text = " ", volume = 0.0)
   - Break long pauses into 5-second chunks to avoid the iOS bug
   - Set `postUtteranceDelay` only on these silent utterances

This workaround completely avoids the iOS bug while maintaining proper pause functionality.

**Files Modified:**
- `zz-time/Views/Components/TextToSpeechManager.swift`

**Version:** Fixed in build 2.1.2 (build #2)

---
