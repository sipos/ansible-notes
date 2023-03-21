MD_FILE_NAME = ansible_notes.md
PDF_FILE_NAME = $(basename $(MD_FILE_NAME)).pdf
HTML_FILE_NAME = $(basename $(MD_FILE_NAME)).html

.PHONY: all clean spell

all: $(PDF_FILE_NAME) $(HTML_FILE_NAME)

$(PDF_FILE_NAME): $(MD_FILE_NAME)
	pandoc -o $@ $^

$(HTML_FILE_NAME): $(MD_FILE_NAME)
	pandoc -o $@ $^

spell: $(MD_FILE_NAME)
	hunspell $^

clean:
	-rm -rf $(PDF_FILE_NAME) $(HTML_FILE_NAME)
