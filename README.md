# Tubaina2.sh

```
tubaina2.sh
  Generates a PDF book from current directory using docker.

tubaina.sh folder/ --html --showNotes --native
  First argument (optional): source folder
  Output options: --html --epub --mobi --pdf --ebooks (optional, default pdf)
  --showNotes exposes instructor comments notes (optional, default hide notes)
  --native runs outside Docker (optional, default runs inside Docker)
  --dockerImage repo/image (optional, default casadocodigo/gitbook)
  --imageRootFolder folder/ (optional)
  --pdfImageQuality <default, screen, ebook, printer or prepress> (optional, default prepress)
  --ebookFilename ebook filename (optional, default book)
  --useBookCodeInEbookFilename (optional)
  --useVersionInEbookFilename (optional)
  --help print usage

On your book source folder, add a book.properties with optional book configurations:
  TITLE="Your Title"
  DESCRIPTION="Book description"
  AUTHOR="Mr. You"
  THEME="cdc-tema"
  DOCKER_IMAGE="casadocodigo/gitbook"

Also add a cover.jpg on your source folder.
```
