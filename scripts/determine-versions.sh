#!/bin/bash
set -e

# Configuration
N8N_REPO="n8n-io/n8n"
DOCKER_REPO="medzin/n8n"

echo "Fetching n8n releases from GitHub..." >&2

# 1. Fetch stable n8n releases from GitHub (Top 30)
# We filter out prereleases and strip 'n8n@'
N8N_RELEASES=$(curl -s "https://api.github.com/repos/$N8N_REPO/releases" \
  | jq -r '.[] | select(.prerelease==false) | .tag_name | sub("n8n@";"")')

echo "Fetching existing tags from Docker Hub for $DOCKER_REPO..." >&2

# 2. Fetch existing tags from Docker Hub
# We accept 404 (repo not found) or empty list
DH_RESPONSE=$(curl -s "https://hub.docker.com/v2/repositories/$DOCKER_REPO/tags/?page_size=100")
DH_TAGS=$(echo "$DH_RESPONSE" | jq -r '.results[].name' 2>/dev/null || echo "")

TO_BUILD=()

if [ -z "$DH_TAGS" ]; then
  echo "No existing tags found in Docker Hub (or repo does not exist)." >&2
  echo "Selecting the latest stable version only." >&2
  
  # Get the very first item (newest) from releases
  LATEST_STABLE=$(echo "$N8N_RELEASES" | head -n 1)
  TO_BUILD+=("$LATEST_STABLE")

else
  echo "Found existing tags in Docker Hub." >&2
  
  # Determine the latest version currently in Docker Hub
  # Filter for valid semantic versions (x.y.z) to avoid 'latest' or other tags
  LATEST_LOCAL=$(echo "$DH_TAGS" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
  
  echo "Latest local version: $LATEST_LOCAL" >&2
  
  if [ -z "$LATEST_LOCAL" ]; then
     # Fallback if tags exist but none look like versions
     echo "Could not determine latest local version from tags. Defaulting to latest stable." >&2
     LATEST_STABLE=$(echo "$N8N_RELEASES" | head -n 1)
     TO_BUILD+=("$LATEST_STABLE")
  else
    # Compare releases
    echo "Checking for newer versions..." >&2
    for VER in $N8N_RELEASES;
 do
      # If VER is greater than LATEST_LOCAL, we build it.
      if [ "$(printf '%s\n%s' "$LATEST_LOCAL" "$VER" | sort -V | tail -n1)" == "$VER" ] && [ "$LATEST_LOCAL" != "$VER" ]; then
        echo "New version found: $VER" >&2
        TO_BUILD+=("$VER")
      fi
    done
  fi
fi

# Sort the build list (Oldest -> Newest) for consistent build order
if [ ${#TO_BUILD[@]} -gt 0 ]; then
   # Use a temporary file or specific sorting strategy if the array is large, 
   # but for version numbers, sort -V works well.
   SORTED_BUILD=($(printf '%s\n' "${TO_BUILD[@]}" | sort -V))
else
   SORTED_BUILD=()
fi

echo "Versions to build: ${SORTED_BUILD[*]}" >&2

# Output JSON array
jq --compact-output --null-input '$ARGS.positional' --args "${SORTED_BUILD[@]}"
