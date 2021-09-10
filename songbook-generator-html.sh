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
cd "$DIR_IN"
for file in *; do
  MARKDOWN="$DIR_TMP/${file%.*}.md"

  # Markdown input
  if [[ "${file#*.}" = "md" ]]; then
    cp "$file" "$MARKDOWN"

  # Plain text input
  # - The first line of the in file is taken as title
  # - All line breaks of the in file are enforced in the Markdown
  # - Lines starting with "|" are formatted as code
  # - Verse|Refrain|Chorus|Bridge|Interlude are italicized
  elif [[ "${file#*.}" = "txt" ]]; then
    echo -e "${green}Generating intermediate Markdown from $file...${nc}"
    cp "$file" "$MARKDOWN"
    sed -Ei '1 s/(.*)/% \1/' "$MARKDOWN"
    sed -Ei '2,$ s/(^[^|].*)/\1  /g' "$MARKDOWN"
    sed -Ei '2,$ s/(^[|].*)/    \1/g' "$MARKDOWN"
    sed -Ei '2,$ s:(Intro|Verse|Refrain|Chorus|Bridge|Interlude|Outro):\*\1\*:g' "$MARKDOWN"

  # PDF input
  # - For desktop, PDFs are embedded via <embed>
  # - For mobile, PDFs are converted to PNGs and embedded via <img>
  elif [[ "${file#*.}" = "pdf" ]]; then
    echo -e "${green}Generating intermediate Markdown with embedded copies of $file...${nc}"

    # Responsive html for pdf embedding
    [[ -d "$DIR_HTML/pdf" ]] || mkdir "$DIR_HTML/pdf"
    cp "$file" "$DIR_HTML/pdf/$file"
    printf '<embed src="%s" width="67%%" height="1150px" class="embedding"/>' "pdf/$file" >> "$MARKDOWN"
    printf '<p class="link">
              Screen width below 500 pixels detected.
	      Assuming a mobile device without support for embedding pdfs.
	      Click to open pdf externally:
	    </p>\n' "pdf/$file" >> "$MARKDOWN"
    printf '<a href="%s" class="link">%s</a>' "pdf/$file" "pdf/$file" >> "$MARKDOWN"
    printf '<style type="text/css"> .embedding{display:none;} </style>' >> "$MARKDOWN"
    printf '<style type="text/css"> @media (min-width: 500px) {.embedding{display:block;} .link{display:none;} </style>' >> "$MARKDOWN"

  # Other (don't do anything but raise awareness)
  else
    echo -e "${yellow}Skipping $file... neither md, nor txt, nor pdf!${nc}"
    skip=1
  fi

  # Add to index
  [[ $skip -ne 1 ]] && printf -- '- [%s](%s)\n' "${file%.*}" "${file%.*}.html" >> "$INDEX"
  skip=0
done
sed -i "1i %${SONGBOOK_TITLE}" $INDEX  # add songbook title to index

# Generate HTML from Markdown
cd "$DIR_TMP"
echo
for file in *.md; do
  echo -e "${green}Converting $file to HTML...${nc}"
  pandoc -s "$file" -o "$DIR_HTML/${file%.*}.html" 2> /dev/null
done

# Cleanup
cd $DIR_TMP
rm *.md
rmdir $DIR_TMP
