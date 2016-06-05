#!/bin/bash
# Tubaina2.sh by @sergiolopes & @adrianoalmeida7

function show_help {
	echo "tubaina2.sh"
	echo "  Generates a PDF book from current directory using docker."
	echo
	echo "tubaina.sh folder/ --html --showNotes --native"
	echo "  First argument (optional): source folder"
	echo "  Output options: --html --epub --mobi --pdf --ebooks (optional, default pdf)"
	echo "  --showNotes exposes instructor comments notes (optional, default hide notes)"
	echo "  --native runs outside Docker (optional, default runs inside Docker)"
	echo "  --dockerImage repo/image (optional, default casadocodigo/gitbook)"
	echo "  --imageRootFolder folder/ (optional)"
	echo "  --pdfImageQuality <default, screen, ebook, printer or prepress> (optional, default prepress)"
	echo "  --plugins <plugin-name>[,<plugin-name>, ...]"
	echo "  --help print usage"
	echo
	echo "On your book source folder, add a book.properties with optional book configurations:"
	echo '  TITLE="Your Title"'
	echo '  DESCRIPTION="Book description"'
	echo '  AUTHOR="Mr. You"'
	echo '  BOOK_CODE="XPTO"'
	echo '  THEME="cdc-tema"'
	echo
	echo "Also add a cover.jpg on your source folder."
}

# First argument (optional) is a folder
if [ "$1" ] && [[ "$1" != -* ]]; then
	SRCDIR=`cd "$1" && pwd`
	shift
else
	SRCDIR="$(pwd)"
fi

if [ ! -d "$SRCDIR" ]; then
	echo "Error: $1 isn't a folder"
	exit 1
fi

DOCKER_IMAGE="casadocodigo/gitbook"
OUTPUT_FORMAT="pdf"
PDF_IMAGE_QUALITY="prepress"

optspec=":h-:"
while getopts "$optspec" optchar; do
	case "${optchar}" in
	-)
		case "${OPTARG}" in
			dockerImage)
				DOCKER_IMAGE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
				if [ ! $DOCKER_IMAGE ] ; then
					echo "Please set a DOCKER IMAGE"
					exit 1
				fi
				;;

			imageRootFolder)
				IMAGE_ROOT_FOLDER="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
				if [ ! $IMAGE_ROOT_FOLDER ] ; then
					echo "Please set a IMAGE ROOT FOLDER"
					exit 1
				fi
				;;

			pdfImageQuality)
				PDF_IMAGE_QUALITY="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
				if [ ! $PDF_IMAGE_QUALITY ] ; then
					echo "Please set a PDF IMAGE QUALITY"
					exit 1
				fi

				PDF_IMAGE_QUALITY_VALUES=(default screen ebook printer prepress)
				if [[ ${PDF_IMAGE_QUALITY} && ! " ${PDF_IMAGE_QUALITY_VALUES[@]} " =~ " ${PDF_IMAGE_QUALITY} " ]]; then
					echo "Error: Invalid -pdfImageQuality. Can be: ${PDF_IMAGE_QUALITY_VALUES[*]}"
					exit 1
				fi
				;;

			plugins)
				OTHER_PLUGINS="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
				if [ ! $OTHER_PLUGINS ] ; then
					echo "Please set valid plugins"
					exit 1
				fi
				;;

			showNotes)
				SHOW_NOTES=true
				;;

			native)
				NATIVE=true
				;;

			help)
				show_help
				exit 2
				;;

			*)
				OUTPUT_FORMAT_VALUES=(html pdf epub mobi ebooks)
				if [[ ${OPTARG} && " ${OUTPUT_FORMAT_VALUES[@]} " =~ " ${OPTARG} " ]]; then
					OUTPUT_FORMAT=${OPTARG}
				else
					echo "Unknown option --${OPTARG}" >&2
					exit 1
				fi
				;;
		esac;;
	h)
		show_help
		exit 2
		;;
	*)
		if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
			echo "Non-option argument: '-${OPTARG}'" >&2
			exit 1
		fi
		;;
	esac
done

echo "[tubaina] Using docker image: $DOCKER_IMAGE"

echo "[tubaina] Generating book from $SRCDIR"

BUILDDIR="$SRCDIR"/.build

rm -rf "$BUILDDIR" 2> /dev/null
mkdir -p "$BUILDDIR"

# Build using docker or in the OS
function run {
	if [[ $NATIVE ]]; then
		cd "$BUILDDIR"
		"$@"
	else
		if [ -d "$BUILDDIR"/extras_env ]; then
			EXTRAS_ENV="-e EXTRAS_DIR=/data/extras_env"
		fi
		docker run --rm $EXTRAS_ENV -v "$BUILDDIR":/data $DOCKER_IMAGE "$@"
	fi | while read line; do echo "[$1] $line"; done
}

function copy {
	# copy directory to tmp
	echo "[tubaina] Copying project to $BUILDDIR"
	cp -R "$SRCDIR"/* "$BUILDDIR"/
	cp "$SRCDIR"/.bookignore "$BUILDDIR"/ 2> /dev/null
	# remove possible README file, since it's special in gitbook
	find "$BUILDDIR"/ -maxdepth 1 -iname "README.md" -exec rm {} \;
}

function book_info {
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

	plugin_count=0
	plugin_log=""
	PARSED_OTHER_PLUGINS=""
	OLDIFS=$IFS
	IFS=',' read -ra addr <<< "$OTHER_PLUGINS"
	for plugin in "${addr[@]}"; do
		plugin_count=$((plugin_count + 1))
		plugin_log+="\n[tubaina]   	$plugin_count) $plugin"
		PARSED_OTHER_PLUGINS="$PARSED_OTHER_PLUGINS, \"$plugin\""
	done

	PLUGINS="\"$THEME\" $PARSED_OTHER_PLUGINS"

	# Log
	echo "[tubaina] Using these options:"
	echo "[tubaina]   TITLE        = $TITLE"
	echo "[tubaina]   DESCRIPTION  = $DESCRIPTION"
	echo "[tubaina]   AUTHOR       = $AUTHOR"
	echo "[tubaina]   BOOK_CODE    = $BOOK_CODE"
	echo "[tubaina]   THEME        = $THEME"
	echo -e "[tubaina]   Using $plugin_count other plugins: $plugin_log"
	
	IFS=$OLDIFS
}

function discover_first_chapter {
	type="$@"


	# first chapter as README
	if [[ "$type" == *epub* || "$type" == *mobi* ]] && [ -d "$BUILDDIR/intro" ]; then
		first_chapter_dir="$BUILDDIR/intro"
	else
		first_chapter_dir="$BUILDDIR"
	fi

	if ls $first_chapter_dir/*.md &> /dev/null; then
		echo "Found .md in $first_chapter_dir"
		first_chapter_path="$(ls $first_chapter_dir/*.md | sort -n | head -1)"
		first_chapter="${first_chapter_path##*/}"
	else
		echo "Did not found .md in $first_chapter_dir. Searching for parts."
		first_part_path="$(ls -d $first_chapter_dir/part-* | sort -n | head -1)"
		first_chapter_path="$(ls $first_part_path/*.md | sort -n | head -2 | tail -1)"
		first_part="${first_part_path##*/}"
		first_chapter="$first_part/${first_chapter_path##*/}"
	fi

	echo "[tubaina] Renaming $first_chapter to README.md"
	cp "$first_chapter_dir"/"$first_chapter" "$BUILDDIR"/README.md

}

function generate_parts {
	echo "[tubaina] Generating parts"
	PART_HEADERS=()
	for part_path in "$BUILDDIR/part-"*; do
		if [ -d "$part_path" ]; then
			first_chapter_in_part_path="$(ls $part_path/*.md | sort -n | head -1)"
			for file_path in "$part_path"/*.md; do
				file="${file_path#$BUILDDIR*/}"
				if [ "$file_path" == "$first_chapter_in_part_path" ]; then
					PART_HEADERS+=("\"$file\"")
					continue
				fi
				title=$(head -1 "$file_path" | sed -e 's/^#[ \t]*//g')
				if [ "$file" == "$first_chapter" ]; then
					file="README.md"
					file_path="$BUILDDIR/README.md"
				fi
				echo "[tubaina]   $file: $title"
				echo "* [$title]($file)" >> "$BUILDDIR"/SUMMARY.md
				tail -n +2 "$file_path" > "$BUILDDIR"/.tmp
				mv "$BUILDDIR"/.tmp "$file_path"
			done
		fi
	done
}

function generate_summary {

	type="$@"

	# generates SUMMARY
	echo "[tubaina] Generating SUMMARY"
	echo "# Summary" > "$BUILDDIR"/SUMMARY.md

	function summary {
		intro="$@"

		folder="$SRCDIR"
		if [ -n "$intro" ]; then
			folder="$folder/$intro"
		fi

		if ls $folder/*.md &> /dev/null; then

			for file_path in "$folder"/*.md; do

				file="${file_path##*/}"
				if [ -n "$intro" ]; then
					file="$intro/$file"
				fi

				#skips possible README.md in source dir
				if [ "$(echo "$file" | tr '[:lower:]' '[:upper:]')" == "README.MD" ]; then
					continue
				fi

				# Extract first line (expects h1 syntax)
				title=$(head -1 "$file_path" | sed -e 's/^#[ \t]*//g' | tr -d '\r\n')

				if [ "$file_path" == "$folder"/"$first_chapter" ]; then
					file="README.md"
				fi

				echo "[tubaina]   $file: $title"

				if [[ "$type" == *html* ]] && [ $file != "README.md" ]; then
					chapter_folder="${file##*[0-9]-}" #strip leading numbers and hyphen
					chapter_folder="${chapter_folder%.*}" #strip file extension
					echo "* [$title]($chapter_folder/index.md)" >> "$BUILDDIR"/SUMMARY.md
				else
					echo "* [$title]($file)" >> "$BUILDDIR"/SUMMARY.md
				fi

				# Remove first line (chapter title)
				tail -n +2 "$BUILDDIR"/"$file" > "$BUILDDIR"/.tmp
				mv "$BUILDDIR"/.tmp "$BUILDDIR"/"$file"

			done

		fi

	}

	# summary begins with intro for epub or mobi
	if [[ "$type" == *epub* || "$type" == *mobi* ]] && [ -d "$SRCDIR/intro" ]; then
		summary "intro"
	fi

	summary

	generate_parts
}

function generate_book_json {
	type="$@"

	if [[ "$type" == *epub* || "$type" == *mobi* ]] && [ -d "$SRCDIR/intro" ]; then
		num_intro_chapters=$(ls "$SRCDIR"/intro/*.md | wc -l)
	else
		num_intro_chapters=0
	fi

	# book.json
	OLDIFS=$IFS
	IFS=,
	echo "[tubaina] Generating book.json"
	cat <<END > "$BUILDDIR"/book.json
	{
		"title": "$TITLE",
		"description": "$DESCRIPTION",
		"author": "$AUTHOR",

		"bookCode": "$BOOK_CODE",
		"firstChapter": "${first_chapter%.*}",
		"numIntroChapters": $num_intro_chapters,
		"partHeaders": [${PART_HEADERS[*]}],
		"pdfImageQuality": "$PDF_IMAGE_QUALITY",

		"plugins": ["cdc", $PLUGINS]

	}
END

	IFS=$OLDIFS

}

function cover {
	# Empty cover
	if [ ! -f "$BUILDDIR"/cover.jpg ]; then
		echo "[tubaina][warning] You don't have a cover.jpg"
		run convert -size 3200x4600 -pointsize 100 -fill red -draw "text 100,1000 \"[AUTO GENERATED UGLY COVER]\"" -fill red -draw "text 100,1200 \"[PLEASE ADD YOUR OWN cover.jpg]\"" -fill white -draw "text 100,2500 \"$TITLE\"" xc:orange cover.jpg	&> /dev/null
	fi
}

function notes {
	OLDIFS=$IFS
	IFS=
	# Transform instructor notes in boxes
	if [[ $SHOW_NOTES ]]; then
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
	IFS=$OLDIFS
}

function adjust_image_root_folder {
	if [[ $IMAGE_ROOT_FOLDER ]]; then
		for file in "$BUILDDIR"/*.md; do
			echo "[tubaina] Adjusting image root folder for $file"
			sed -i -e "s|!\[\(.*\)\](\(.*\))|![\1]($IMAGE_ROOT_FOLDER/\2)|" $file
		done
	fi
}

function html {
	echo "Generating html"
	copy
	book_info
	discover_first_chapter html
	generate_summary html
	generate_book_json html
	cover
	notes
	adjust_image_root_folder

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

	run gitbook build -v
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
		run sed -i -e '/src="http:/! { s|<img src="\(.*\)"|<img src="../\1"| }' -e 's|<a href=\"\.\./index.html\" class=\"book-title\"|<a href=\"\.\./\" class=\"book-title\"|' -e 's|<a href=\"\(.*\)index.html\" class=\"nav-simple-chapter\"|<a href=\"\1\" class=\"nav-simple-chapter\"|' _book/"$folder"/index.html
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
	run sed -i -e '/src="http:/! { s|<img src="\(.*\)"|<img src="../\1"| }' -e 's|<link rel=\"stylesheet\" href=\"\(.*\)\"|<link rel=\"stylesheet\" href=\"../\1\"|' -e 's|<a href=\"./\(.*\)index.html\"|<a href=\"../\1index.html\"|' -e 's|<a href=\"\.\./index.html\" class=\"book-title\"|<a href=\"\.\./\" class=\"book-title\"|' -e 's|<a href=\"\.\./\(.*\)index.html\" class=\"nav-simple-chapter\"|<a href=\"\.\./\1\" class=\"nav-simple-chapter\"|' _book/"$first"/index.html

}

function epub {
	echo "[tubaina] Generating epub"
	copy
	book_info
	discover_first_chapter epub
	generate_summary epub
	generate_book_json epub
	cover
	notes
	adjust_image_root_folder
	run gitbook epub -v
	echo "[tubaina] Generated epub: $BUILDDIR/book.epub"
}

function mobi {
	echo "[tubaina] Generating mobi"
	copy
	book_info
	discover_first_chapter mobi
	generate_summary mobi
	generate_book_json mobi
	cover
	notes
	adjust_image_root_folder
	run gitbook mobi -v
	echo "[tubaina] Generated mobi: $BUILDDIR/book.mobi"
}

function pdf {
	echo "[tubaina] Generating pdf"
	copy
	if [ -d "$EXTRAS_DIR" ]; then
		cp -R "$EXTRAS_DIR" "$BUILDDIR"/extras_env
	fi
	book_info
	discover_first_chapter pdf
	generate_summary pdf
	generate_book_json pdf
	cover
	notes
	adjust_image_root_folder
	run gitbook pdf -v
	echo "[tubaina] Generated PDF: $BUILDDIR/book.pdf"
}

# What to build
echo "[tubaina] Building with Gitbook"
if [[ "$OUTPUT_FORMAT" == *html* ]]; then
	html
elif [[ "$OUTPUT_FORMAT" == *epub* ]]; then
	epub
elif [[ "$OUTPUT_FORMAT" == *mobi* ]]; then
	mobi
elif [[ "$OUTPUT_FORMAT" == *pdf* ]]; then
	pdf
elif [[ "$OUTPUT_FORMAT" == *ebooks* ]]; then
	pdf
	epub
	mobi
fi
