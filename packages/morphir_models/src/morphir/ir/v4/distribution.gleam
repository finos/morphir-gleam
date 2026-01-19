//// Distribution types for Morphir IR v4.
////
//// This module defines the structure of distribution packages, including
//// libraries, specifications, and applications, as well as VFS manifest types.

import gleam/dict.{type Dict}
import gleam/option.{type Option}
import morphir/ir/access_controlled.{type AccessControlled}
import morphir/ir/documented.{type Documented}
import morphir/ir/fqname.{type FQName}
import morphir/ir/name.{type Name}
import morphir/ir/package.{type PackageName}
import morphir/ir/v4/type_ as t
import morphir/ir/v4/value as v

/// Module definition containing types and values.
pub type ModuleDefinition(ta, va) {
  ModuleDefinition(
    types: Dict(Name, AccessControlled(Documented(t.Definition(ta)))),
    values: Dict(Name, AccessControlled(Documented(v.Definition(ta, va)))),
  )
}

/// Module specification containing type and value specifications.
pub type ModuleSpecification(ta) {
  ModuleSpecification(
    types: Dict(Name, Documented(t.Specification(ta))),
    values: Dict(Name, Documented(v.Specification(ta))),
  )
}

/// Package definition containing modules.
pub type PackageDefinition(ta, va) {
  PackageDefinition(
    modules: Dict(Name, AccessControlled(ModuleDefinition(ta, va))),
  )
}

/// Package specification containing module specifications.
pub type PackageSpecification(ta) {
  PackageSpecification(modules: Dict(Name, ModuleSpecification(ta)))
}

/// Information about a package.
pub type PackageInfo {
  PackageInfo(name: PackageName, version: String)
}

/// Entry point kind.
pub type EntryPointKind {
  Main
  Command
  Handler
  Job
  Policy
}

/// Entry point definition.
pub type EntryPoint {
  EntryPoint(target: FQName, kind: EntryPointKind, doc: Option(String))
}

/// A library distribution.
pub type LibraryDistribution(ta, va) {
  LibraryDistribution(
    package_info: PackageInfo,
    definition: PackageDefinition(ta, va),
    dependencies: Dict(PackageName, PackageSpecification(ta)),
  )
}

/// A specification distribution.
pub type SpecsDistribution(ta) {
  SpecsDistribution(
    package_info: PackageInfo,
    specification: PackageSpecification(ta),
    dependencies: Dict(PackageName, PackageSpecification(ta)),
  )
}

/// An application distribution.
pub type ApplicationDistribution(ta, va) {
  ApplicationDistribution(
    package_info: PackageInfo,
    definition: PackageDefinition(ta, va),
    dependencies: Dict(PackageName, PackageDefinition(ta, va)),
    entry_points: Dict(Name, EntryPoint),
  )
}

/// The main distribution type.
pub type Distribution(ta, va) {
  Library(LibraryDistribution(ta, va))
  Specs(SpecsDistribution(ta))
  Application(ApplicationDistribution(ta, va))
}

/// Distribution mode for VFS manifest.
pub type DistributionMode {
  ClassicMode
  VfsMode
}

/// VFS Manifest (format.json).
pub type VfsManifest {
  VfsManifest(
    format_version: String,
    layout: DistributionMode,
    package_name: PackageName,
    created: String,
  )
}
