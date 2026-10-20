// Compiled directly by check-stable.sh: no libFuzzer dependency required.
fn main() {
    let corpus = std::env::args().nth(1).expect("corpus directory");
    let mut count = 0;
    for entry in std::fs::read_dir(corpus).unwrap() {
        let path = entry.unwrap().path();
        eprintln!("seed {}", path.display());
        let data = std::fs::read(path).unwrap();
        for target in [emf_fuzz::parse, emf_fuzz::serialize, emf_fuzz::ffi] {
            target(&data);
            // Deterministic public boundary mutations preserve meaningful prefixes.
            for end in [0, 1, 4, 8, 40, 88, data.len().saturating_sub(1)] {
                target(&data[..end.min(data.len())]);
            }
            for offset in [4, 48, 52, 88, 92] {
                if offset + 4 <= data.len() {
                    let mut mutated = data.clone();
                    mutated[offset..offset + 4].fill(0xff);
                    target(&mutated);
                    mutated[offset..offset + 4].fill(0);
                    target(&mutated);
                }
            }
        }
        count += 1;
    }
    println!("stable corpus regression passed: {count} seeds, 3 targets plus boundary mutations");
}
