#!/bin/bash

FILE_PATH="$1"
MAX_SIZE_MB="$2"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found"
    exit 1
fi

if [ -z "$MAX_SIZE_MB" ]; then
    MAX_SIZE_MB=95
fi

FOLDER=$(dirname "$FILE_PATH")
FILENAME=$(basename "$FILE_PATH")
BASENAME="${FILENAME%.*}"
EXTENSION="${FILENAME##*.}"

cd "$FOLDER"

# محاسبه حجم فایل
FILE_SIZE_BYTES=$(stat -c%s "$FILENAME")
FILE_SIZE_MB=$(echo "scale=2; $FILE_SIZE_BYTES/1048576" | bc)

echo "Splitting $FILENAME ($FILE_SIZE_MB MB) into parts of ${MAX_SIZE_MB}MB..."

# استفاده از rar برای اسپلیت
RANDOM_HEX=$(openssl rand -hex 4)
ARCHIVE_NAME="part_${RANDOM_HEX}"

rar a -v${MAX_SIZE_MB}m -m5 -ep1 "${ARCHIVE_NAME}.rar" "$FILENAME"

if [ $? -eq 0 ]; then
    # حذف فایل اصلی بعد از اسپلیت موفق
    rm "$FILENAME"
    
    echo "✅ Split completed successfully"
    echo "Split files:"
    ls -lh "${ARCHIVE_NAME}.part"*.rar 2>/dev/null || ls -lh "${ARCHIVE_NAME}.rar" 2>/dev/null
    
    # ایجاد فایل راهنما
    cat > "HOW_TO_EXTRACT.txt" << EOF
How to extract these split files:
1. Download all .part*.rar files
2. Run: rar x ${ARCHIVE_NAME}.part1.rar
3. Or if single file: unrar x ${ARCHIVE_NAME}.rar

Original file: $FILENAME
Split date: $(date)
EOF
else
    echo "❌ Split failed"
    exit 1
fi
