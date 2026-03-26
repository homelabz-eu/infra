#!/usr/bin/env bash
set -euo pipefail

DUMP_URL="https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-pages-articles-multistream.xml.bz2"
WORK_DIR="${1:-/tmp/wikipedia-knowledge}"
OUTPUT_DIR="${WORK_DIR}/chunks"
CHUNK_SIZE="${CHUNK_SIZE:-2000}"
OPEN_WEBUI_URL="${OPEN_WEBUI_URL:-https://chat.toolz.homelabz.eu}"
KNOWLEDGE_NAME="${KNOWLEDGE_NAME:-Simple English Wikipedia}"
PARALLEL=${PARALLEL:-8}

if [ -z "${OPENWEBUI_TOKEN:-}" ]; then
    echo "ERROR: OPENWEBUI_TOKEN is required."
    echo "Get it from Open WebUI: Settings > Account > API Keys > Create"
    echo ""
    echo "Usage: OPENWEBUI_TOKEN='sk-...' $0 [work_dir]"
    exit 1
fi

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"

echo "=== Step 1: Download Simple English Wikipedia dump ==="
DUMP_FILE="${WORK_DIR}/simplewiki-latest.xml.bz2"
if [ ! -f "${DUMP_FILE}" ]; then
    echo "Downloading from ${DUMP_URL} (~200MB)..."
    curl -L -o "${DUMP_FILE}" "${DUMP_URL}"
else
    echo "Dump already downloaded, skipping."
fi

echo ""
echo "=== Step 2: Extract and chunk articles ==="
if [ "$(find "${OUTPUT_DIR}" -name '*.txt' 2>/dev/null | head -1)" ]; then
    echo "Chunks already exist, skipping."
else
    python3 - "${DUMP_FILE}" "${OUTPUT_DIR}" "${CHUNK_SIZE}" <<'PYTHON'
import bz2
import xml.etree.ElementTree as ET
import os
import sys
import re

dump_file = sys.argv[1]
output_dir = sys.argv[2]
chunk_size = int(sys.argv[3])

def strip_wikitext(text):
    text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)
    text = re.sub(r"\{\{[^}]*\}\}", "", text)
    text = re.sub(r"\{\|.*?\|\}", "", text, flags=re.DOTALL)
    text = re.sub(r"<ref[^>]*>.*?</ref>", "", text, flags=re.DOTALL)
    text = re.sub(r"<ref[^/]*/?>", "", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\[\[Category:[^\]]*\]\]", "", text)
    text = re.sub(r"\[\[File:[^\]]*\]\]", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\[\[Image:[^\]]*\]\]", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\[\[[^\]]*\|([^\]]*)\]\]", r"\1", text)
    text = re.sub(r"\[\[([^\]]*)\]\]", r"\1", text)
    text = re.sub(r"\[https?://[^\s\]]*\s?([^\]]*)\]", r"\1", text)
    text = re.sub(r"'{2,5}", "", text)
    text = re.sub(r"^[=]{2,}\s*(.*?)\s*[=]{2,}$", r"\n\1\n", text, flags=re.MULTILINE)
    text = re.sub(r"^\*+\s*", "- ", text, flags=re.MULTILINE)
    text = re.sub(r"^#+\s*", "- ", text, flags=re.MULTILINE)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

file_count = 0
skipped = 0
article_count = 0

print("Parsing Wikipedia dump (this takes a few minutes)...")

with bz2.open(dump_file, "rt", encoding="utf-8") as f:
    for event, elem in ET.iterparse(f, events=("end",)):
        tag = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag

        if tag != "page":
            continue

        ns_tag = elem.tag.replace("page", "ns")
        title_tag = elem.tag.replace("page", "title")
        text_tag = elem.tag.replace("page", "text")

        ns_elem = elem.find(ns_tag)
        if ns_elem is None or ns_elem.text != "0":
            elem.clear()
            continue

        title_elem = elem.find(title_tag)
        text_elem = elem.find(f".//{text_tag}")

        if title_elem is None or text_elem is None or not text_elem.text:
            elem.clear()
            continue

        title = title_elem.text.strip()
        wikitext = text_elem.text

        if wikitext.lower().startswith("#redirect"):
            elem.clear()
            continue

        article_count += 1
        if article_count % 5000 == 0:
            print(f"  Processed {article_count} articles, created {file_count} chunks...")

        text = strip_wikitext(wikitext)

        if len(text) < 100:
            skipped += 1
            elem.clear()
            continue

        safe_title = re.sub(r'[^\w\s-]', '', title)[:80].strip().replace(' ', '_')

        if len(text) <= chunk_size:
            out_path = os.path.join(output_dir, f"{safe_title}.txt")
            with open(out_path, "w", encoding="utf-8") as out:
                out.write(f"# {title}\n\n{text}\n")
            file_count += 1
        else:
            paragraphs = text.split('\n\n')
            chunk = ""
            chunk_num = 0
            for para in paragraphs:
                if len(chunk) + len(para) + 2 > chunk_size and chunk:
                    chunk_num += 1
                    out_path = os.path.join(output_dir, f"{safe_title}_part{chunk_num}.txt")
                    with open(out_path, "w", encoding="utf-8") as out:
                        out.write(f"# {title} (Part {chunk_num})\n\n{chunk}\n")
                    file_count += 1
                    chunk = para
                else:
                    chunk = f"{chunk}\n\n{para}" if chunk else para
            if chunk:
                chunk_num += 1
                out_path = os.path.join(output_dir, f"{safe_title}_part{chunk_num}.txt")
                with open(out_path, "w", encoding="utf-8") as out:
                    out.write(f"# {title} (Part {chunk_num})\n\n{chunk}\n")
                file_count += 1

        elem.clear()

print(f"Created {file_count} chunk files from {article_count} articles (skipped {skipped} short/empty)")
PYTHON
fi

TOTAL_FILES=$(find "${OUTPUT_DIR}" -name "*.txt" | wc -l)
TOTAL_SIZE=$(du -sh "${OUTPUT_DIR}" | cut -f1)
echo "Total: ${TOTAL_FILES} files, ${TOTAL_SIZE}"

echo ""
echo "=== Step 3: Create knowledge base in Open WebUI ==="
if [ -f "${WORK_DIR}/knowledge_id.txt" ]; then
    KNOWLEDGE_ID=$(cat "${WORK_DIR}/knowledge_id.txt")
    echo "Using existing knowledge base: ${KNOWLEDGE_ID}"
else
    KNOWLEDGE_ID=$(curl -sf -X POST "${OPEN_WEBUI_URL}/api/v1/knowledge/create" \
        -H "Authorization: Bearer ${OPENWEBUI_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${KNOWLEDGE_NAME}\", \"description\": \"Simple English Wikipedia articles for RAG\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    echo "${KNOWLEDGE_ID}" > "${WORK_DIR}/knowledge_id.txt"
    echo "Created knowledge base: ${KNOWLEDGE_ID}"
fi

echo ""
echo "=== Step 4: Upload files to Open WebUI (${TOTAL_FILES} files) ==="

PROGRESS_FILE="${WORK_DIR}/upload_progress.txt"
touch "${PROGRESS_FILE}"
ALREADY_DONE=$(wc -l < "${PROGRESS_FILE}")
if [ "${ALREADY_DONE}" -gt 0 ]; then
    echo "Resuming from ${ALREADY_DONE}/${TOTAL_FILES} already uploaded."
fi

upload_file() {
    local file="$1"
    local basename
    basename=$(basename "${file}")

    if grep -qFx "${basename}" "${PROGRESS_FILE}" 2>/dev/null; then
        return 0
    fi

    local file_id
    file_id=$(curl -sf --retry 3 --retry-delay 2 -X POST "${OPEN_WEBUI_URL}/api/v1/files/" \
        -H "Authorization: Bearer ${OPENWEBUI_TOKEN}" \
        -F "file=@${file}" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null) || return 1

    sleep 0.5

    curl -sf --retry 3 --retry-delay 2 -X POST "${OPEN_WEBUI_URL}/api/v1/knowledge/${KNOWLEDGE_ID}/file/add" \
        -H "Authorization: Bearer ${OPENWEBUI_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"file_id\": \"${file_id}\"}" >/dev/null 2>&1 && {
        echo "${basename}" >> "${PROGRESS_FILE}"
        return 0
    } || {
        return 1
    }
}

export -f upload_file
export OPEN_WEBUI_URL OPENWEBUI_TOKEN KNOWLEDGE_ID PROGRESS_FILE

find "${OUTPUT_DIR}" -name "*.txt" -print0 | sort -z | \
    xargs -0 -n1 -P"${PARALLEL}" bash -c '
        upload_file "$1"
        STATUS=$?
        DONE=$(wc -l < "${PROGRESS_FILE}")
        TOTAL='"${TOTAL_FILES}"'
        if [ $STATUS -eq 0 ]; then
            printf "\r[%d/%d] Uploaded: %-60s" "${DONE}" "${TOTAL}" "$(basename "$1")"
        else
            printf "\n[FAIL] %s\n" "$(basename "$1")"
        fi
    ' _

echo ""
UPLOADED=$(wc -l < "${PROGRESS_FILE}")
echo ""
echo "=== Done ==="
echo "Uploaded: ${UPLOADED}/${TOTAL_FILES} files to knowledge base '${KNOWLEDGE_NAME}'"
echo "Knowledge base ID: ${KNOWLEDGE_ID}"
echo ""
echo "To use in chat: type # in the message box and select '${KNOWLEDGE_NAME}'"
