#!/bin/bash
#
# A simple pdf songbook generator based on pandoc
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
DIR_PDF="$PWD/out/pdf"
DIR_LOGS="$PWD/logs"
[[ -d "$DIR_TMP" ]] || mkdir -p "$DIR_TMP"
[[ -d "$DIR_PDF" ]] || mkdir -p "$DIR_PDF"
[[ -d "$DIR_LOGS" ]] || mkdir -p "$DIR_LOGS"
MARKDOWN=""  # path of intermediate Markdown file

# Prepare intermediate Markdown in $DIR_TMP for all in files
cd "$DIR_IN"
i=1
for file in *; do
  # Intermediate Markdown format: 0000i-FIRST_WORD_OF_IN_FILENAME.md
  # -> enforces correct sorting for number of files < 1e6
  # -> gets rid of error-prone spaces in filenames
  MARKDOWN="$DIR_TMP/$( printf "%05d" $i )-$( echo ${file%.*} | cut -d " " -f1 ).md"

  # Markdown input
  if [[ "${file#*.}" = "md" ]]; then
    cp "$file" "$MARKDOWN"
    sed -Ei '1 s/(.*)/#\1/' "$MARKDOWN"  # replace "#" by "##" for auto-generated TOC

  # Plain text input
  # - The first line of the in file is taken as title
  # - All line breaks of the in file are enforced in the Markdown
  # - Lines starting with "|" are formatted as code
  # - Verse|Refrain|Chorus|Bridge|Interlude are italicized
  elif [[ "${file#*.}" = "txt" ]]; then
    echo -e "${green}Generating intermediate Markdown from $file...${nc}"
    cp "$file" "$MARKDOWN"
    sed -Ei '1 s/(.*)/## \1/' "$MARKDOWN"
    sed -Ei '2,$ s/(^[^|].*)/\1  /g' "$MARKDOWN"
    sed -Ei '2,$ s/(^[|].*)/    \1/g' "$MARKDOWN"
    sed -Ei '2,$ s:(Intro|Verse|Refrain|Chorus|Bridge|Interlude|Outro):\*\1\*:g' "$MARKDOWN"

  # PDF input
  elif [[ "${file#*.}" = "pdf" ]]; then
    echo -e "${green}Generating intermediate Markdown with embedding of $file...${nc}"
    file_stripped=$( echo $file | sed 's:&:\\&:g' )  # escape "&" in filename for LaTeX
    printf "\includepdf[pages=-, addtotoc={1,subsection,1,%s,test}]{%s}\n" \
      "${file_stripped%.*}" \
      "$DIR_IN/$file" \
      >> $MARKDOWN

  # Other (don't do anything but raise awareness)
  else
    echo -e "${yellow}Skipping $file... neither md, nor txt, nor pdf!${nc}"
  fi

  echo "\newpage" >> "$MARKDOWN"  # put each song onto a new page
  i=$((i+1))
done

# Generate PDF from Markdown
cd "$DIR_TMP"
echo
echo -e "${green}Checking for ISO-8859 encodings in intermediate Markdown...${nc}"
for file in *.md; do
  [[ $(file "$file" | sed -E 's/^.*: ([^ ]*).*/\1/') == "ISO-8859" ]] \
    && echo -e "  ${green}Detected ISO-8859 encoding in $file, converting to UTF-8...${nc}" \
    && iconv -f ISO-8859-1 -t UTF-8 -o "$file" "$file"  
done

echo -e "${green}Converting to PDF...${nc}"
pandoc $( ls *.md ) \
  -V header-includes="\usepackage{pdfpages}" --pdf-engine=pdflatex --toc \
  -o "$DIR_PDF/songbook.pdf"

# Cleanup
cd $DIR_TMP
rm *.md
rmdir $DIR_TMP
