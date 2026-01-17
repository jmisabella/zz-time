#!/bin/bash

# Script to copy TTSContent directory structure to app bundle
# This preserves the folder hierarchy that Xcode's normal copy phase flattens

set -e

echo "🔵 Starting TTSContent copy script..."

SOURCE_DIR="${SRCROOT}/zz-time/TTSContent"
DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/TTSContent"

echo "📂 Source: ${SOURCE_DIR}"
echo "📂 Destination: ${DEST_DIR}"

# Remove old TTSContent if it exists
if [ -d "${DEST_DIR}" ]; then
    echo "🗑️  Removing old TTSContent..."
    rm -rf "${DEST_DIR}"
fi

# Copy the entire TTSContent directory with structure preserved
if [ -d "${SOURCE_DIR}" ]; then
    echo "📋 Copying TTSContent directory..."
    cp -R "${SOURCE_DIR}" "${DEST_DIR}"
    echo "✅ TTSContent copied successfully"

    # List what was copied for verification
    echo "📁 Contents:"
    find "${DEST_DIR}" -type f -name "*.txt" | while read file; do
        echo "   - ${file#${DEST_DIR}/}"
    done
else
    echo "❌ ERROR: Source directory not found at ${SOURCE_DIR}"
    exit 1
fi

echo "🎉 TTSContent copy complete!"
