//! Filesystem boundary for native callers and the sandboxed WASM guest.
//!
//! Both targets use the same [`Vfs`] trait and in-memory [`MemoryVfs`]. Native
//! callers get an [`OsVfs`] backed by `std::fs`. The guest keeps generated files
//! in memory and its [`OsVfs`] rejects access to an operating system filesystem.
pub use portable::{MemoryVfs, Vfs};

#[cfg(not(target_arch = "wasm32"))]
pub use native::OsVfs;

#[cfg(target_arch = "wasm32")]
pub use portable::OsVfs;

#[cfg(not(target_arch = "wasm32"))]
mod native {
    use super::Vfs;
    use std::fs;
    use std::io::Result;
    use std::path::{Path, PathBuf};

    /// Operating system filesystem for native callers.
    pub struct OsVfs;

    impl Vfs for OsVfs {
        fn read_to_string(&self, path: &Path) -> Result<String> {
            fs::read_to_string(path)
        }
        fn write_from_string(&self, path: &Path, content: &str) -> Result<()> {
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent)?;
            }
            fs::write(path, content)
        }
        fn exists(&self, path: &Path) -> bool {
            path.exists()
        }
        fn list_dir(&self, path: &Path) -> Result<Vec<PathBuf>> {
            fs::read_dir(path)?
                .map(|entry| entry.map(|entry| entry.path()))
                .collect()
        }
        fn create_dir_all(&self, path: &Path) -> Result<()> {
            fs::create_dir_all(path)
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn native_os_files_round_trip() {
            let dir = tempfile::tempdir().unwrap();
            let path = dir.path().join("generated/nested/model.gleam");
            OsVfs.write_from_string(&path, "pub type T = Int").unwrap();
            assert_eq!(OsVfs.read_to_string(&path).unwrap(), "pub type T = Int");
            assert!(OsVfs.exists(&dir.path().join("generated")));
            assert_eq!(
                OsVfs
                    .list_dir(&dir.path().join("generated/nested"))
                    .unwrap(),
                vec![path]
            );
        }
    }
}

mod portable {
    use std::collections::BTreeMap;
    use std::io::{Error, ErrorKind, Result};
    use std::path::{Component, Path, PathBuf};
    use std::sync::{Arc, Mutex};

    /// File operations used by Gleam's visitors inside the guest.
    pub trait Vfs {
        /// Read a generated file.
        fn read_to_string(&self, path: &Path) -> Result<String>;
        /// Write a generated file, creating its parent directories implicitly.
        fn write_from_string(&self, path: &Path, content: &str) -> Result<()>;
        /// Whether a file or a directory containing files exists.
        fn exists(&self, path: &Path) -> bool;
        /// List files contained in a directory.
        fn list_dir(&self, path: &Path) -> Result<Vec<PathBuf>>;
        /// Create directories used by a visitor.
        fn create_dir_all(&self, path: &Path) -> Result<()>;
    }

    /// An in-memory filesystem shared by visitor clones.
    #[derive(Clone, Debug, Default)]
    pub struct MemoryVfs {
        files: Arc<Mutex<BTreeMap<PathBuf, String>>>,
    }

    impl MemoryVfs {
        /// Create an empty filesystem.
        pub fn new() -> Self {
            Self::default()
        }
    }

    impl Vfs for MemoryVfs {
        fn read_to_string(&self, path: &Path) -> Result<String> {
            self.files
                .lock()
                .unwrap()
                .get(&normalize(path))
                .cloned()
                .ok_or_else(|| {
                    Error::new(
                        ErrorKind::NotFound,
                        format!("file not found: {}", path.display()),
                    )
                })
        }
        fn write_from_string(&self, path: &Path, content: &str) -> Result<()> {
            self.files
                .lock()
                .unwrap()
                .insert(normalize(path), content.into());
            Ok(())
        }
        fn exists(&self, path: &Path) -> bool {
            let path = normalize(path);
            let files = self.files.lock().unwrap();
            files
                .keys()
                .any(|name| path.as_os_str().is_empty() || name.starts_with(&path))
        }
        fn list_dir(&self, path: &Path) -> Result<Vec<PathBuf>> {
            let path = normalize(path);
            Ok(self
                .files
                .lock()
                .unwrap()
                .keys()
                .filter(|name| *name != &path && name.starts_with(&path))
                .cloned()
                .collect())
        }
        fn create_dir_all(&self, _path: &Path) -> Result<()> {
            Ok(())
        }
    }

    fn normalize(path: &Path) -> PathBuf {
        path.components()
            .filter(|component| !matches!(component, Component::CurDir))
            .collect()
    }

    #[cfg(any(target_arch = "wasm32", test))]
    fn unsupported<T>() -> Result<T> {
        Err(Error::new(
            ErrorKind::Unsupported,
            "operating system files are unavailable in the WASM guest",
        ))
    }

    /// The guest has no operating system filesystem capability.
    #[cfg(any(target_arch = "wasm32", test))]
    pub struct OsVfs;
    #[cfg(any(target_arch = "wasm32", test))]
    impl Vfs for OsVfs {
        fn read_to_string(&self, _path: &Path) -> Result<String> {
            unsupported()
        }
        fn write_from_string(&self, _path: &Path, _content: &str) -> Result<()> {
            unsupported()
        }
        fn exists(&self, _path: &Path) -> bool {
            false
        }
        fn list_dir(&self, _path: &Path) -> Result<Vec<PathBuf>> {
            unsupported()
        }
        fn create_dir_all(&self, _path: &Path) -> Result<()> {
            unsupported()
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn generated_files_are_shared_and_relative_paths_are_normalized() {
            let fs = MemoryVfs::new();
            fs.create_dir_all(Path::new("generated/nested")).unwrap();
            fs.write_from_string(
                Path::new("./generated/nested/model.gleam"),
                "pub type T = Int",
            )
            .unwrap();
            let reader = fs.clone();
            assert_eq!(
                reader
                    .read_to_string(Path::new("generated/nested/model.gleam"))
                    .unwrap(),
                "pub type T = Int"
            );
            assert!(reader.exists(Path::new("generated")));
            assert_eq!(
                reader.list_dir(Path::new("generated")).unwrap(),
                vec![PathBuf::from("generated/nested/model.gleam")]
            );
            assert_eq!(
                reader
                    .read_to_string(Path::new("missing"))
                    .unwrap_err()
                    .kind(),
                ErrorKind::NotFound
            );
        }

        #[test]
        fn guest_operating_system_io_reports_unsupported() {
            let fs = OsVfs;
            let path = Path::new("output.gleam");
            assert_eq!(
                fs.write_from_string(path, "content").unwrap_err().kind(),
                ErrorKind::Unsupported
            );
            assert_eq!(
                fs.read_to_string(path).unwrap_err().kind(),
                ErrorKind::Unsupported
            );
            assert_eq!(
                fs.create_dir_all(path).unwrap_err().kind(),
                ErrorKind::Unsupported
            );
            assert_eq!(
                fs.list_dir(path).unwrap_err().kind(),
                ErrorKind::Unsupported
            );
            assert!(!fs.exists(path));
        }
    }
}
