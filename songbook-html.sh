#!/bin/bash
#
# A simple static site generator for a songbook website based on pandoc
#
# Supported input formats:
# - Plain text (needs to have extension .txt)
# - Manually formatted Markdown (needs to have extension .md)
# - PDF

# Define colors for terminal output
green='\u001b[32m'
yellow='\u001b[33m'
nc='\e[0m'

# Prepare globals and directories
DIR_IN="$PWD/in"
DIR_TMP="$PWD/out/tmp"
DIR_HTML="$PWD/out/html"
DIR_LOGS="$PWD/logs"
[[ -d "$DIR_TMP" ]] || mkdir "$DIR_TMP"
[[ -d "$DIR_HTML" ]] || mkdir "$DIR_HTML"
[[ -d "$DIR_LOGS" ]] || mkdir "$DIR_LOGS"
MARKDOWN=""  # path of intermediate Markdown file
INDEX="$DIR_TMP/index.md"
[[ -e "$INDEX" ]] && rm "$INDEX"

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

    # Desktop
    [[ -d "$DIR_HTML/pdf" ]] || mkdir "$DIR_HTML/pdf"
    cp "$file" "$DIR_HTML/pdf/$file"
    printf '<embed src="%s" width="800px" height="1150px"/>' "pdf/$file" >> "$MARKDOWN"

    # Mobile
    #[[ -d "$DIR_OUT/html/img" ]] || mkdir "$DIR_OUT/html/img"
    # TODO: convert -- cp "$file" "$DIR_OUT/html/pdf/$file"
    # TODO: embed

  # Other (don't do anything but raise awareness)
  else
    echo -e "${yellow}Skipping $file... neither md, nor txt, nor pdf!${nc}"
    skip=1
  fi

  # Add to index
  [[ $skip -ne 1 ]] && printf -- '- [%s](%s)\n' "${file%.*}" "${file%.*}.html" >> "$INDEX"
  skip=0
done
sed -i "1i %Songbook" $INDEX  # add songbook title to index

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
