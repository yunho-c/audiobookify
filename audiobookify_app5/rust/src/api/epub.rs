//! Runtime EPUB parsing API backed by rbook-utils.

use rbook_utils::runtime as runtime_epub;

/// Metadata extracted from an EPUB file.
#[derive(Debug, Clone)]
pub struct EpubMetadata {
    pub title: Option<String>,
    pub creator: Option<String>,
    pub language: Option<String>,
    pub identifier: Option<String>,
    pub publisher: Option<String>,
    pub description: Option<String>,
}

/// Fully parsed runtime book data.
#[derive(Debug, Clone)]
pub struct ParsedEpubBook {
    pub metadata: EpubMetadata,
    pub cover_image: Option<Vec<u8>>,
    pub sections: Vec<Section>,
}

#[derive(Debug, Clone)]
pub struct Section {
    pub id: String,
    pub title: String,
    pub start_href: String,
    pub start_fragment: Option<String>,
    pub end_href: Option<String>,
    pub end_fragment: Option<String>,
    pub spine_start: usize,
    pub spine_end: usize,
    pub anchors: Vec<String>,
    pub document: ReaderDocument,
}

#[derive(Debug, Clone)]
pub struct ReaderDocument {
    pub chapter_href: String,
    pub blocks: Vec<ReaderBlock>,
}

#[derive(Debug, Clone)]
pub enum ReaderBlockKind {
    Paragraph,
    Heading,
    BlockQuote,
    List,
    ListItem,
    Image,
    Table,
    HorizontalRule,
}

#[derive(Debug, Clone)]
pub struct ReaderBlock {
    pub kind: ReaderBlockKind,
    pub level: i32,
    pub ordered: bool,
    pub inlines: Vec<ReaderInline>,
    pub blocks: Vec<ReaderBlock>,
    pub items: Vec<ListItem>,
    pub src: Option<String>,
    pub alt: Option<String>,
    pub caption: Option<String>,
    pub rows: Vec<TableRow>,
}

#[derive(Debug, Clone)]
pub struct ListItem {
    pub blocks: Vec<ReaderBlock>,
}

#[derive(Debug, Clone)]
pub struct TableRow {
    pub cells: Vec<TableCell>,
}

#[derive(Debug, Clone)]
pub struct TableCell {
    pub is_header: bool,
    pub inlines: Vec<ReaderInline>,
}

#[derive(Debug, Clone)]
pub enum ReaderInlineKind {
    Text,
    Emphasis,
    Strong,
    Sup,
    Sub,
    Link,
    LineBreak,
    Span,
}

#[derive(Debug, Clone)]
pub enum SpanStyleHint {
    Italic,
    Bold,
    Underline,
}

#[derive(Debug, Clone)]
pub struct ReaderInline {
    pub kind: ReaderInlineKind,
    pub text: Option<String>,
    pub href: Option<String>,
    pub style_hints: Vec<SpanStyleHint>,
    pub children: Vec<ReaderInline>,
}

/// Error type for EPUB operations.
#[derive(Debug, Clone)]
pub struct EpubError {
    pub message: String,
}

impl std::fmt::Display for EpubError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for EpubError {}

/// Open an EPUB file from path and parse runtime reader sections.
pub fn open_epub(path: String) -> Result<ParsedEpubBook, EpubError> {
    runtime_epub::parse_epub_runtime(std::path::Path::new(&path))
        .map(ParsedEpubBook::from)
        .map_err(map_runtime_error)
}

/// Lazily read a book resource from the EPUB archive.
pub fn read_book_resource_bytes(path: String, href: String) -> Result<Option<Vec<u8>>, EpubError> {
    runtime_epub::read_epub_resource_bytes(std::path::Path::new(&path), &href)
        .map_err(map_runtime_error)
}

fn map_runtime_error(error: anyhow::Error) -> EpubError {
    EpubError {
        message: error.to_string(),
    }
}

impl From<runtime_epub::RuntimeParsedEpubBook> for ParsedEpubBook {
    fn from(value: runtime_epub::RuntimeParsedEpubBook) -> Self {
        Self {
            metadata: value.metadata.into(),
            cover_image: value.cover_image,
            sections: value.sections.into_iter().map(Section::from).collect(),
        }
    }
}

impl From<runtime_epub::RuntimeEpubMetadata> for EpubMetadata {
    fn from(value: runtime_epub::RuntimeEpubMetadata) -> Self {
        Self {
            title: value.title,
            creator: value.creator,
            language: value.language,
            identifier: value.identifier,
            publisher: value.publisher,
            description: value.description,
        }
    }
}

impl From<runtime_epub::RuntimeSection> for Section {
    fn from(value: runtime_epub::RuntimeSection) -> Self {
        Self {
            id: value.id,
            title: value.title,
            start_href: value.start_href,
            start_fragment: value.start_fragment,
            end_href: value.end_href,
            end_fragment: value.end_fragment,
            spine_start: value.spine_start,
            spine_end: value.spine_end,
            anchors: value.anchors,
            document: value.document.into(),
        }
    }
}

impl From<runtime_epub::RuntimeReaderDocument> for ReaderDocument {
    fn from(value: runtime_epub::RuntimeReaderDocument) -> Self {
        Self {
            chapter_href: value.chapter_href,
            blocks: value.blocks.into_iter().map(ReaderBlock::from).collect(),
        }
    }
}

impl From<runtime_epub::RuntimeReaderBlock> for ReaderBlock {
    fn from(value: runtime_epub::RuntimeReaderBlock) -> Self {
        Self {
            kind: value.kind.into(),
            level: value.level,
            ordered: value.ordered,
            inlines: value.inlines.into_iter().map(ReaderInline::from).collect(),
            blocks: value.blocks.into_iter().map(ReaderBlock::from).collect(),
            items: value.items.into_iter().map(ListItem::from).collect(),
            src: value.src,
            alt: value.alt,
            caption: value.caption,
            rows: value.rows.into_iter().map(TableRow::from).collect(),
        }
    }
}

impl From<runtime_epub::RuntimeReaderBlockKind> for ReaderBlockKind {
    fn from(value: runtime_epub::RuntimeReaderBlockKind) -> Self {
        match value {
            runtime_epub::RuntimeReaderBlockKind::Paragraph => Self::Paragraph,
            runtime_epub::RuntimeReaderBlockKind::Heading => Self::Heading,
            runtime_epub::RuntimeReaderBlockKind::BlockQuote => Self::BlockQuote,
            runtime_epub::RuntimeReaderBlockKind::List => Self::List,
            runtime_epub::RuntimeReaderBlockKind::ListItem => Self::ListItem,
            runtime_epub::RuntimeReaderBlockKind::Image => Self::Image,
            runtime_epub::RuntimeReaderBlockKind::Table => Self::Table,
            runtime_epub::RuntimeReaderBlockKind::HorizontalRule => Self::HorizontalRule,
        }
    }
}

impl From<runtime_epub::RuntimeListItem> for ListItem {
    fn from(value: runtime_epub::RuntimeListItem) -> Self {
        Self {
            blocks: value.blocks.into_iter().map(ReaderBlock::from).collect(),
        }
    }
}

impl From<runtime_epub::RuntimeTableRow> for TableRow {
    fn from(value: runtime_epub::RuntimeTableRow) -> Self {
        Self {
            cells: value.cells.into_iter().map(TableCell::from).collect(),
        }
    }
}

impl From<runtime_epub::RuntimeTableCell> for TableCell {
    fn from(value: runtime_epub::RuntimeTableCell) -> Self {
        Self {
            is_header: value.is_header,
            inlines: value.inlines.into_iter().map(ReaderInline::from).collect(),
        }
    }
}

impl From<runtime_epub::RuntimeReaderInline> for ReaderInline {
    fn from(value: runtime_epub::RuntimeReaderInline) -> Self {
        Self {
            kind: value.kind.into(),
            text: value.text,
            href: value.href,
            style_hints: value.style_hints.into_iter().map(SpanStyleHint::from).collect(),
            children: value.children.into_iter().map(ReaderInline::from).collect(),
        }
    }
}

impl From<runtime_epub::RuntimeReaderInlineKind> for ReaderInlineKind {
    fn from(value: runtime_epub::RuntimeReaderInlineKind) -> Self {
        match value {
            runtime_epub::RuntimeReaderInlineKind::Text => Self::Text,
            runtime_epub::RuntimeReaderInlineKind::Emphasis => Self::Emphasis,
            runtime_epub::RuntimeReaderInlineKind::Strong => Self::Strong,
            runtime_epub::RuntimeReaderInlineKind::Sup => Self::Sup,
            runtime_epub::RuntimeReaderInlineKind::Sub => Self::Sub,
            runtime_epub::RuntimeReaderInlineKind::Link => Self::Link,
            runtime_epub::RuntimeReaderInlineKind::LineBreak => Self::LineBreak,
            runtime_epub::RuntimeReaderInlineKind::Span => Self::Span,
        }
    }
}

impl From<runtime_epub::RuntimeSpanStyleHint> for SpanStyleHint {
    fn from(value: runtime_epub::RuntimeSpanStyleHint) -> Self {
        match value {
            runtime_epub::RuntimeSpanStyleHint::Italic => Self::Italic,
            runtime_epub::RuntimeSpanStyleHint::Bold => Self::Bold,
            runtime_epub::RuntimeSpanStyleHint::Underline => Self::Underline,
        }
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_epub_api() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture_path() -> String {
        format!(
            "{}/../test/assets/test_ebook.epub",
            env!("CARGO_MANIFEST_DIR")
        )
    }

    #[test]
    fn opens_runtime_book_and_sections() {
        let book = open_epub(fixture_path()).expect("open test epub");
        assert!(book.metadata.title.is_some());
        assert!(!book.sections.is_empty());
        assert!(!book.sections[0].document.blocks.is_empty());
    }

    #[test]
    fn reads_book_resources_without_crashing() {
        let book = open_epub(fixture_path()).expect("open test epub");
        let image_href = book
            .sections
            .iter()
            .flat_map(|section| section.document.blocks.iter())
            .find_map(|block| block.src.clone());
        if let Some(href) = image_href {
            let bytes = read_book_resource_bytes(fixture_path(), href).expect("read bytes");
            assert!(bytes.is_some());
        }
    }
}
