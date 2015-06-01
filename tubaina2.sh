#!/bin/bash
# Tubaina2.sh by @sergiolopes & @adrianoalmeida7

if [[ "$@" == *-help* ]]; then
	echo "tubaina2.sh"
	echo "  Generates a PDF book from current directory using docker."
	echo
	echo "tubaina.sh folder/ -html -showNotes -native"
	echo "  First argument (optional): source folder"
	echo "  Output options: -html -epub -mobi (optional, default pdf)"
	echo "  -showNotes exposes instructor comments notes (optional, default hide notes)"
	echo "  -native runs outside Docker (optional, default runs inside Docker)"
	echo
	echo "On your book source folder, add a book.properties with optional book configurations:"
	echo '  TITLE="Your Title"'
	echo '  DESCRIPTION="Book description"'
	echo '  PUBLISHER="Casa do Código"'
	echo '  AUTHOR="Mr. You"'
	echo '  THEME="cdc-tema"'
	echo '  DOCKER_IMAGE="cdc/gitbook"'
	echo
	echo "Also add a cover.jpg on your source folder."

	exit 0
fi

# First argument (optional) is a folder
if [ "$1" ] && [[ "$1" != -* ]]; then
	SRCDIR="$1"
	OPTS=${@:2}
else
	SRCDIR="$(pwd)"	
	OPTS=$@
fi

if [ ! -d "$SRCDIR" ]; then
	echo "Error: $SRCDIR isn't a folder"
	exit 1
fi

echo "[tubaina] Generating book from $SRCDIR"

BUILDDIR="$SRCDIR"/.build

rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

# copy directory to tmp
echo "[tubaina] Copying project to $BUILDDIR"
cp -R "$SRCDIR"/* "$BUILDDIR"/

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
[ "$PUBLISHER" ] || PUBLISHER="Anonymous {define a publisher in book.properties}"
[ "$THEME" ] || THEME="cdc-tema"
[ "$DOCKER_IMAGE" ] || DOCKER_IMAGE="cdc/gitbook"

# Log
echo "[tubaina] Using these options:"
echo "[tubaina]   TITLE        = $TITLE"
echo "[tubaina]   DESCRIPTION  = $DESCRIPTION"
echo "[tubaina]   AUTHOR       = $AUTHOR"
echo "[tubaina]   PUBLISHER    = $PUBLISHER"
echo "[tubaina]   THEME        = $THEME"
echo "[tubaina]   DOCKER_IMAGE = $DOCKER_IMAGE"

# first chapter as README
first_chapter="$(ls *.md | sort -n | head -1)"
echo "[tubaina] Renaming $first_chapter to README"
if [ -f "$first_chapter" ]; then
	mv "$BUILDDIR"/"$first_chapter" "$BUILDDIR"/README.md
fi

# generates SUMMARY
echo "[tubaina] Generating SUMMARY"
echo "# Summary" > "$BUILDDIR"/SUMMARY.md

for file in *.md; do
	# Extract first line (expects h1 syntax)
	title=$(head -1 "$file" | sed -e 's/^#[ \t]*//g')
	echo "[tubaina]   $file: $title"

	if [ "$file" == "$first_chapter" ]; then
		file="README.md"
	fi

	echo "* [$title]($file)" >> "$BUILDDIR"/SUMMARY.md

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
	"publisher": "$PUBLISHER",
	
	"plugins": ["cdc", "$THEME"],
	
	"links": {
		"gitbook": false
	}
}
END

# Empty cover
if [ ! -f "$BUILDDIR"/cover.jpg ]; then
	echo "[tubaina][warning] You don't have a cover.jpg"
	convert -size 3200x4600 -pointsize 100  \
		-fill red -draw "text 100,1000 \"[AUTO GENERATED UGLY COVER]\"" \
		-fill red -draw "text 100,1200 \"[PLEASE ADD YOUR OWN cover.jpg]\"" \
		-fill white -draw "text 100,2500 \"$TITLE\"" \
		xc:orange \
		"$BUILDDIR"/cover.jpg &> /dev/null
fi

# Transform instructor notes in boxes
if [[ "$OPTS" == *-showNotes* ]]; then
	echo "[tubaina] Detected -showNotes option"
	echo "[tubaina] Transforming <!--@note --> in md boxes"

	IFS=""

	for file in "$BUILDDIR"/*.md; do
		inside_note=false

		cat "$file" | while read -r line; do

			if [[ $inside_note == true ]]; then 
				echo "> $line" | sed -e 's/-->$//'

				if [[ $line == *--\> ]]; then
					inside_note=false
				fi
			else
				if [[ $line == \<\!--@note* ]]; then
					echo "> **@note**"
					echo ">"

					note=$(echo $line | sed -e 's/^<!--@note//;s/-->$//')
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

# Build using docker or in the OS
function run {
	if [[ "$OPTS" == *-native* ]]; then
		cd "$BUILDDIR"
		$@
	else
		docker run -v "$BUILDDIR":/data $DOCKER_IMAGE $@
	fi | while read line; do echo "[gitbook] $line"; done
}

# What to build
echo "[tubaina] Building with Gitbook"
if [[ "$OPTS" == *-html* ]]; then
	run gitbook build

	echo "[tubaina] Generated HTML output: $BUILDIR/_book/"
elif [[ "$OPTS" == *-epub* ]]; then
	run gitbook epub

	echo "[tubaina] Generated epub: $BUILDIR/book.epub"
elif [[ "$OPTS" == *-mobi* ]]; then
	run gitbook mobi

	echo "[tubaina] Generated mobi: $BUILDIR/book.mobi"
else
	run gitbook pdf

	echo "[tubaina] Generated PDF: $BUILDIR/book.pdf"
fi

