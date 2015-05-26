#!/bin/bash
# Execute na pasta do projeto

# TODO
#   - pq plugin global nao funcionou
#	- precisa do packages.json?
#	- parametrizar script (pasta opcional, pdf/html/epub/mobi, aluno/instrutor)
#	- parametros opcionais (titulo, description, template)
#	- testar corner cases, botar ifs
#	- Resolver notes, comentarios etc


SRCDIR="$(pwd)"
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
	convert -size 32x32 xc:orange "$BUILDDIR"/cover.jpg
fi

# Build PDF
docker run -v "$BUILDDIR":/data cdc/gitbook gitbook pdf
