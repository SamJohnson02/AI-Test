#!/bin/bash

# Default values
CATEGORY="general"
LANG="en"
COUNTRY="us"
MAX="10"
API_KEY=$GNEWS_API_KEY

# Usage message
usage() {
    echo "Usage: $0 -k API_KEY [-c category] [-l lang] [-u country] [-m max]"
    echo "Defaults: category=general lang=en country=us max=10"
    exit 1
}

# Parse command-line arguments
while getopts ":k:c:l:u:m:" opt; do
  case $opt in
    k) API_KEY="$OPTARG" ;;
    c) CATEGORY="$OPTARG" ;;
    l) LANG="$OPTARG" ;;
    u) COUNTRY="$OPTARG" ;;
    m) MAX="$OPTARG" ;;
    *) usage ;;
  esac
done

# Require API key
if [ -z "$API_KEY" ]; then
    echo "Error: API key is required."
    usage
fi

# Build URL
URL="https://gnews.io/api/v4/top-headlines?category=$CATEGORY&lang=$LANG&country=$COUNTRY&max=$MAX&apikey=$API_KEY"

echo "Calling GNews API..."
echo "Category: $CATEGORY | Lang: $LANG | Country: $COUNTRY | Max: $MAX"
echo ""

# Perform the API request and pretty-print
curl -s "$URL" | jq -r '
  .articles[] |
  "----------------------------------------",
  "Title:      \(.title)",
  "Descriotion: \(.description)",
  "Source:     \(.source.name)",
  "Published:  \(.publishedAt)",
  "URL:        \(.url)",
  "",
  "Article:",
  (.content // "No article text provided."),
  "----------------------------------------",
  ""
'

