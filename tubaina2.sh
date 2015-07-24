#!/bin/bash
# Tubaina2.sh by @sergiolopes & @adrianoalmeida7

if [[ "$@" == *-help* ]]; then
	echo "tubaina2.sh"
	echo "  Generates a PDF book from current directory using docker."
	echo
	echo "tubaina.sh folder/ -html -showNotes -native"
	echo "  First argument (optional): source folder"
	echo "  Output options: -html -epub -mobi -pdf -ebooks (optional, default pdf)"
	echo "  -showNotes exposes instructor comments notes (optional, default hide notes)"
	echo "  -native runs outside Docker (optional, default runs inside Docker)"
	echo
	echo "On your book source folder, add a book.properties with optional book configurations:"
	echo '  TITLE="Your Title"'
	echo '  DESCRIPTION="Book description"'
	echo '  AUTHOR="Mr. You"'
	echo '  THEME="cdc-tema"'
	echo '  DOCKER_IMAGE="cdc/gitbook"'
	echo
	echo "Also add a cover.jpg on your source folder."

	exit 0
fi

# First argument (optional) is a folder
if [ "$1" ] && [[ "$1" != -* ]]; then
	SRCDIR=`cd "$1" && pwd`
	OPTS=${@:2}
else
	SRCDIR="$(pwd)"	
	OPTS=$@
fi

if [ ! -d "$SRCDIR" ]; then
	echo "Error: $1 isn't a folder"
	exit 1
fi

echo "[tubaina] Generating book from $SRCDIR"

BUILDDIR="$SRCDIR"/.build

rm -rf "$BUILDDIR" 2> /dev/null
mkdir -p "$BUILDDIR"

# copy directory to tmp
echo "[tubaina] Copying project to $BUILDDIR"
cp -R "$SRCDIR"/* "$BUILDDIR"/

# remove possible README file, since it's special in gitbook
find "$BUILDDIR"/ -maxdepth 1 -iname "README.md" -exec rm {} \;

# Get book info
if [ -f "$SRCDIR"/../book.properties ]; then
	. "$SRCDIR"/../book.properties
fi
if [ -f "$BUILDDIR"/book.properties ]; then
	. "$BUILDDIR"/book.properties
fi

# Default book info
[ "$TITLE" ] || TITLE="Untitled {define one in book.properties}"
[ "$DESCRIPTION" ] || DESCRIPTION="No description {define one in book.properties}"
[ "$AUTHOR" ] || AUTHOR="Anonymous {define an author in book.properties}"
[ "$BOOK_CODE" ] || BOOK_CODE="${SRCDIR##*/}"
[ "$THEME" ] || THEME="cdc-tema"
[ "$DOCKER_IMAGE" ] || DOCKER_IMAGE="cdc/gitbook"

# Log
echo "[tubaina] Using these options:"
echo "[tubaina]   TITLE        = $TITLE"
echo "[tubaina]   DESCRIPTION  = $DESCRIPTION"
echo "[tubaina]   AUTHOR       = $AUTHOR"
echo "[tubaina]   BOOK_CODE    = $BOOK_CODE"
echo "[tubaina]   THEME        = $THEME"
echo "[tubaina]   DOCKER_IMAGE = $DOCKER_IMAGE"

# first chapter as README
first_chapter_path="$(ls $BUILDDIR/*.md | sort -n | head -1)"
first_chapter="${first_chapter_path##*/}"
echo "[tubaina] Renaming $first_chapter to README.md"
mv "$BUILDDIR"/"$first_chapter" "$BUILDDIR"/README.md

# generates SUMMARY
echo "[tubaina] Generating SUMMARY"
echo "# Summary" > "$BUILDDIR"/SUMMARY.md

for file_path in "$SRCDIR"/*.md; do
	file="${file_path##*/}"
	
	#skips possible README.md in source dir
	if [ "$(echo "$file" | tr '[:lower:]' '[:upper:]')" == "README.MD" ]; then
		continue
	fi

	if [ "$file_path" == "$SRCDIR"/"$first_chapter" ]; then
		file="README.md"
	fi
	
	# Extract first line (expects h1 syntax)
	title=$(head -1 "$file_path" | sed -e 's/^#[ \t]*//g')
	echo "[tubaina]   $file: $title"

	if [[ "$OPTS" == *-html* ]] && [ $file != "README.md" ]; then
		folder="${file##*[0-9]-}" #strip leading numbers and hyphen
		folder="${folder%.*}" #strip file extension
		echo "* [$title]($folder/index.md)" >> "$BUILDDIR"/SUMMARY.md
	else
		echo "* [$title]($file)" >> "$BUILDDIR"/SUMMARY.md
	fi

	# Remove first line (chapter title)
	tail -n +2 "$BUILDDIR"/"$file" > "$BUILDDIR"/.tmp
	mv "$BUILDDIR"/.tmp "$BUILDDIR"/"$file"
done

# book.json
echo "[tubaina] Generating book.json"
cat <<END > "$BUILDDIR"/book.json
{
	"title": "$TITLE",
	"description": "$DESCRIPTION",
	"author": "$AUTHOR",

	"bookCode": "$BOOK_CODE",
	"firstChapter": "${first_chapter%.*}",

	"plugins": ["cdc", "$THEME"]
}
END

# Build using docker or in the OS
function run {
	if [[ "$OPTS" == *-native* ]]; then
		cd "$BUILDDIR"
		"$@"
	else
		docker run --rm -v "$BUILDDIR":/data $DOCKER_IMAGE "$@"
	fi | while read line; do echo "[gitbook] $line"; done
}

# Empty cover
if [ ! -f "$BUILDDIR"/cover.jpg ]; then
	echo "[tubaina][warning] You don't have a cover.jpg"
	run convert -size 3200x4600 -pointsize 100 -fill red -draw "text 100,1000 \"[AUTO GENERATED UGLY COVER]\"" -fill red -draw "text 100,1200 \"[PLEASE ADD YOUR OWN cover.jpg]\"" -fill white -draw "text 100,2500 \"$TITLE\"" xc:orange cover.jpg	&> /dev/null
fi

# Transform instructor notes in boxes
if [[ "$OPTS" == *-showNotes* ]]; then
	echo "[tubaina] Detected -showNotes option"
	echo "[tubaina] Transforming <!--@note --> in md boxes"

	for file in "$BUILDDIR"/*.md; do
		inside_note=false

		cat "$file" | while read -r line; do

			if [[ $inside_note == true ]]; then 
				echo "> $line" | sed -e 's/-->$//'

				if [[ $line == *--\> ]]; then
					inside_note=false
				fi
			else
				if [[ $line == \<\!--*@note* ]]; then
					echo "> **@note**"
					echo ">"

					note=$(echo $line | sed -e 's/^<!--\s*@note//;s/-->$//')
					if [[ "$note" ]]; then
						echo "> $note"
					fi

					if [[ $line != *--\> ]]; then
						inside_note=true
					fi
				else
					echo "$line"
				fi
			fi

		done > "$BUILDDIR"/.tmp

		mv "$BUILDDIR"/.tmp "$file"
	done
fi

function html {
	CHAPTERS=()
	for file_path in "$BUILDDIR"/*.md; do
		file="${file_path##*/}"
		if [ "$file" != "README.md" ] && [ "$file" != "SUMMARY.md" ]; then
			file="${file##*[0-9]-}" #strip leading numbers and hyphen
			file="${file%.*}" #strip file extension
			folder="$BUILDDIR"/"$file"
			CHAPTERS+=("$file")
			mkdir -p "$folder"; mv "$file_path" "$folder"/index.md
		fi
	done
	
    if [ -d "$BUILDDIR"/intro-html ]; then
        mv "$BUILDDIR"/intro-html "$BUILDDIR"/intro
    fi

    run gitbook build
    echo "[tubaina] Generated HTML output: $BUILDDIR/_book/"

	first="${first_chapter##*[0-9]-}" #strip leading numbers and hyphen
	first="${first%.*}" #strip file extension

	echo "[tubaina] Fixing navigation to first chapter in $BUILDDIR/_book/${CHAPTERS[0]}/index.html"
	run sed -i "s|<a href=\"\.\./index.html\" class=\"nav-simple-chapter\"|<a href=\"../$first/index.html\" class=\"nav-simple-chapter\"|" _book/"${CHAPTERS[0]}"/index.html 

	for folder in ${CHAPTERS[@]}; do
		echo "[tubaina] Fixing references in $BUILDDIR/_book/$folder/index.html"
		#adds ../ to every image which src is not http://
		#removes index.html from the top
		#removes index.html from previous and next navs
		run sed -i -e '/src="http:/! { s|<img src="\(.*\)"|<img src="../\1/"| }' -e 's|<a href=\"\.\./index.html\" class=\"book-title\"|<a href=\"\.\./\" class=\"book-title\"|' -e 's|<a href=\"\(.*\)index.html\" class=\"nav-simple-chapter\"|<a href=\"\1\" class=\"nav-simple-chapter\"|' _book/"$folder"/index.html
	done

	echo "[tubaina] Fixing Table of Contents"
	run mkdir -p _book/"$first"
	run mv _book/index.html _book/"$first"/index.html
	run mv _book/GLOSSARY.html _book/index.html

	echo "[tubaina] Fixing references in $BUILDDIR/_book/index.html"
	#safe to remove every index.html, as we control toc generation
	run sed -i -e "s|${first_chapter%.*}|$first/index|" -e "s|index.html||" _book/index.html

	echo "[tubaina] Fixing references in $BUILDDIR/_book/$first/index.html"
	#adds ../ to every image which src is not http://
	#adds ../ to css references
	#adds ../ to links
	#removes index.html from the top
	#removes index.html from previous and next navs
	run sed -i -e '/src="http:/! { s|<img src="\(.*\)"|<img src="../\1/"| }' -e 's|<link rel=\"stylesheet\" href=\"\(.*\)\"|<link rel=\"stylesheet\" href=\"../\1\"|' -e 's|<a href=\"./\(.*\)index.html\"|<a href=\"../\1index.html\"|' -e 's|<a href=\"\.\./index.html\" class=\"book-title\"|<a href=\"\.\./\" class=\"book-title\"|' -e 's|<a href=\"\.\./\(.*\)index.html\" class=\"nav-simple-chapter\"|<a href=\"\.\./\1\" class=\"nav-simple-chapter\"|' _book/"$first"/index.html

}

function epub {
	run gitbook epub
	echo "[tubaina] Generated epub: $BUILDDIR/book.epub"
}

function mobi {
	run gitbook mobi
	echo "[tubaina] Generated mobi: $BUILDDIR/book.mobi"
}

function pdf {
	run gitbook pdf
	echo "[tubaina] Generated PDF: $BUILDDIR/book.pdf"
}

# What to build
echo "[tubaina] Building with Gitbook"
if [[ "$OPTS" == *-html* ]]; then
    html
elif [[ "$OPTS" == *-epub* ]]; then
    epub
elif [[ "$OPTS" == *-mobi* ]]; then
    mobi
elif [[ "$OPTS" == *-pdf* ]]; then
    pdf
elif [[ "$OPTS" == *-ebooks* ]]; then
    pdf
    epub
    mobi
else
    pdf
fi

