#!/bin/bash
# Tubaina2.sh by @sergiolopes & @adrianoalmeida7

if [[ "$@" == *-h* ]] || [[ "$@" == *-help* ]]; then
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

# TODO
#	- testar corner cases, botar ifs
#	- Resolver notes, comentarios etc



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

BUILDDIR="$SRCDIR"/.build

rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

# copy directory
echo "Copying project to $BUILDDIR"
cp -R "$SRCDIR"/* "$BUILDDIR"/

# first chapter as README
first_chapter="$(ls *.md | sort -n | head -1)"
echo "Renaming $first_chapter to README"
if [ -f "$first_chapter" ]; then
	mv "$BUILDDIR"/"$first_chapter" "$BUILDDIR"/README.md
fi

# generates SUMMARY
echo "Generating SUMMARY"
echo "# Sumário" > "$BUILDDIR"/SUMMARY.md

for file in *.md; do
	# Extract first line (expects h1 syntax)
	title=$(head -1 "$file" | sed -e 's/^#[ \t]*//g')

	if [ "$file" == "$first_chapter" ]; then
		file="README.md"
	fi

	echo "  * $title ($file)"
	echo "* [$title]($file)" >> "$BUILDDIR"/SUMMARY.md

	# Remove first line (chapter title)
	tail -n +2 "$BUILDDIR"/"$file" > "$BUILDDIR"/.tmp
	mv "$BUILDDIR"/.tmp "$BUILDDIR"/"$file"
done

# Get book info
if [ -f "$SRCDIR"/../book.properties ]; then
	. "$SRCDIR"/../book.properties
fi
if [ -f "$BUILDDIR"/book.properties ]; then
	. "$BUILDDIR"/book.properties
fi

# Default book info
[ $TITLE ] || TITLE="Untitled {define one in book.properties}"
[ $DESCRIPTION ] || DESCRIPTION="No description {define one in book.properties}"
[ $AUTHOR ] || AUTHOR="Anonymous {define an author in book.properties}"
[ $PUBLISHER ] || PUBLISHER="Anonymous {define a publisher in book.properties}"
[ $THEME ] || THEME="cdc-tema"
[ $DOCKER_IMAGE ] || DOCKER_IMAGE="cdc/gitbook"

# book.json
cat <<END > "$BUILDDIR"/book.json
{
	"title": "$TITLE",
	"description": "$DESCRIPTION",
	"author": "$AUTHOR",
	"publisher": "$PUBLISHER",
	
	"pdf": {
		"margin": {
			"right": 62,
			"left": 62,
			"top": 62,
			"bottom": 62
		},
		"headerTemplate": "<p id='ebook-header' style='border-bottom: 1px solid black; margin-top: 36pt;'><span class='odd_page'><span>Casa do Código</span><span style='float:right'>_SECTION_</span></span><span class='even_page'><span>_SECTION_</span><span style='float:right'>Casa do Código</span></span><script>if(!(/^[0-9]/.test('_SECTION_'))) { document.getElementById('ebook-header').style.display='none'; }</script></p>",
		"footerTemplate": "<p id='ebook-footer'></p><script>var footer = document.getElementById('ebook-footer'); footer.innerHTML = _PAGENUM_ - 2; if(_PAGENUM_ % 2 != 0){ footer.style.textAlign = 'right'; }</script>"
	},

	"plugins": ["cdc", "$THEME"],
	
	"links": {
		"gitbook": false
	}
}
END

# Empty cover
if [ ! -f "$BUILDDIR"/cover.jpg ]; then
	convert -size 3200x4600 -pointsize 100  \
		-fill red -draw "text 100,1000 \"[AUTO GENERATED UGLY COVER]\"" \
		-fill red -draw "text 100,1200 \"[PLEASE ADD YOUR OWN cover.jpg]\"" \
		-fill white -draw "text 100,2500 \"$TITLE\"" \
		xc:orange \
		"$BUILDDIR"/cover.jpg
fi

# Transform instructor notes in boxes
if [[ "$OPTS" == *-showNotes* ]]; then
	echo TODO transformar comentarios em box
fi

# Build using docker or in the OS
function run {
	if [[ "$OPTS" == *-native* ]]; then
		cd "$BUILDDIR"
		$@
	else
		docker run -v "$BUILDDIR":/data $DOCKER_IMAGE $@
	fi
}

# What to build
if [[ "$OPTS" == *-html* ]]; then
	run gitbook build

	echo
	echo Generated HTML output: $BUILDIR/_book/
elif [[ "$OPTS" == *-epub* ]]; then
	run gitbook epub

	echo
	echo Generated epub: $BUILDIR/book.epub
elif [[ "$OPTS" == *-mobi* ]]; then
	run gitbook mobi

	echo
	echo Generated mobi: $BUILDIR/book.mobi
else
	run gitbook pdf

	echo
	echo Generated PDF: $BUILDIR/book.pdf
fi

