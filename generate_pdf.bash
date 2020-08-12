#!/bin/bash
#
# Create "Songbook.pdf" (including a table of contents)
# from txt and pdf files in subfolder "Lieder"
#
# The following programs will be used:
# - cups (to generate pdf files from txt files)
# - identify (to count the page numbers of pdf files)
# - qpdf (to merge pdf files)
#
# TODO:
# - add leading zeros for correct sorting for qpdf
# - use latex to print page number on pdfs

# Define Colors for terminal output
red='\u001b[31m'
green='\u001b[32m'
yellow='\u001b[33m'
blue='\u001b[34m'
magenta='\u001b[35m'
cyan='\u001b[36m'
nc='\e[0m'

# Prepare for action
pwd=$PWD
tmp="Lieder/tmp_pdfs"
[[ -d $tmp ]] || mkdir $tmp
[[ -z "$( ls -A "$pwd/$tmp" )" ]] || rm $pwd/$tmp/*
 
# Convert txts to pdf and mv to tmp_pdfs
# Copy pdfs to tmp_pdfs
# Raise awareness for other files
cd "$pwd/Lieder"
for file in *; do
  if [[ "${file#*.}" = "txt" ]]; then
    echo -e "${yellow}Converting $file to pdf and moving ...${nc}"
    cupsfilter "$file"  > tmp_pdfs/"${file%.*}".pdf 2> $pwd/log_pdf_convert_with_cups
  elif [[ "${file#*.}" = "pdf" ]]; then
    echo -e "${green}Copying $file ...${nc}"
    cp "$file" tmp_pdfs/
  else
    echo -e "${red}Skipping $file ... neither txt nor pdf!${nc}"
  fi
done

# Create sorted list of pdfs in tmp_pdfs
cd "$pwd/$tmp"
for file in *; do
  echo "${file%.*}" >> tmp_halfsorted
done
echo
echo "Sorting files ..."
LC_ALL=C sort tmp_halfsorted > tmp_sorted

# Determine number of digits from number of files
#[[ $( cat tmp_sorted | wc -l ) -lt 1000 ]] && digits=3
#[[ $( cat tmp_sorted | wc -l ) -lt 100 ]] && digits=2
#[[ $( cat tmp_sorted | wc -l ) -lt 10 ]] && digits=1

# Generate toc file
[[ -e alphabetisch.toc ]] && rm alphabetisch.toc
echo
echo Generating toc ...
echo $'\n\n\n' >> alphabetisch.toc
echo Inhaltsverzeichnis >> alphabetisch.toc
echo >> alphabetisch.toc

# Get page numbers, rename [with leading zeros] and append to toc file
i=1
while read title; do
  echo
  file="${title}.pdf"
  echo Processing \"$file\"
  
  numberOfPages=$(identify "$file" | wc -l | tr -d ' ')
  #Identify from imagemagick gets info for each page [dump stderr to dev null]
  #count the lines of output
  #trim the whitespace from the wc -l outout
  echo Number of pages: $numberOfPages
  
  echo Renaming to \"$i $file\"
  mv "$file" "${i} ${file}"
  
  echo Appending to toc
  echo "S.${i}" $title >> alphabetisch.toc
  
  (( i+=numberOfPages ))
done < tmp_sorted

# Generate toc pdf
cupsfilter alphabetisch.toc  > "0 Inhaltsverzeichnis.pdf" 2> $pwd/log_pdf_convert_with_cups_toc

# Merge all pdfs
echo
echo "Merging pdfs... Output: Songbook.pdf"
qpdf --empty --pages *.pdf -- Songbook.pdf

# Cleanup
mv Songbook.pdf "$pwd"
rm "$pwd"/$tmp/*
rmdir "$pwd"/$tmp