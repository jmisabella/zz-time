# Adding New Stories to Z Rooms iOS App

This guide explains the procedure for adding new story collections to the Z Rooms iOS app.

## Overview

The Z Rooms app uses Xcode's **File System Synchronized Root Group** feature for the `TTSContent` folder. This means files in `TTSContent` are automatically discovered at build time, **BUT** you must explicitly list which files to include in the app bundle by adding them to the `membershipExceptions` list in the `project.pbxproj` file.

## Why This Is Needed

**Problem:** Simply creating files in `zz-time/TTSContent/YourStory/` won't make them appear in the app.

**Root Cause:** The TTSContent folder uses Xcode's "File System Synchronized Root Group" feature, which includes a `membershipExceptions` list that explicitly controls which files are bundled with the app.

**Solution:** You must manually edit `project.pbxproj` to add your story's files to the exception list.

---

## Step-by-Step Procedure

### 1. Create Your Story Files

Create a new directory structure under `zz-time/TTSContent/`:

```
zz-time/TTSContent/YourStoryName/
├── Poems/
│   ├── 01_first_poem.txt
│   ├── 02_second_poem.txt
│   └── ...
└── Stories/
    ├── 01_chapter_1.txt
    ├── 02_chapter_2.txt
    └── ...
```

**Naming Requirements:**
- Files MUST start with digits followed by an underscore: `01_`, `02_`, etc.
- Files MUST have `.txt` extension
- The digits determine the sequence order (01 = first, 02 = second, etc.)
- The part after the underscore can be anything descriptive
- Poems can use any naming (e.g., `preset_poem1.txt` or `01_custom_name.txt`)

**Examples:**
- ✅ `01_prelude.txt`
- ✅ `02_chapter_2.txt`
- ✅ `01_seventeen_thousand_years.txt`
- ✅ `preset_poem1.txt`
- ❌ `prelude.txt` (missing sequence number)
- ❌ `chapter_01.txt` (sequence number not at start)

### 2. Edit project.pbxproj

**CRITICAL:** This is the step that makes your files appear in the app.

1. Open `zz-time.xcodeproj/project.pbxproj` in a text editor
2. Find the `PBXFileSystemSynchronizedBuildFileExceptionSet` section (around line 148-194)
3. Locate the `membershipExceptions = (` line
4. Add your story files to this list, following the existing pattern

**Example Addition:**

```
membershipExceptions = (
    Signal_Decay/Poems/preset_poem1.txt,
    ... (existing entries) ...
    The_Eighteen_Paradox/Stories/11_chapter_11_amalgamation.txt,
    YourStoryName/Poems/01_first_poem.txt,        ← ADD YOUR FILES HERE
    YourStoryName/Poems/02_second_poem.txt,
    YourStoryName/Stories/01_chapter_1.txt,
    YourStoryName/Stories/02_chapter_2.txt,
);
```

**Important Notes:**
- Paths are relative to the `TTSContent` folder
- Each entry MUST end with a comma
- Use the exact filenames (case-sensitive)
- List ALL poem and story files for your collection
- Maintain alphabetical or logical ordering for clarity

### 3. Build and Test

1. Open the Xcode project: `zz-time.xcodeproj`
2. Build the project (⌘B)
3. Run the app in the simulator or on a device
4. Navigate to the story selection screen
5. Verify your new story appears with correct chapter/poem counts

**Verification:**
- Story name should appear in the story selector
- Chapter count should match the number of story files you added
- Poem count should match the number of poem files you added
- Tapping the story should show it as the active story
- Story playback should work correctly

---

## How the App Discovers Stories

The app automatically scans the `TTSContent` directory at runtime:

1. **StoryCollectionManager** scans for subdirectories under `TTSContent/`
2. For each subdirectory, it looks for `Stories/` and `Poems/` folders
3. It collects all `.txt` files in these folders
4. Sequence numbers are extracted from filenames (the `01`, `02` part)
5. Files are sorted by sequence number for playback order

**Code Reference:** See `StoryCollectionManager.swift` lines 38-120

---

## Example: Adding "Soil" Story

Here's what was done to add the "Soil" story collection:

### Files Created:
```
zz-time/TTSContent/Soil/
├── Poems/
│   ├── 01_seventeen_thousand_years.txt
│   ├── 02_the_touching.txt
│   ├── 03_sweet_rotten.txt
│   ├── 04_seventeen_hours.txt
│   ├── 05_forty_three.txt
│   ├── 06_scatter.txt
│   ├── 07_cold_wake.txt
│   ├── 08_drift.txt
│   ├── 09_seventeen_thousand_faces.txt
│   ├── 10_silence_or_patience.txt
│   ├── 11_the_gaps.txt
│   └── 12_isolation_protocol.txt
└── Stories/
    ├── 01_chapter_1.txt
    ├── 02_chapter_2.txt
    ├── 03_chapter_3.txt
    ├── 04_chapter_4.txt
    ├── 05_chapter_5.txt
    ├── 06_chapter_6.txt
    ├── 07_chapter_7.txt
    ├── 08_chapter_8.txt
    ├── 09_chapter_9.txt
    ├── 10_chapter_10.txt
    ├── 11_chapter_11.txt
    ├── 12_chapter_12.txt
    ├── 13_chapter_13.txt
    ├── 14_chapter_14.txt
    ├── 15_chapter_15.txt
    ├── 16_chapter_16.txt
    ├── 17_chapter_17.txt
    └── 18_chapter_18.txt
```

### project.pbxproj Changes:
Added these lines to `membershipExceptions` (lines 191-220):
```
Soil/Poems/01_seventeen_thousand_years.txt,
Soil/Poems/02_the_touching.txt,
Soil/Poems/03_sweet_rotten.txt,
Soil/Poems/04_seventeen_hours.txt,
Soil/Poems/05_forty_three.txt,
Soil/Poems/06_scatter.txt,
Soil/Poems/07_cold_wake.txt,
Soil/Poems/08_drift.txt,
Soil/Poems/09_seventeen_thousand_faces.txt,
Soil/Poems/10_silence_or_patience.txt,
Soil/Poems/11_the_gaps.txt,
Soil/Poems/12_isolation_protocol.txt,
Soil/Stories/01_chapter_1.txt,
Soil/Stories/02_chapter_2.txt,
Soil/Stories/03_chapter_3.txt,
Soil/Stories/04_chapter_4.txt,
Soil/Stories/05_chapter_5.txt,
Soil/Stories/06_chapter_6.txt,
Soil/Stories/07_chapter_7.txt,
Soil/Stories/08_chapter_8.txt,
Soil/Stories/09_chapter_9.txt,
Soil/Stories/10_chapter_10.txt,
Soil/Stories/11_chapter_11.txt,
Soil/Stories/12_chapter_12.txt,
Soil/Stories/13_chapter_13.txt,
Soil/Stories/14_chapter_14.txt,
Soil/Stories/15_chapter_15.txt,
Soil/Stories/16_chapter_16.txt,
Soil/Stories/17_chapter_17.txt,
Soil/Stories/18_chapter_18.txt,
```

Result: Soil now appears in the story selector showing "18 chapters, 12 poems"

---

## Troubleshooting

### Story doesn't appear in the app
- **Check:** Did you add ALL files to `membershipExceptions` in `project.pbxproj`?
- **Check:** Did you rebuild the app after editing `project.pbxproj`?
- **Check:** Are the file paths correct (relative to `TTSContent/`)?

### Poems/chapters show as "0" in the story selector
- **Check:** Did you add the poem/story files to `membershipExceptions`?
- **Check:** Are the files in the correct subdirectories (`Poems/` and `Stories/`)?
- **Check:** Do filenames start with sequence numbers (`01_`, `02_`, etc.)?

### Story appears but playback doesn't work
- **Check:** Are file paths in `project.pbxproj` exactly matching the actual file paths?
- **Check:** Are filenames case-sensitive correct?
- **Check:** Do files have `.txt` extension?

### Xcode shows errors after editing project.pbxproj
- **Check:** Did you maintain proper comma placement?
- **Check:** Did you save the file with proper indentation (use tabs, not spaces)?
- **Check:** Did you close the Xcode project before editing the file?
- **Fix:** Close Xcode, revert changes to `project.pbxproj`, try again

---

## Historical Reference

See [CHANGE_LOG.md](CHANGE_LOG.md) for:
- **2026-01-18**: The Eighteen Paradox story addition (lines 159-177)
- **2026-01-31**: Soil story addition

---

## Quick Reference Checklist

When adding a new story collection:

- [ ] Create `TTSContent/YourStoryName/Poems/` directory
- [ ] Create `TTSContent/YourStoryName/Stories/` directory
- [ ] Add poem .txt files with sequence numbers (01_, 02_, etc.)
- [ ] Add story .txt files with sequence numbers (01_, 02_, etc.)
- [ ] Close Xcode if it's open
- [ ] Edit `project.pbxproj` to add all files to `membershipExceptions`
- [ ] Verify comma placement in `membershipExceptions` list
- [ ] Open Xcode and rebuild the project (⌘B)
- [ ] Run the app and verify story appears correctly
- [ ] Test story playback and poem playback
- [ ] Update CHANGE_LOG.md with the addition

---

**Last Updated:** 2026-01-31
