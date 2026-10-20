//! Dependency-free, in-memory kernel measurements; see bench/native-kernels.md.
#[path = "../tests/support/sha256.rs"]
mod sha256;

use emf_core::{parse, serialize, Document, ParseLimits, RecordData};
use std::{env, fs, hint::black_box, path::PathBuf, process::Command, time::Instant};

type Result<T> = std::result::Result<T, String>;

struct Options {
    warmups: usize,
    samples: usize,
    fixtures: Vec<PathBuf>,
}

fn options() -> Result<Option<Options>> {
    let mut options = Options {
        warmups: 5,
        samples: 20,
        fixtures: Vec::new(),
    };
    let mut args = env::args().skip(1);
    let mut paths = false;
    while let Some(arg) = args.next() {
        if arg == "--bench" {
            continue;
        } // Cargo may append this after paths.
        if paths {
            options.fixtures.push(arg.into());
            continue;
        }
        match arg.as_str() {
            "--help" | "-h" => {
                println!("parser [--warmups 0..100] [--samples 1..1000] -- FIXTURE [FIXTURE ...]\nExplicit EMF paths only; at most 32. See bench/native-kernels.md.");
                return Ok(None);
            }
            "--" => paths = true,
            "--warmups" | "--samples" => {
                let value = args
                    .next()
                    .ok_or_else(|| format!("missing value for {arg}"))?;
                let value: usize = value
                    .parse()
                    .map_err(|_| format!("invalid integer for {arg}"))?;
                if arg == "--warmups" && value <= 100 {
                    options.warmups = value;
                } else if arg == "--samples" && (1..=1000).contains(&value) {
                    options.samples = value;
                } else {
                    return Err(format!("out of bounds: {arg}={value}"));
                }
            }
            _ => {
                return Err(format!(
                    "unknown argument {arg:?}; put fixture paths after --"
                ))
            }
        }
    }
    if options.fixtures.is_empty() || options.fixtures.len() > 32 {
        return Err("provide between 1 and 32 explicit fixture paths after --".into());
    }
    Ok(Some(options))
}

fn command(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_owned())
        .unwrap_or_else(|| "unavailable".into())
}

// Each result survives the end timestamp. Destruction is outside the measured
// interval, avoiding retained batches whose memory grows with the sample count.
fn measure<T>(
    name: &str,
    options: &Options,
    mut operation: impl FnMut() -> Result<T>,
) -> Result<()> {
    for _ in 0..options.warmups {
        drop(black_box(operation()?));
    }
    let mut samples = Vec::with_capacity(options.samples);
    for _ in 0..options.samples {
        let start = Instant::now();
        let result = black_box(operation()?);
        let elapsed = start.elapsed().as_nanos();
        drop(result);
        samples.push(elapsed);
    }
    let mut sorted = samples.clone();
    sorted.sort_unstable();
    let n = sorted.len();
    let median = if n % 2 == 0 {
        sorted[n / 2 - 1] as f64 / 2.0 + sorted[n / 2] as f64 / 2.0
    } else {
        sorted[n / 2] as f64
    };
    let p95 = sorted[(95 * n).div_ceil(100) - 1];
    println!("kernel={name} unit=ns median={median} p95={p95} samples={samples:?}");
    Ok(())
}

fn edited_document(
    document: &Document,
    input: &[u8],
    limits: &ParseLimits,
) -> Result<Option<Document>> {
    for (index, record) in document.records().iter().enumerate() {
        let mut data = record.data().clone();
        let family = match &mut data {
            RecordData::SetTextColor { color } => {
                color.red ^= 1;
                "SetTextColor"
            }
            RecordData::SetBkColor { color } => {
                color.red ^= 1;
                "SetBkColor"
            }
            RecordData::MoveToEx { origin } => {
                origin.x ^= 1;
                "MoveToEx"
            }
            _ => continue,
        };
        let mut edited = document.clone();
        edited
            .edit_record(index, data.clone())
            .map_err(|e| format!("edit: {e:?}"))?;
        let bytes = serialize(&edited).map_err(|e| format!("edited serialize: {e:?}"))?;
        if bytes == input {
            return Err("typed edit did not change bytes".into());
        }
        let reparsed = parse(&bytes, limits).map_err(|e| format!("edited reparse: {e:?}"))?;
        if reparsed.records().get(index).map(|r| r.data()) != Some(&data)
            || serialize(&reparsed).map_err(|e| format!("edited roundtrip: {e:?}"))? != bytes
        {
            return Err("typed edit failed reparse/roundtrip guard".into());
        }
        println!(
            "editable_serialize=supported record_index={index} family={family} sha256={}",
            sha256::digest(&bytes)
        );
        return Ok(Some(edited));
    }
    println!("editable_serialize=unsupported reason=no_SetTextColor_SetBkColor_or_MoveToEx");
    Ok(None)
}

fn run() -> Result<()> {
    let Some(options) = options()? else {
        return Ok(());
    };
    println!("schema=emf-native-kernels-v1");
    println!(
        "build_profile={:?} build_rustc={:?} debug_assertions={} os={} arch={}",
        option_env!("EMF_BENCH_PROFILE").unwrap_or("unavailable"),
        option_env!("EMF_BENCH_RUSTC").unwrap_or("unavailable"),
        cfg!(debug_assertions),
        env::consts::OS,
        env::consts::ARCH
    );
    println!(
        "revision={:?} working_tree={:?}",
        command("git", &["rev-parse", "HEAD"]),
        command("git", &["status", "--porcelain"])
    );
    println!(
        "host={:?} cpu={:?}",
        command("uname", &["-a"]),
        command("sysctl", &["-n", "machdep.cpu.brand_string"])
    );
    println!("warmups={} samples={} timing=in_memory_result_destruction_excluded file_io=excluded limits=default", options.warmups, options.samples);
    let limits = ParseLimits::default();
    for path in &options.fixtures {
        if fs::metadata(path)
            .map_err(|e| format!("{path:?}: {e}"))?
            .len()
            > limits.max_input_bytes as u64
        {
            return Err(format!("{path:?}: exceeds default input limit"));
        }
        let bytes = fs::read(path).map_err(|e| format!("{path:?}: {e}"))?;
        let document = parse(&bytes, &limits).map_err(|e| format!("{path:?}: parse: {e:?}"))?;
        if serialize(&document).map_err(|e| format!("serialize guard: {e:?}"))? != bytes {
            return Err(format!("{path:?}: exact unchanged roundtrip failed"));
        }
        println!(
            "fixture={path:?} bytes={} sha256={} records={} diagnostics={} exact_roundtrip=passed",
            bytes.len(),
            sha256::digest(&bytes),
            document.records().len(),
            document.diagnostics().len()
        );
        let edited = edited_document(&document, &bytes, &limits)?;
        measure("parse_only", &options, || {
            parse(black_box(&bytes), black_box(&limits)).map_err(|e| format!("parse: {e:?}"))
        })?;
        measure("serialize_only", &options, || {
            serialize(black_box(&document)).map_err(|e| format!("serialize: {e:?}"))
        })?;
        measure("parse_serialize", &options, || {
            let parsed = parse(black_box(&bytes), black_box(&limits))
                .map_err(|e| format!("parse: {e:?}"))?;
            let output = serialize(black_box(&parsed)).map_err(|e| format!("serialize: {e:?}"))?;
            Ok((parsed, output))
        })?;
        if let Some(edited) = edited {
            measure("editable_serialize", &options, || {
                serialize(black_box(&edited)).map_err(|e| format!("serialize: {e:?}"))
            })?;
        }
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("native kernel benchmark: {error}");
        std::process::exit(1);
    }
}
