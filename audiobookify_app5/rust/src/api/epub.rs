//! Runtime EPUB parsing API backed by rbook-utils render IR.

use rbook_utils::render_ir as render_ir_epub;

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
    pub spine_start: i32,
    pub spine_end: i32,
    pub anchors: Vec<String>,
    pub document: ReaderDocument,
}

#[derive(Debug, Clone)]
pub struct ReaderDocument {
    pub chapter_href: String,
    pub blocks: Vec<ReaderBlock>,
}

#[derive(Debug, Clone)]
pub struct ImagePresentation {
    pub width: Option<ImageLength>,
    pub height: Option<ImageLength>,
    pub max_width: Option<ImageLength>,
    pub max_height: Option<ImageLength>,
}

#[derive(Debug, Clone)]
pub struct ImageLength {
    pub value_milli: i32,
    pub unit: ImageLengthUnit,
}

#[derive(Debug, Clone)]
pub enum ImageLengthUnit {
    Percent,
    Px,
    Em,
    Rem,
    Auto,
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
    Code,
}

#[derive(Debug, Clone)]
pub enum BlockAlignment {
    Center,
    Right,
}

#[derive(Debug, Clone)]
pub struct ReaderBlock {
    pub kind: ReaderBlockKind,
    pub level: i32,
    pub alignment: Option<BlockAlignment>,
    pub ordered: bool,
    pub inlines: Vec<ReaderInline>,
    pub blocks: Vec<ReaderBlock>,
    pub items: Vec<ListItem>,
    pub resource: Option<ResourceRef>,
    pub alt: Option<String>,
    pub caption: Option<String>,
    pub presentation: Option<ImagePresentation>,
    pub rows: Vec<TableRow>,
    pub code_text: Option<String>,
    pub source: SourceMap,
}

#[derive(Debug, Clone)]
pub struct ListItem {
    pub blocks: Vec<ReaderBlock>,
    pub source: SourceMap,
}

#[derive(Debug, Clone)]
pub struct TableRow {
    pub cells: Vec<TableCell>,
    pub source: SourceMap,
}

#[derive(Debug, Clone)]
pub struct TableCell {
    pub is_header: bool,
    pub inlines: Vec<ReaderInline>,
    pub source: SourceMap,
}

#[derive(Debug, Clone)]
pub enum ReaderInlineKind {
    Text,
    Span,
    Link,
    Image,
    LineBreak,
}

#[derive(Debug, Clone)]
pub enum SpanStyleHint {
    Italic,
    Bold,
    Underline,
    Superscript,
    Subscript,
    Code,
}

#[derive(Debug, Clone)]
pub struct ReaderInline {
    pub kind: ReaderInlineKind,
    pub text: Option<String>,
    pub target: Option<LinkTarget>,
    pub resource: Option<ResourceRef>,
    pub alt: Option<String>,
    pub presentation: Option<ImagePresentation>,
    pub style_hints: Vec<SpanStyleHint>,
    pub children: Vec<ReaderInline>,
    pub source: SourceMap,
}

#[derive(Debug, Clone)]
pub enum LinkTargetKind {
    Internal,
    External,
    Unresolved,
}

#[derive(Debug, Clone)]
pub struct LinkTarget {
    pub kind: LinkTargetKind,
    pub href: String,
    pub section_id: Option<String>,
    pub section_index: Option<i32>,
    pub fragment: Option<String>,
}

#[derive(Debug, Clone)]
pub enum ResourceKind {
    Image,
    Stylesheet,
    Cover,
    Other,
}

#[derive(Debug, Clone)]
pub struct ResourceRef {
    pub href: String,
    pub media_type: Option<String>,
    pub kind: ResourceKind,
}

#[derive(Debug, Clone)]
pub struct SourceMap {
    pub spine_index: i32,
    pub href: String,
    pub fragment: Option<String>,
    pub node_path: Vec<i32>,
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
    let render_model = render_ir_epub::parse_epub_render_model(std::path::Path::new(&path))
        .map_err(map_runtime_error)?;
    let cover_image = render_model
        .cover_image
        .as_ref()
        .map(|resource| {
            render_ir_epub::read_epub_resource_bytes(std::path::Path::new(&path), resource)
                .map_err(map_runtime_error)
        })
        .transpose()?
        .flatten();

    Ok(ParsedEpubBook::from_render_model(render_model, cover_image))
}

/// Lazily read a book resource from the EPUB archive.
pub fn read_book_resource_bytes(
    path: String,
    resource: ResourceRef,
) -> Result<Option<Vec<u8>>, EpubError> {
    let render_resource = render_ir_epub::ResourceRef {
        href: resource.href,
        media_type: resource.media_type,
        kind: resource.kind.into(),
    };
    render_ir_epub::read_epub_resource_bytes(std::path::Path::new(&path), &render_resource)
        .map_err(map_runtime_error)
}

fn map_runtime_error(error: anyhow::Error) -> EpubError {
    EpubError {
        message: error.to_string(),
    }
}

impl ParsedEpubBook {
    fn from_render_model(
        value: render_ir_epub::BookRenderModel,
        cover_image: Option<Vec<u8>>,
    ) -> Self {
        Self {
            metadata: value.metadata.into(),
            cover_image,
            sections: value.sections.into_iter().map(Section::from).collect(),
        }
    }
}

impl From<render_ir_epub::RenderMetadata> for EpubMetadata {
    fn from(value: render_ir_epub::RenderMetadata) -> Self {
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

impl From<render_ir_epub::Section> for Section {
    fn from(value: render_ir_epub::Section) -> Self {
        let chapter_href = value.source.start_href.clone();
        Self {
            id: value.id,
            title: value.title.unwrap_or_default(),
            start_href: value.source.start_href,
            start_fragment: value.source.start_fragment,
            end_href: value.source.end_href,
            end_fragment: value.source.end_fragment,
            spine_start: to_i32(value.source.spine_start),
            spine_end: to_i32(value.source.spine_end),
            anchors: value.anchors,
            document: ReaderDocument {
                chapter_href,
                blocks: value.blocks.into_iter().map(ReaderBlock::from).collect(),
            },
        }
    }
}

impl From<render_ir_epub::Block> for ReaderBlock {
    fn from(value: render_ir_epub::Block) -> Self {
        match value {
            render_ir_epub::Block::Paragraph(paragraph) => Self {
                kind: ReaderBlockKind::Paragraph,
                level: 0,
                alignment: paragraph.alignment.map(BlockAlignment::from),
                ordered: false,
                inlines: paragraph
                    .inlines
                    .into_iter()
                    .map(ReaderInline::from)
                    .collect(),
                blocks: Vec::new(),
                items: Vec::new(),
                resource: None,
                alt: None,
                caption: None,
                presentation: None,
                rows: Vec::new(),
                code_text: None,
                source: paragraph.source.into(),
            },
            render_ir_epub::Block::Heading(heading) => Self {
                kind: ReaderBlockKind::Heading,
                level: i32::from(heading.level),
                alignment: heading.alignment.map(BlockAlignment::from),
                ordered: false,
                inlines: heading
                    .inlines
                    .into_iter()
                    .map(ReaderInline::from)
                    .collect(),
                blocks: Vec::new(),
                items: Vec::new(),
                resource: None,
                alt: None,
                caption: None,
                presentation: None,
                rows: Vec::new(),
                code_text: None,
                source: heading.source.into(),
            },
            render_ir_epub::Block::Quote(quote) => Self {
                kind: ReaderBlockKind::BlockQuote,
                level: 0,
                alignment: None,
                ordered: false,
                inlines: Vec::new(),
                blocks: quote.blocks.into_iter().map(ReaderBlock::from).collect(),
                items: Vec::new(),
                resource: None,
                alt: None,
                caption: None,
                presentation: None,
                rows: Vec::new(),
                code_text: None,
                source: quote.source.into(),
            },
            render_ir_epub::Block::List(list) => Self {
                kind: ReaderBlockKind::List,
                level: 0,
                alignment: None,
                ordered: list.ordered,
                inlines: Vec::new(),
                blocks: Vec::new(),
                items: list.items.into_iter().map(ListItem::from).collect(),
                resource: None,
                alt: None,
                caption: None,
                presentation: None,
                rows: Vec::new(),
                code_text: None,
                source: list.source.into(),
            },
            render_ir_epub::Block::Table(table) => Self {
                kind: ReaderBlockKind::Table,
                level: 0,
                alignment: None,
                ordered: false,
                inlines: Vec::new(),
                blocks: Vec::new(),
                items: Vec::new(),
                resource: None,
                alt: None,
                caption: None,
                presentation: None,
                rows: table.rows.into_iter().map(TableRow::from).collect(),
                code_text: None,
                source: table.source.into(),
            },
            render_ir_epub::Block::Image(image) => Self {
                kind: ReaderBlockKind::Image,
                level: 0,
                alignment: None,
                ordered: false,
                inlines: Vec::new(),
                blocks: Vec::new(),
                items: Vec::new(),
                resource: Some(image.resource.into()),
                alt: image.alt,
                caption: image.caption,
                presentation: image_presentation_into_option(image.presentation),
                rows: Vec::new(),
                code_text: None,
                source: image.source.into(),
            },
            render_ir_epub::Block::Rule(rule) => Self {
                kind: ReaderBlockKind::HorizontalRule,
                level: 0,
                alignment: None,
                ordered: false,
                inlines: Vec::new(),
                blocks: Vec::new(),
                items: Vec::new(),
                resource: None,
                alt: None,
                caption: None,
                presentation: None,
                rows: Vec::new(),
                code_text: None,
                source: rule.source.into(),
            },
            render_ir_epub::Block::Code(code) => Self {
                kind: ReaderBlockKind::Code,
                level: 0,
                alignment: None,
                ordered: false,
                inlines: Vec::new(),
                blocks: Vec::new(),
                items: Vec::new(),
                resource: None,
                alt: None,
                caption: None,
                presentation: None,
                rows: Vec::new(),
                code_text: Some(code.text),
                source: code.source.into(),
            },
        }
    }
}

impl From<render_ir_epub::ListItem> for ListItem {
    fn from(value: render_ir_epub::ListItem) -> Self {
        Self {
            blocks: value.blocks.into_iter().map(ReaderBlock::from).collect(),
            source: value.source.into(),
        }
    }
}

impl From<render_ir_epub::TableRow> for TableRow {
    fn from(value: render_ir_epub::TableRow) -> Self {
        Self {
            cells: value.cells.into_iter().map(TableCell::from).collect(),
            source: value.source.into(),
        }
    }
}

impl From<render_ir_epub::TableCell> for TableCell {
    fn from(value: render_ir_epub::TableCell) -> Self {
        Self {
            is_header: value.is_header,
            inlines: value.inlines.into_iter().map(ReaderInline::from).collect(),
            source: value.source.into(),
        }
    }
}

impl From<render_ir_epub::Inline> for ReaderInline {
    fn from(value: render_ir_epub::Inline) -> Self {
        match value {
            render_ir_epub::Inline::Text(text) => Self {
                kind: ReaderInlineKind::Text,
                text: Some(text.text),
                target: None,
                resource: None,
                alt: None,
                presentation: None,
                style_hints: Vec::new(),
                children: Vec::new(),
                source: text.source.into(),
            },
            render_ir_epub::Inline::Span(span) => Self {
                kind: ReaderInlineKind::Span,
                text: None,
                target: None,
                resource: None,
                alt: None,
                presentation: None,
                style_hints: span.styles.into_iter().map(SpanStyleHint::from).collect(),
                children: span.children.into_iter().map(ReaderInline::from).collect(),
                source: span.source.into(),
            },
            render_ir_epub::Inline::Link(link) => Self {
                kind: ReaderInlineKind::Link,
                text: None,
                target: Some(link.target.into()),
                resource: None,
                alt: None,
                presentation: None,
                style_hints: Vec::new(),
                children: link.children.into_iter().map(ReaderInline::from).collect(),
                source: link.source.into(),
            },
            render_ir_epub::Inline::Image(image) => Self {
                kind: ReaderInlineKind::Image,
                text: None,
                target: None,
                resource: Some(image.resource.into()),
                alt: image.alt,
                presentation: image_presentation_into_option(image.presentation),
                style_hints: Vec::new(),
                children: Vec::new(),
                source: image.source.into(),
            },
            render_ir_epub::Inline::Break(source) => Self {
                kind: ReaderInlineKind::LineBreak,
                text: None,
                target: None,
                resource: None,
                alt: None,
                presentation: None,
                style_hints: Vec::new(),
                children: Vec::new(),
                source: source.into(),
            },
        }
    }
}

impl From<render_ir_epub::TextStyleHint> for SpanStyleHint {
    fn from(value: render_ir_epub::TextStyleHint) -> Self {
        match value {
            render_ir_epub::TextStyleHint::Italic => Self::Italic,
            render_ir_epub::TextStyleHint::Bold => Self::Bold,
            render_ir_epub::TextStyleHint::Underline => Self::Underline,
            render_ir_epub::TextStyleHint::Superscript => Self::Superscript,
            render_ir_epub::TextStyleHint::Subscript => Self::Subscript,
            render_ir_epub::TextStyleHint::Code => Self::Code,
        }
    }
}

impl From<render_ir_epub::BlockAlignment> for BlockAlignment {
    fn from(value: render_ir_epub::BlockAlignment) -> Self {
        match value {
            render_ir_epub::BlockAlignment::Center => Self::Center,
            render_ir_epub::BlockAlignment::Right => Self::Right,
        }
    }
}

impl From<render_ir_epub::ImagePresentation> for ImagePresentation {
    fn from(value: render_ir_epub::ImagePresentation) -> Self {
        Self {
            width: value.width.map(ImageLength::from),
            height: value.height.map(ImageLength::from),
            max_width: value.max_width.map(ImageLength::from),
            max_height: value.max_height.map(ImageLength::from),
        }
    }
}

impl From<render_ir_epub::ImageLength> for ImageLength {
    fn from(value: render_ir_epub::ImageLength) -> Self {
        Self {
            value_milli: value.value_milli,
            unit: value.unit.into(),
        }
    }
}

impl From<render_ir_epub::ImageLengthUnit> for ImageLengthUnit {
    fn from(value: render_ir_epub::ImageLengthUnit) -> Self {
        match value {
            render_ir_epub::ImageLengthUnit::Percent => Self::Percent,
            render_ir_epub::ImageLengthUnit::Px => Self::Px,
            render_ir_epub::ImageLengthUnit::Em => Self::Em,
            render_ir_epub::ImageLengthUnit::Rem => Self::Rem,
            render_ir_epub::ImageLengthUnit::Auto => Self::Auto,
        }
    }
}

fn image_presentation_into_option(
    value: render_ir_epub::ImagePresentation,
) -> Option<ImagePresentation> {
    if value.width.is_none()
        && value.height.is_none()
        && value.max_width.is_none()
        && value.max_height.is_none()
    {
        None
    } else {
        Some(value.into())
    }
}

impl From<render_ir_epub::LinkTarget> for LinkTarget {
    fn from(value: render_ir_epub::LinkTarget) -> Self {
        match value {
            render_ir_epub::LinkTarget::Internal {
                section_id,
                section_index,
                href,
                fragment,
            } => Self {
                kind: LinkTargetKind::Internal,
                href,
                section_id: Some(section_id),
                section_index: Some(to_i32(section_index)),
                fragment,
            },
            render_ir_epub::LinkTarget::External { href } => Self {
                kind: LinkTargetKind::External,
                href,
                section_id: None,
                section_index: None,
                fragment: None,
            },
            render_ir_epub::LinkTarget::Unresolved { href } => {
                let fragment = href
                    .split_once('#')
                    .map(|(_, fragment)| fragment.to_string());
                Self {
                    kind: LinkTargetKind::Unresolved,
                    href,
                    section_id: None,
                    section_index: None,
                    fragment,
                }
            }
        }
    }
}

impl From<render_ir_epub::ResourceRef> for ResourceRef {
    fn from(value: render_ir_epub::ResourceRef) -> Self {
        Self {
            href: value.href,
            media_type: value.media_type,
            kind: value.kind.into(),
        }
    }
}

impl From<render_ir_epub::ResourceKind> for ResourceKind {
    fn from(value: render_ir_epub::ResourceKind) -> Self {
        match value {
            render_ir_epub::ResourceKind::Image => Self::Image,
            render_ir_epub::ResourceKind::Stylesheet => Self::Stylesheet,
            render_ir_epub::ResourceKind::Cover => Self::Cover,
            render_ir_epub::ResourceKind::Other => Self::Other,
        }
    }
}

impl From<ResourceKind> for render_ir_epub::ResourceKind {
    fn from(value: ResourceKind) -> Self {
        match value {
            ResourceKind::Image => Self::Image,
            ResourceKind::Stylesheet => Self::Stylesheet,
            ResourceKind::Cover => Self::Cover,
            ResourceKind::Other => Self::Other,
        }
    }
}

impl From<render_ir_epub::SourceMap> for SourceMap {
    fn from(value: render_ir_epub::SourceMap) -> Self {
        Self {
            spine_index: to_i32(value.spine_index),
            href: value.href,
            fragment: value.fragment,
            node_path: value.node_path.into_iter().map(to_i32).collect(),
        }
    }
}

fn to_i32<T>(value: T) -> i32
where
    T: TryInto<i32> + Copy,
{
    value.try_into().unwrap_or(i32::MAX)
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
    fn opens_render_model_book_and_sections() {
        let book = open_epub(fixture_path()).expect("open test epub");
        assert!(book.metadata.title.is_some());
        assert!(!book.sections.is_empty());
        assert!(!book.sections[0].document.blocks.is_empty());
        assert!(book.sections[0].spine_start >= 0);
    }

    #[test]
    fn reads_book_resources_without_crashing() {
        let book = open_epub(fixture_path()).expect("open test epub");
        let image_resource = book
            .sections
            .iter()
            .flat_map(|section| section.document.blocks.iter())
            .find_map(|block| block.resource.clone());
        if let Some(resource) = image_resource {
            let bytes = read_book_resource_bytes(fixture_path(), resource).expect("read bytes");
            assert!(bytes.is_some());
        }
    }
}
