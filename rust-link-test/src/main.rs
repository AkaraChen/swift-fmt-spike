// Rust -> Swift FFI link test for the SwiftFmtShim static library.
//
// Proves, per platform:
//   1. the static lib + Swift runtime link into a plain Rust binary,
//   2. swiftfmt_format() round-trips through the C ABI and formats Swift,
//   3. error paths return NULL,
//   4. per-call latency over 50 calls,
//   5. the formatter is usable from multiple threads concurrently.
use std::ffi::{c_char, CStr, CString};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::thread;
use std::time::Instant;

extern "C" {
    fn swiftfmt_version() -> *const c_char;
    fn swiftfmt_format(input: *const c_char, filename: *const c_char) -> *mut c_char;
    fn swiftfmt_free(ptr: *mut c_char);
}

// Deliberately unformatted Swift: a generic struct with a mutating method and
// a string interpolation, packed onto few lines with missing whitespace.
const SAMPLE: &str = r#"struct   Box<T:Comparable>{var items:[T]=[]
mutating   func add(_ item:T){items.append(item)}
func summary()->String{"Box has \(items.count) item(s)"}
}

let b=Box<Int>(items:[3,1,2]);print(b.summary())"#;

fn call_format(src: &[u8]) -> Option<String> {
    let mut buf = src.to_vec();
    buf.push(0); // NUL-terminate for the C ABI
    unsafe {
        let fname = CString::new("sample.swift").unwrap();
        let ptr = swiftfmt_format(buf.as_ptr() as *const c_char, fname.as_ptr());
        if ptr.is_null() {
            return None;
        }
        let out = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        swiftfmt_free(ptr);
        Some(out)
    }
}

fn main() {
    println!("== swift-fmt spike: Rust -> Swift static library link test ==");

    unsafe {
        let v = swiftfmt_version();
        assert!(!v.is_null(), "swiftfmt_version returned NULL");
        println!("version: {}", CStr::from_ptr(v).to_string_lossy());
    }

    // 0a. Empty-input probe: format() short-circuits before parsing, so this
    // exercises the Swift runtime + FFI boundary without the parser.
    match call_format(b"") {
        Some(s) => println!("empty-input probe: OK ({} bytes)", s.len()),
        None => println!("empty-input probe: NULL"),
    }

    // 0b. Tiny-input probe: full parse + pretty-print of one line.
    let tiny = call_format(b"let x = 1\n").expect("tiny-input probe returned NULL");
    println!("tiny-input probe: OK ({:?})", tiny);

    // 1. Basic formatting through the C ABI.
    let out = call_format(SAMPLE.as_bytes())
        .expect("swiftfmt_format returned NULL for valid input");
    println!("---- formatted output ----\n{out}\n--------------------------");
    assert!(out != SAMPLE, "output identical to input: formatter did not run");
    assert!(
        out.contains("struct Box<T: Comparable>"),
        "expected normalized generic declaration, got:\n{out}"
    );
    println!("format round-trip: OK");

    // 2. Idempotency: formatting the formatter's own output must be a no-op.
    let out2 = call_format(out.as_bytes()).expect("second formatting pass returned NULL");
    assert_eq!(out2, out, "formatter is not idempotent");
    println!("idempotency: OK");

    // 3. Invalid UTF-8 input must yield NULL (not a crash, not mojibake).
    let bad: &[u8] = b"let x = \"\xff\xfe\"";
    assert!(call_format(bad).is_none(), "invalid UTF-8 should return NULL");
    println!("invalid-UTF8 -> NULL: OK");

    // 4. Per-call latency over 50 calls (after 5 warmups).
    for _ in 0..5 {
        let _ = call_format(SAMPLE.as_bytes());
    }
    let mut samples_us: Vec<f64> = Vec::with_capacity(50);
    for _ in 0..50 {
        let t = Instant::now();
        let _ = call_format(SAMPLE.as_bytes()).expect("latency call returned NULL");
        samples_us.push(t.elapsed().as_secs_f64() * 1e6);
    }
    samples_us.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let avg = samples_us.iter().sum::<f64>() / samples_us.len() as f64;
    let p50 = samples_us[samples_us.len() / 2];
    let p95 = samples_us[(samples_us.len() as f64 * 0.95) as usize];
    println!(
        "latency over {} calls: avg={:.1}us p50={:.1}us p95={:.1}us min={:.1}us max={:.1}us",
        samples_us.len(),
        avg,
        p50,
        p95,
        samples_us[0],
        samples_us[samples_us.len() - 1]
    );

    // 5. Concurrency probe: 4 threads x 10 calls each. The shim creates a
    // fresh parser + formatter per call; this checks that nothing else in the
    // Swift runtime/formatter stack blows up under parallel Rust threads.
    let fails = AtomicUsize::new(0);
    thread::scope(|s| {
        for _ in 0..4 {
            s.spawn(|| {
                for _ in 0..10 {
                    if call_format(SAMPLE.as_bytes()).is_none() {
                        fails.fetch_add(1, Ordering::SeqCst);
                    }
                }
            });
        }
    });
    assert_eq!(
        fails.load(Ordering::SeqCst),
        0,
        "concurrent formatting calls failed"
    );
    println!("concurrency probe (4 threads x 10 calls): OK");

    println!("ALL CHECKS PASSED");
}
