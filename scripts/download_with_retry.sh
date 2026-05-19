#!/bin/bash

set -e

URL="${DOWNLOAD_URL}"
FOLDER="${OUTPUT_FOLDER:-downloads}"
QUALITY="${QUALITY:-best}"
USE_PROXY="${USE_PROXY:-false}"

mkdir -p "$FOLDER"
touch "$FOLDER/.download_start"

echo "========================================="
echo "📥 Starting download process"
echo "URL: $URL"
echo "Folder: $FOLDER"
echo "Quality: $QUALITY"
echo "Proxy: $USE_PROXY"
echo "========================================="

# روش‌های مختلف دانلود
METHODS=(
    "yt-dlp_normal"
    "yt-dlp_with_headers"
    "yt-dlp_with_cookies"
    "yt-dlp_with_user_agent_rotation"
    "curl_fallback"
)

# اگر پروکسی فعال بود، روش‌های پروکسی اضافه کن
if [ "$USE_PROXY" = "true" ]; then
    METHODS+=("yt-dlp_with_proxy" "wget_with_proxy")
fi

RETRY_COUNT=0
MAX_RETRIES=${#METHODS[@]}
SUCCESS=false

for METHOD in "${METHODS[@]}"; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo ""
    echo "========================================="
    echo "🔄 Attempt $RETRY_COUNT/$MAX_RETRIES: $METHOD"
    echo "========================================="
    
    case "$METHOD" in
        "yt-dlp_normal")
            yt-dlp \
                --output "$FOLDER/%(uploader)s - %(title)s - %(id)s.%(ext)s" \
                --format "$QUALITY" \
                --merge-output-format mp4 \
                --retries 10 \
                --fragment-retries 20 \
                --no-check-certificate \
                --geo-bypass \
                --geo-bypass-country US \
                --socket-timeout 30 \
                "$URL" && SUCCESS=true
            ;;
            
        "yt-dlp_with_headers")
            yt-dlp \
                --output "$FOLDER/%(uploader)s - %(title)s - %(id)s.%(ext)s" \
                --format "$QUALITY" \
                --add-header "User-Agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                --add-header "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
                --add-header "Accept-Language:en-US,en;q=0.5" \
                --add-header "Accept-Encoding:gzip, deflate, br" \
                --add-header "Referer:https://www.google.com/" \
                --add-header "Origin:https://www.youtube.com" \
                --add-header "Sec-Fetch-Mode:navigate" \
                --add-header "Sec-Fetch-Site:cross-site" \
                --merge-output-format mp4 \
                --retries 10 \
                --no-check-certificate \
                "$URL" && SUCCESS=true
            ;;
            
        "yt-dlp_with_cookies")
            # ایجاد کوکی موقت
            echo ".example.com TRUE / FALSE 0 COOKIE_TEST value" > /tmp/cookies.txt
            yt-dlp \
                --cookies /tmp/cookies.txt \
                --output "$FOLDER/%(uploader)s - %(title)s - %(id)s.%(ext)s" \
                --format "$QUALITY" \
                --merge-output-format mp4 \
                --retries 10 \
                "$URL" && SUCCESS=true
            ;;
            
        "yt-dlp_with_user_agent_rotation")
            USER_AGENTS=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0"
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/119.0.0.0"
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/118.0.0.0"
            )
            RANDOM_UA=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}
            yt-dlp \
                --user-agent "$RANDOM_UA" \
                --output "$FOLDER/%(uploader)s - %(title)s - %(id)s.%(ext)s" \
                --format "$QUALITY" \
                --merge-output-format mp4 \
                --retries 10 \
                --no-check-certificate \
                "$URL" && SUCCESS=true
            ;;
            
        "yt-dlp_with_proxy")
            yt-dlp \
                --proxy "$HTTP_PROXY" \
                --output "$FOLDER/%(uploader)s - %(title)s - %(id)s.%(ext)s" \
                --format "$QUALITY" \
                --merge-output-format mp4 \
                --retries 15 \
                --no-check-certificate \
                "$URL" && SUCCESS=true
            ;;
            
        "curl_fallback")
            FILENAME=$(echo "$URL" | md5sum | cut -d' ' -f1).mp4
            curl -L \
                -H "User-Agent: Mozilla/5.0" \
                -H "Accept: */*" \
                --max-time 300 \
                --retry 5 \
                -o "$FOLDER/$FILENAME" \
                "$URL" && [ -s "$FOLDER/$FILENAME" ] && SUCCESS=true
            ;;
            
        "wget_with_proxy")
            wget \
                --header="User-Agent: Mozilla/5.0" \
                --timeout=30 \
                --tries=5 \
                --waitretry=5 \
                -P "$FOLDER" \
                -e use_proxy=yes \
                -e http_proxy="$HTTP_PROXY" \
                -e https_proxy="$HTTPS_PROXY" \
                "$URL" && SUCCESS=true
            ;;
    esac
    
    if [ "$SUCCESS" = true ]; then
        echo "✅ Download successful with method: $METHOD"
        break
    else
        echo "❌ Method $METHOD failed, trying next..."
        sleep 3
    fi
done

if [ "$SUCCESS" = false ]; then
    echo ""
    echo "========================================="
    echo "❌ ALL DOWNLOAD METHODS FAILED"
    echo "========================================="
    echo "Final diagnosis:"
    echo "- URL might be permanently gone (410)"
    echo "- Domain might be blocked"
    echo "- Try using a different URL"
    echo "========================================="
    exit 1
fi

# پیدا کردن فایل دانلود شده
sleep 2
DOWNLOADED_FILE=$(find "$FOLDER" -type f -newer "$FOLDER/.download_start" ! -name ".download_start" | head -1)

if [ -z "$DOWNLOADED_FILE" ]; then
    echo "⚠️ Could not locate downloaded file, but process succeeded"
    exit 0
fi

FILE_SIZE=$(stat -c%s "$DOWNLOADED_FILE")
echo ""
echo "========================================="
echo "✅ Download completed successfully!"
echo "File: $DOWNLOADED_FILE"
echo "Size: $(echo "scale=2; $FILE_SIZE/1048576" | bc) MB"
echo "========================================="
