#!/bin/bash

URL=$1

echo "========================================="
echo "🔍 Checking URL: $URL"
echo "========================================="

# تست با روش‌های مختلف
METHODS=("default" "proxy" "tor")

for METHOD in "${METHODS[@]}"; do
    echo ""
    echo "Testing with $METHOD method..."
    
    if [ "$METHOD" = "default" ]; then
        STATUS=$(curl -L -o /dev/null -s -w "%{http_code}" \
            --max-time 30 \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            "$URL")
    elif [ "$METHOD" = "proxy" ]; then
        # استفاده از پروکسی تست
        STATUS=$(curl -L -o /dev/null -s -w "%{http_code}" \
            --max-time 30 \
            --proxy http://us.proxy.webshare.io:80 \
            "$URL")
    else
        # روش fallback
        STATUS=$(curl -L -o /dev/null -s -w "%{http_code}" \
            --max-time 30 \
            -x socks5://184.178.172.5:4145 \
            "$URL")
    fi
    
    echo "HTTP Status: $STATUS"
    
    if [ "$STATUS" = "200" ]; then
        echo "✅ URL is accessible with $METHOD method"
        exit 0
    elif [ "$STATUS" = "410" ]; then
        echo "❌ HTTP 410 Gone - Resource permanently removed"
        echo "   Possible causes:"
        echo "   - Video/page has been deleted by author"
        echo "   - Domain blocked by GitHub"
        echo "   - Regional restriction"
        
        # تست با wget به عنوان روش آخر
        echo ""
        echo "🔄 Trying wget with tor proxy..."
        if command -v torsocks &> /dev/null; then
            sudo apt-get install -y tor torsocks
            sudo service tor start
            sleep 5
            torsocks wget --spider --timeout=30 "$URL" 2>&1 | grep -q "200 OK" && echo "✅ Accessible via Tor" || echo "❌ Still 410"
        fi
    else
        echo "⚠️ HTTP $STATUS - Not ideal"
    fi
done

echo ""
echo "========================================="
echo "💡 Recommendations:"
echo "1. Try different URL/video"
echo "2. Enable proxy option in workflow"
echo "3. Check if content still exists"
echo "========================================="

exit 1
