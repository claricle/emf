//! Structural no-format-mixing guard: the PNG model crate must carry zero
//! DIB concepts, the DIB model crate zero PNG concepts, and the transformer
//! must be the only crate importing both. Enforced by reading the sibling
//! manifests at test time so a stray dependency fails loudly.
use std::fs;
use std::path::{Path, PathBuf};

fn workspace_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("crate under workspace crates/")
        .to_path_buf()
}

fn manifest(crate_name: &str) -> String {
    fs::read_to_string(workspace_root().join(crate_name).join("Cargo.toml"))
        .unwrap_or_else(|error| panic!("{crate_name} manifest readable: {error}"))
}

fn declared_deps(crate_name: &str) -> Vec<String> {
    let text = manifest(crate_name);
    let mut deps = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        if let Some(rest) = line
            .strip_prefix("dib-model")
            .or_else(|| line.strip_prefix("png-model"))
            .or_else(|| line.strip_prefix("emf-core"))
            .or_else(|| line.strip_prefix("emf-ffi"))
        {
            if rest.starts_with(' ') || rest.starts_with('=') {
                deps.push(line.split_whitespace().next().expect("token").to_string());
            }
        }
    }
    deps
}

#[test]
fn png_model_carries_no_dib_or_emf_concepts() {
    let deps = declared_deps("png-model");
    assert!(
        deps.iter()
            .all(|dep| dep != "dib-model" && dep != "emf-core" && dep != "emf-ffi"),
        "png-model must not depend on DIB or EMF crates; found {deps:?}"
    );
}

#[test]
fn dib_model_carries_no_png_or_emf_concepts() {
    let deps = declared_deps("dib-model");
    assert!(
        deps.iter()
            .all(|dep| dep != "png-model" && dep != "emf-core" && dep != "emf-ffi"),
        "dib-model must not depend on PNG or EMF crates; found {deps:?}"
    );
}

#[test]
fn transformer_is_the_only_meeting_point() {
    let deps = declared_deps("dib-png");
    assert!(
        deps.contains(&"dib-model".to_string()) && deps.contains(&"png-model".to_string()),
        "dib-png must depend on both models; found {deps:?}"
    );
    for sibling in ["png-model", "dib-model", "emf-core", "emf-ffi"] {
        let deps = declared_deps(sibling);
        let both =
            deps.contains(&"dib-model".to_string()) && deps.contains(&"png-model".to_string());
        assert!(
            !both,
            "{sibling} must not import both bitmap formats; found {deps:?}"
        );
    }
}
