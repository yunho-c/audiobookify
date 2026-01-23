//! EPUB loading API using rbook library
//!
//! This module provides functions for opening and reading EPUB files,
//! extracting metadata, cover images, table of contents, and chapter content.

use rbook::{Epub, Ebook};
use rbook::prelude::*;
use rbook::ebook::toc::TocEntry as RbookTocEntryTrait;
use rbook::ebook::epub::toc::EpubTocEntry;
use std::io::Cursor;

/// Metadata extracted from an EPUB file
#[derive(Debug, Clone)]
pub struct EpubMetadata {
    pub title: Option<String>,
    pub creator: Option<String>,
    pub language: Option<String>,
    pub identifier: Option<String>,
    pub publisher: Option<String>,
    pub description: Option<String>,
}

/// A single entry in the table of contents
#[derive(Debug, Clone)]
pub struct TocEntry {
    pub title: String,
    pub href: String,
}

/// A chapter from the EPUB spine
#[derive(Debug, Clone)]
pub struct ChapterInfo {
    pub index: usize,
    pub id: String,
    pub href: String,
    pub media_type: String,
}

/// EPUB book data - we load everything upfront to avoid lifetime issues with FFI
#[derive(Debug, Clone)]
pub struct EpubBook {
    pub metadata: EpubMetadata,
    pub chapters: Vec<ChapterInfo>,
    pub toc: Vec<TocEntry>,
    pub cover_image: Option<Vec<u8>>,
    pub chapter_contents: Vec<String>,
}

/// Error type for EPUB operations
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

/// Open an EPUB file from path and load all data
pub fn open_epub(path: String) -> Result<EpubBook, EpubError> {
    let epub = Epub::options()
        .strict(false)
        .open(&path)
        .map_err(|e| EpubError {
            message: format!("Failed to open EPUB: {}", e),
        })?;
    
    load_epub_data(&epub)
}

/// Open an EPUB from raw bytes and load all data
pub fn open_epub_bytes(bytes: Vec<u8>) -> Result<EpubBook, EpubError> {
    let cursor = Cursor::new(bytes);
    let epub = Epub::options()
        .strict(false)
        .read(cursor)
        .map_err(|e| EpubError {
            message: format!("Failed to open EPUB from bytes: {}", e),
        })?;
    
    load_epub_data(&epub)
}

fn load_epub_data(epub: &Epub) -> Result<EpubBook, EpubError> {
    // Extract metadata
    let epub_metadata = epub.metadata();
    let title = epub_metadata.title().map(|t| t.value().to_string());
    let creator = epub_metadata.creators().next().map(|c| c.value().to_string());
    let language = epub_metadata.language().map(|l| l.value().to_string());
    let identifier = epub_metadata.identifier().map(|i| i.value().to_string());
    let publisher = epub_metadata.publishers().next().map(|p| p.value().to_string());
    let description = epub_metadata.description().map(|d| d.value().to_string());
    
    let metadata = EpubMetadata {
        title,
        creator,
        language,
        identifier,
        publisher,
        description,
    };
    
    // Extract cover image
    let cover_image = epub.manifest()
        .cover_image()
        .and_then(|cover| cover.read_bytes().ok());
    
    // Extract chapters from spine - iterate over EpubSpine
    let mut chapters = Vec::new();
    let mut chapter_contents = Vec::new();
    
    for (index, spine_entry) in epub.spine().into_iter().enumerate() {
        if let Some(manifest_entry) = spine_entry.manifest_entry() {
            chapters.push(ChapterInfo {
                index,
                id: manifest_entry.id().to_string(),
                href: manifest_entry.href().to_string(),
                media_type: manifest_entry.media_type().to_string(),
            });
            
            // Read chapter content
            let content = manifest_entry.read_str().map_err(|e| EpubError {
                message: format!(
                    "Failed to read chapter content ({}): {}",
                    manifest_entry.id(),
                    e
                ),
            })?;
            chapter_contents.push(content);
        }
    }
    
    // Extract table of contents - flatten all descendants for better coverage.
    let mut toc = Vec::new();
    for (_kind, entry) in epub.toc().into_iter() {
        push_toc_entries(&mut toc, entry, 0);
    }
    
    Ok(EpubBook {
        metadata,
        chapters,
        toc,
        cover_image,
        chapter_contents,
    })
}

fn push_toc_entries<'ebook>(
    toc: &mut Vec<TocEntry>,
    entry: EpubTocEntry<'ebook>,
    depth: usize,
) {
    let href_str = entry
        .href()
        .map(|h| h.to_string())
        .unwrap_or_default();
    let indent = "  ".repeat(depth);
    let title = if indent.is_empty() {
        entry.label().to_string()
    } else {
        format!("{}{}", indent, entry.label())
    };
    toc.push(TocEntry { title, href: href_str });

    for child in entry.children() {
        push_toc_entries(toc, child, depth + 1);
    }
}

/// Read a specific chapter by index
pub fn read_chapter(book: &EpubBook, index: usize) -> Result<String, EpubError> {
    book.chapter_contents.get(index).cloned().ok_or_else(|| EpubError {
        message: format!("Chapter index {} out of range", index),
    })
}

/// Get the number of chapters in the book
#[flutter_rust_bridge::frb(sync)]
pub fn get_chapter_count(book: &EpubBook) -> usize {
    book.chapters.len()
}

/// Get metadata from the book
#[flutter_rust_bridge::frb(sync)]
pub fn get_metadata(book: &EpubBook) -> EpubMetadata {
    book.metadata.clone()
}

/// Get table of contents entries
#[flutter_rust_bridge::frb(sync)]
pub fn get_toc(book: &EpubBook) -> Vec<TocEntry> {
    book.toc.clone()
}

/// Get chapter info list
#[flutter_rust_bridge::frb(sync)]
pub fn get_chapters(book: &EpubBook) -> Vec<ChapterInfo> {
    book.chapters.clone()
}

/// Get cover image bytes
#[flutter_rust_bridge::frb(sync)]
pub fn get_cover(book: &EpubBook) -> Option<Vec<u8>> {
    book.cover_image.clone()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_epub_api() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
