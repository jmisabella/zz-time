
### NEW: March 1, 2026
Read CONTEXT.md to understand this project from a high-level. Now, we have the TTS Story/Poetry mode text content in the zz-time/TTSContent folder: Each story has a subdirectory in TTSContent with the story's name, and the story's prose is inside the Stories/ subdirectory as chapters, and its corresponding poems are inside the Poems/ subdirectory. Also check ADDING_NEW_STORIES.md document to understand what we need to do for these stories/poems to be added and available to the XCode project. 

Now, we currently have 4 stories: Aphelion, Signal Decay, Soil, and The Eighteen Paradox. Well, we've proofread all stories and found that 3/4 are primetime-ready. However we feel that Signal Decay is not good enough and needs reworked. For the time being, we need to remove Signal Decay story altogether, leaving only Aphelion, Soil, and The Eighteen Paradox. 

Please remove Signal_Decay from this project and also do what is necessary to do so. We don't want it anymore. I have a backup of the files elsewhere so this is safe for us to do. 


### OLD: January 2026
# Multi-Story Architecture Implementation - COMPLETED

## Overview
Converted Z Rooms from single-story structure to scalable multi-story architecture where each story is a self-contained collection with chapters and thematically related poems.

## Design Decisions (Confirmed)

### Directory Structure
```
TTSContent/
├── default_custom_story.txt
├── default_custom_poem.txt
├── Signal_Decay/
│   ├── Stories/
│   │   ├── 01_prelude.txt
│   │   ├── 02_chapter1.txt
│   │   ├── 03_chapter2.txt
│   │   └── ... (numbered sequentially)
│   └── Poems/
│       └── *.txt (any filenames - selected randomly)
└── [Future_Story_Name]/
    ├── Stories/
    └── Poems/
```

### Key Features Implemented
1. **Story Title Display**: Every time Leaf or Theater button is toggled on, story title appears at top of ExpandingView for 4-5 seconds with smooth fade animation
2. **Story Selection**: Title is tappable during display - opens menu/dropdown overlay showing all available stories with metadata (chapter count, poem count)
3. **Story Persistence**: Selected story remembered via `@AppStorage` between app sessions
4. **Per-Story Chapter Memory**: Each story remembers its chapter position separately (Signal Decay at chapter 4, Other Story at chapter 2, etc.)
5. **Scoped Poems**: Theater button plays random poem ONLY from currently selected story's Poems/ directory (not from all stories)
6. **Custom Stories Unchanged**: UserDefaults-based custom stories/poems remain completely separate from TTSContent/ system

### File Naming Conventions
- **Directory names**: Use underscores/dashes (e.g., `Signal_Decay`, `My_New-Story`)
- **Display names**: Replace with spaces (e.g., "Signal Decay", "My New Story")
- **Story files**: MUST have numeric prefix for chapter ordering (e.g., `01_`, `02_`, etc.)
- **Poem files**: Can have any name - they're selected randomly

### Migration Approach
- **Manual file reorganization** - No auto-migration implemented
- User copies and renames files into new TTSContent/ structure
- Old flat Stories/ and Poems/ directories remain for reference but are no longer used

## Architecture Changes

### New Components
- **StoryCollection.swift**: Data model representing a story collection
- **StoryCollectionManager.swift**: Manages file discovery, chapter positions, content loading
- **StorySelectionView.swift**: UI for selecting different stories

### Modified Components
- **TextToSpeechManager.swift**: Updated to use StoryCollectionManager for loading stories/poems
- **ExpandingView.swift**: Added title display overlay and story selection sheet

### Chapter Position Tracking
- Dictionary stored in UserDefaults: `[directoryName: chapterIndex]`
- Encoded as JSON Data for @AppStorage compatibility
- Example: `{"Signal_Decay": 4, "Other_Story": 2}`

## Future Story Addition Process
1. Create new subdirectory in TTSContent/ (e.g., `New_Story_Name/`)
2. Create `Stories/` and `Poems/` subdirectories
3. Add numbered story files: `01_chapter1.txt`, `02_chapter2.txt`, etc.
4. Add poem text files (any names)
5. Add to Xcode project bundle
6. App automatically discovers and makes available - no code changes needed

## Testing Checklist
- [x] Story title displays and fades on Leaf/Theater toggle
- [x] Story selection UI shows all available stories
- [x] Chapter positions persist per-story
- [x] Poems scoped to current story
- [x] Custom stories/poems unaffected
- [x] App session persistence (selected story and chapter positions)