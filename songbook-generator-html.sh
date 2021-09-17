#!/bin/bash
#
# A simple static site generator for a songbook website based on pandoc
#
# Supported input formats:
# - Plain text (needs to have extension .txt)
# - Manually formatted Markdown (needs to have extension .md)
# - PDF

# Define globals
SONGBOOK_TITLE="Songbook"  # default value
DIR_IN="$PWD/in"  # default value
DIR_TMP="$PWD/out/tmp"  # default value
DIR_HTML="$PWD/out/html"
DIR_LOGS="$PWD/logs"
MARKDOWN=""  # path of intermediate Markdown file
INDEX="$DIR_TMP/index.md"

# Handle command line options for songbook title
# and input and output directories
for i in "$@"; do
  case $i in
    -t=*|--title=*)
      SONGBOOK_TITLE="${i#*=}"
      shift # past argument=value
      ;;
    -i=*|--input=*)
      DIR_IN="${i#*=}"
      shift # past argument=value
      ;;
    -o=*|--output=*)
      DIR_TMP="${i#*=}/tmp"
      DIR_HTML="${i#*=}/html"
      INDEX="$DIR_TMP/index.md"
      shift # past argument=value
      ;;
    *)
      # unknown option
      ;;
  esac
done

# Prepare directories and files
mkdir -p "$DIR_TMP"
mkdir -p "$DIR_HTML"
mkdir -p "$DIR_LOGS"
[[ -e "$INDEX" ]] && rm "$INDEX"

# Define colors for terminal output
green='\u001b[32m'
yellow='\u001b[33m'
nc='\e[0m'

# Prepare intermediate Markdown in $DIR_TMP for all in files and the index
cd "$DIR_IN" || exit 1
for file in *; do
  MARKDOWN="$DIR_TMP/${file%.*}.md"

  # Markdown input
  if [[ "${file#*.}" = "md" ]]; then
    cp "$file" "$MARKDOWN"

  # Plain text input
  elif [[ "${file#*.}" = "txt" ]]; then
    echo -e "${green}Generating intermediate Markdown from $file...${nc}"
    cp "$file" "$MARKDOWN"

    # Convert intermediate Markdown to UTF-8 if it is ISO-8859-encoded
    if [[ $(file "$MARKDOWN" | sed -E 's/^.*: ([^ ]*).*/\1/') == "ISO-8859" ]]; then
      echo "  Detected ISO-8859 encoding, converting to UTF-8..."
      file "$MARKDOWN"
      iconv -f ISO-8859-1 -t UTF-8 -o "$MARKDOWN" "$MARKDOWN"
      file "$MARKDOWN"
      sed -Ei 's/\r//g' "$MARKDOWN"
      file "$MARKDOWN"
    fi

    # Format intermediate Markdown
    # - The first line of the in file is taken as title
    # - All line breaks of the in file are enforced explicitly in the Markdown
    # - Lines starting with "|" are formatted as code
    # - Riff|Intro|Verse|Strophe|Refrain|Chorus|Bridge|Solo|Interlude|Outro are
    #     - TODO: formatted as code if the following line starts with |
    #     - italicized else
    sed -Ei '1 s/(.*)/% \1/' "$MARKDOWN"
    sed -Ei '2,$ s/(^[^|].*)/\1  /g' "$MARKDOWN"
    sed -Ei '2,$ s/(^[|].*)/    \1/g' "$MARKDOWN"
    sed -Ei '2,$ s:(Riff|Intro|Verse|Strophe|Refrain|Chorus|Bridge|Solo|Interlude|Outro):\*\1\*:g' "$MARKDOWN"

  # PDF input
  # - For desktop, PDFs are embedded via <embed>
  # - For mobile, PDFs are converted to PNGs and embedded via <img>
  elif [[ "${file#*.}" = "pdf" ]]; then
    echo -e "${green}Generating intermediate Markdown with embedded copies of $file...${nc}"

    # Responsive html for pdf embedding
    [[ -d "$DIR_HTML/pdf" ]] || mkdir "$DIR_HTML/pdf"
    cp "$file" "$DIR_HTML/pdf/$file"
    {
      printf '<embed src="%s" width="61.8%%" height="1150px" class="embedding"/>' "pdf/$file"
      echo '<p class="link">'
      echo "Screen width is below 500 pixels.
        Pdf embedding is disabled because mobile devices don't support it.
        Click to open the pdf:"
      echo '</p>'
      printf '<a href="%s" class="link">%s</a>' "pdf/$file" "pdf/$file"
      echo '<style type="text/css"> .embedding{display:none;} </style>'
      echo '<style type="text/css"> @media (min-width: 500px) {.embedding{display:block;} .link{display:none;} </style>' 
    } >> "$MARKDOWN"


  # Other (don't do anything but raise awareness)
  else
    echo -e "${yellow}Skipping $file... neither md, nor txt, nor pdf!${nc}"
    skip=1
  fi

  # Add to index
  [[ $skip -ne 1 ]] && printf -- '- [%s](%s)\n' "${file%.*}" "${file%.*}.html" >> "$INDEX"
  skip=0
done
sed -i "1i %${SONGBOOK_TITLE}" "$INDEX"  # add songbook title to index

# Generate HTML from Markdown
cd "$DIR_TMP" || exit 1
echo
for file in *.md; do
  echo -e "${green}Converting $file to HTML...${nc}"

  pandoc -s "$file" -o "$DIR_HTML/${file%.*}.html"
done

# DEBUG
#exit 0

# Cleanup
echo -n "Cleanup..."
cd "$DIR_TMP" || exit 1
rm ./*.md
rmdir "$DIR_TMP"
echo " Done!"
