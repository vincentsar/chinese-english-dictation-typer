#!/bin/bash
# Download Whisper model from Hugging Face
set -euo pipefail

MODEL_NAME="${1:-small-q5_1}"
MODEL_FILE="ggml-${MODEL_NAME}.bin"

# Keep this helper aligned with ModelManager. Do not interpolate arbitrary input
# into a URL or path: model names come from this allowlist only.
case "$MODEL_NAME" in
    base-q5_1)
        EXPECTED_SHA256="422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898" ;;
    small-q5_1)
        EXPECTED_SHA256="ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb" ;;
    medium-q5_0)
        EXPECTED_SHA256="19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f" ;;
    small)
        EXPECTED_SHA256="1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b" ;;
    *)
        echo "Unsupported model: $MODEL_NAME" >&2
        echo "Choose: base-q5_1, small-q5_1, medium-q5_0, or small." >&2
        exit 2 ;;
esac

MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_FILE}"

# App stores models in Application Support
APP_SUPPORT_DIR="$HOME/Library/Application Support/VoiceKeyboard/Models"
mkdir -p "$APP_SUPPORT_DIR"

DEST="$APP_SUPPORT_DIR/$MODEL_FILE"

if [ -f "$DEST" ]; then
    ACTUAL_SHA256=$(shasum -a 256 "$DEST" | awk '{print $1}')
    if [ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ]; then
        echo "Model already exists and passed integrity check: $DEST"
        exit 0
    fi
    echo "Existing model failed integrity check; replacing it." >&2
fi

echo "==> Downloading $MODEL_FILE..."
echo "    URL: $MODEL_URL"
echo "    Destination: $DEST"
echo ""

TMP_FILE=$(mktemp "$APP_SUPPORT_DIR/.${MODEL_FILE}.download.XXXXXX")
trap 'rm -f "$TMP_FILE"' EXIT

curl --fail --location --proto '=https' --tlsv1.2 --progress-bar -o "$TMP_FILE" "$MODEL_URL"

ACTUAL_SHA256=$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "Download failed integrity check; discarding it." >&2
    exit 1
fi

mv -f "$TMP_FILE" "$DEST"
trap - EXIT

SIZE=$(ls -lh "$DEST" | awk '{print $5}')
echo ""
echo "==> Downloaded $MODEL_FILE ($SIZE) to $DEST"
