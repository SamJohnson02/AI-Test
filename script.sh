#!/bin/bash

# Default prompt
PROMPT="How many inches in a foot?"

# Model mapping
function get_model() {
    case "$1" in
        llama)
            echo "meta-llama/llama-3.3-70b-instruct:free"
            ;;
        mistral)
            echo "mistralai/mistral-7b-instruct:free"
            ;;
        gemma)
            echo "google/gemma-3-27b-it:free"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Usage message
usage() {
    echo "Usage: $0 -m [llama|mistral|gemma] -p \"prompt text\""
    exit 1
}

# Parse command line args
while getopts "m:p:" opt; do
    case $opt in
        m) MODEL_KEY="$OPTARG" ;;
        p) PROMPT="$OPTARG" ;;
        *) usage ;;
    esac
done

# Validate model selection
MODEL=$(get_model "$MODEL_KEY")
if [ -z "$MODEL" ]; then
    echo "ERROR: Invalid model name."
    usage
fi

# Ensure API key is set
if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "ERROR: OPENROUTER_API_KEY environment variable is not set."
    exit 1
fi

# Execute API call
curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -d "{
    \"model\": \"$MODEL\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"$PROMPT\"
      }
    ]
  }" | jq '.'

