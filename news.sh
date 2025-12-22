#!/bin/bash

# ----- Map short model names to OpenRouter model IDs -----
get_model() {
    case "$1" in
        llama)   echo "meta-llama/llama-3.3-70b-instruct:free" ;;
        mistral) echo "mistralai/mistral-7b-instruct:free" ;;
        gemma)   echo "google/gemma-3-27b-it:free" ;;
        *)       echo "" ;;
    esac
}

# ----- Defaults -----
CATEGORY="general"
LANG="en"
COUNTRY="us"
MAX="10"
GNEWS_API_KEY="${GNEWS_API_KEY:-}"
MODEL_KEY=""
PRINT_ARTICLE="print"   # print | nop
DEBUG="no"              # yes | no

usage() {
    echo "Usage: $0 -m [llama|mistral|gemma] [-k GNEWS_API_KEY] [-c category] [-l lang] [-u country] [-n max] [-a print|nop] [-d]"
    echo "Env vars: OPENROUTER_API_KEY required, GNEWS_API_KEY optional unless -k used"
    exit 1
}

# ----- Parse arguments -----
while getopts "m:k:c:l:u:n:a:d" opt; do
    case $opt in
        m) MODEL_KEY="$OPTARG" ;;
        k) GNEWS_API_KEY="$OPTARG" ;;
        c) CATEGORY="$OPTARG" ;;
        l) LANG="$OPTARG" ;;
        u) COUNTRY="$OPTARG" ;;
        n) MAX="$OPTARG" ;;
        a) PRINT_ARTICLE="$OPTARG" ;;
        d) DEBUG="yes" ;;
        *) usage ;;
    esac
done

if [[ "$PRINT_ARTICLE" != "print" && "$PRINT_ARTICLE" != "nop" ]]; then
    echo "ERROR: -a must be 'print' or 'nop'"
    exit 1
fi

MODEL=$(get_model "$MODEL_KEY")
if [ -z "$MODEL" ]; then
    echo "ERROR: Invalid or missing model. Use -m [llama|mistral|gemma]"
    usage
fi

if [ -z "$GNEWS_API_KEY" ]; then
    echo "ERROR: GNews API key missing. Set env GNEWS_API_KEY or use -k"
    exit 1
fi

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "ERROR: OPENROUTER_API_KEY env var is not set."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required."
    exit 1
fi

# GNews request with nullable fields
URL="https://gnews.io/api/v4/top-headlines?category=$CATEGORY&lang=$LANG&country=$COUNTRY&max=$MAX&nullable=description,content,image&apikey=$GNEWS_API_KEY"

echo "Fetching news..."
echo "Category: $CATEGORY | Lang: $LANG | Country: $COUNTRY | Max: $MAX"
echo "Model: $MODEL | Print: $PRINT_ARTICLE | Debug: $DEBUG"
echo ""

RESPONSE=$(curl -s "$URL")

if [ -z "$RESPONSE" ]; then
    echo "ERROR: Empty response from GNews."
    exit 1
fi

ERR=$(echo "$RESPONSE" | jq -r '.errors // empty')
if [ -n "$ERR" ]; then
    echo "GNews API ERROR: $ERR"
    exit 1
fi

# Loop articles
echo "$RESPONSE" | jq -c '.articles[]' | while read -r article; do

    title=$(echo "$article"        | jq -r '.title')
    source=$(echo "$article"       | jq -r '.source.name')
    published=$(echo "$article"    | jq -r '.publishedAt')
    url=$(echo "$article"          | jq -r '.url')
    description=$(echo "$article"  | jq -r '.description // "No description provided."')
    content=$(echo "$article"      | jq -r '.content // "No content provided."')

    # ----- Build the LLM prompt -----
read -r -d '' prompt <<EOF
You are a news classifier.
Pick ONE category from:
general, world, nation, business, technology, entertainment, sports, science, health, opinion, other.

Respond ONLY with the category.

Title: $title
Description: $description
Source: $source
Published: $published
URL: $url

Content:
$content
EOF

    body=$(jq -Rn --arg model "$MODEL" --arg prompt "$prompt" '
        { model: $model, messages: [ {role:"user", content:$prompt} ] }')

    llm_response=$(curl -s https://openrouter.ai/api/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENROUTER_API_KEY" \
      -H "X-Title: news-categorizer-script" \
      -d "$body")

    [ "$DEBUG" = "yes" ] && echo "RAW LLM RESPONSE:" && echo "$llm_response" && echo "------"

    category=$(echo "$llm_response" | jq -r '
        if (.choices | type=="array") and (.choices|length>0)
            then .choices[0].message.content
        elif .error and .error.message
            then "ERROR_FROM_API: " + .error.message
        else "unknown" end' | tr -d '\n')

    # ----- PRETTY PRINT OUTPUT -----
    if [ "$PRINT_ARTICLE" = "print" ]; then
        echo "$article" | jq -r --arg category "$category" '
          "----------------------------------------",
          "Title:       \(.title)",
          "Description: \(.description // "No description provided.")",
          "Source:      \(.source.name)",
          "Published:   \(.publishedAt)",
          "URL:         \(.url)",
          "LLM Category: \($category)",
          "",
          "Content:",
          (.content // "No content provided."),
          "----------------------------------------",
          ""
        '
    else
        echo "$article" | jq -r --arg category "$category" '
          "----------------------------------------",
          "Title:       \(.title)",
          "Description: \(.description // "No description provided.")",
          "Source:      \(.source.name)",
          "Published:   \(.publishedAt)",
          "URL:         \(.url)",
          "LLM Category: \($category)",
          "----------------------------------------",
          ""
        '
    fi

done

