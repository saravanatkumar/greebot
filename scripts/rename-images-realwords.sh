#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
  echo "ERROR: This script must be run with bash (not sh)."
  echo "Run: bash scripts/rename-images-realwords.sh [images-directory]"
  exit 1
fi

IMAGES_DIR="${1:-/Users/apple/CascadeProjects/windsurf-project-2/data/images}"

if [ ! -d "$IMAGES_DIR" ]; then
  echo "ERROR: Directory not found: $IMAGES_DIR"
  exit 1
fi

COUNTER_FILE="$IMAGES_DIR/.rename-images-realwords.counter"
if [ -f "$COUNTER_FILE" ]; then
  counter=$(cat "$COUNTER_FILE" 2>/dev/null)
else
  counter=0
fi
counter=${counter:-0}

to_base36() {
  local n="$1"
  local digits="0123456789abcdefghijklmnopqrstuvwxyz"
  local out=""
  local rem

  if [ -z "$n" ]; then
    echo "0"
    return
  fi

  if [ "$n" -eq 0 ] 2>/dev/null; then
    echo "0"
    return
  fi

  while [ "$n" -gt 0 ] 2>/dev/null; do
    rem=$((n % 36))
    out="${digits:$rem:1}${out}"
    n=$((n / 36))
  done

  echo "$out"
}

pad_left() {
  local s="$1"
  local width="$2"
  while [ "${#s}" -lt "$width" ]; do
    s="0${s}"
  done
  echo "$s"
}

sanitize_slug() {
  local s="$1"
  s=$(echo "$s" | tr '[:upper:]' '[:lower:]')
  s=$(echo "$s" | sed -E 's/\.[^.]+$//')
  s=$(echo "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  echo "$s"
}

first_keyword() {
  local slug="$1"
  local kw
  kw=$(echo "$slug" | cut -d'-' -f1)
  if [ -z "$kw" ]; then
    kw="img"
  fi
  echo "$kw"
}

ADJ=(
  "green" "bright" "fresh" "happy" "swift" "calm" "clean" "smooth" "bold" "lucky"
  "sunny" "soft" "quiet" "vivid" "pure" "crisp" "kind" "cheerful" "friendly" "shiny"
  "tiny" "giant" "mini" "royal" "golden" "silver" "new" "daily" "local" "urban"
  "sweet" "spicy" "tasty" "hot" "cool" "cozy" "classic" "simple" "magic" "super"
)

NOUN=(
  "dot" "spot" "circle" "ring" "orb" "ball" "badge" "mark" "point" "bead"
  "bubble" "glow" "seed" "leaf" "mint" "lime" "olive" "gem" "token" "spark"
  "pizza" "tea-cup" "bindi" "juice" "chips" "stadium" "corn" "chutney" "pakku-plate"
  "coffee" "lemon" "mango" "banana" "apple" "grape" "watermelon" "coconut" "guava" "papaya"
  "burger" "sandwich" "noodles" "rice" "dosa" "idli" "samosa" "biscuit" "cake" "ice-cream"
  "bottle" "cup" "plate" "spoon" "fork" "kettle" "jar" "box" "bag" "basket"
  "garden" "market" "street" "temple" "bridge" "station" "school" "office" "park" "beach"
  "library" "museum" "theater" "mall" "airport" "harbor" "highway" "subway" "bus-stop" "crossroad"
  "hostel" "hotel" "cafe" "bakery" "kitchen" "balcony" "rooftop" "hall" "room" "gate"
  "notebook" "pencil" "eraser" "marker" "stapler" "scissors" "tape" "envelope" "folder" "wallet"
  "camera" "tripod" "speaker" "headphone" "charger" "laptop" "keyboard" "mouse" "screen" "remote"
  "tshirt" "jacket" "cap" "shoe" "sandal" "watch" "ring" "chain" "bracelet" "sunglass"
  "soap" "shampoo" "towel" "comb" "mirror" "perfume" "lotion" "brush" "bucket" "mug"
  "parotta" "biryani" "paniyaram" "pongal" "vada" "upma" "rasam" "sambar" "pickle" "curd"
  "tomato" "onion" "potato" "carrot" "cucumber" "spinach" "beans" "peas" "ginger" "garlic"
)

EXTRA=(
  "greet" "hello" "find" "spot" "seek" "scan" "watch" "look" "catch" "trace"
  "smile" "wave" "share" "join" "play" "cheer" "click" "post" "visit" "collect"
)

pick_from() {
  local arr_name="$1"
  local len
  local idx
  local val

  len=$(eval "echo \${#${arr_name}[@]}")
  if [ -z "$len" ] || [ "$len" -le 0 ] 2>/dev/null; then
    echo ""
    return
  fi

  idx=$((RANDOM % len))
  val=$(eval "echo \${${arr_name}[$idx]}")
  echo "$val"
}

DATE_TAG=$(date +%Y%m%d)

echo "=========================================="
echo "Renaming images to real-word unique names"
echo "Directory: $IMAGES_DIR"
echo "=========================================="
echo ""

count=0

for path in "$IMAGES_DIR"/*; do
  file=$(basename "$path")
  if [ -f "$path" ]; then
    ext=""
    if [[ "$file" == *.* ]]; then
      ext="${file##*.}"
    fi

    slug=$(sanitize_slug "$file")
    kw=$(first_keyword "$slug")
    if [ "$kw" = "image" ]; then
      kw=$(pick_from NOUN)
      if [ -z "$kw" ]; then
        kw="img"
      fi
    fi

    w1=$(pick_from ADJ)
    w2=$(pick_from NOUN)
    w3=$(pick_from EXTRA)

    id36=$(to_base36 "$counter")
    id36=$(pad_left "$id36" 4)

    new_base="${kw}-${w1}-${w2}-${w3}-${DATE_TAG}-${id36}"

    new_name="$new_base"
    if [ -n "$ext" ] && [ "$ext" != "$file" ]; then
      new_name="${new_base}.${ext}"
    fi

    if [ -e "$IMAGES_DIR/$new_name" ]; then
      suffix=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 4)
      new_base="${new_base}-${suffix}"
      new_name="$new_base"
      if [ -n "$ext" ] && [ "$ext" != "$file" ]; then
        new_name="${new_base}.${ext}"
      fi
    fi

    mv "$path" "$IMAGES_DIR/$new_name"
    echo "  ✓ $file -> $new_name"

    counter=$((counter + 1))
    count=$((count + 1))
  fi
  
done

echo "$counter" > "$COUNTER_FILE"

echo ""
echo "=========================================="
echo "Done! Renamed $count images"
echo "Counter stored in: $COUNTER_FILE"
echo "=========================================="
