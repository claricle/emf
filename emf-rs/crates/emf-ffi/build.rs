fn main() {
    // Apple's default install name embeds the build directory in the library.
    // Keep the cdylib identity stable across clean builds in different directories.
    if std::env::var("CARGO_CFG_TARGET_VENDOR").as_deref() == Ok("apple") {
        println!("cargo:rustc-cdylib-link-arg=-Wl,-install_name,@rpath/libemf_ffi.dylib");
    }
}
