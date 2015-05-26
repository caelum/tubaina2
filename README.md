# Tubaina2.sh

```
tubaina2.sh
  Generates a PDF book from current directory using docker.

tubaina.sh folder/ -html -showNotes -native
  First argument (optional): source folder
  Output options: -html -epub -mobi (optional, default pdf)
  -showNotes exposes instructor comments notes (optional, default hide notes)
  -native runs outside Docker (optional, default runs inside Docker)

On your book source folder, add a book.properties with optional book configurations:
  TITLE="Your Title"
  DESCRIPTION="Book description"
  PUBLISHER="Casa do Código"
  AUTHOR="Mr. You"
  THEME="cdc-tema"
  DOCKER_IMAGE="cdc/gitbook"

Also add a cover.jpg on your source folder.
```