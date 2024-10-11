use std::process::{Command, ExitCode};

fn main() -> ExitCode {
    let mut child = match Command::new("/usr/bin/drill")
        .args(std::env::args().skip(1))
        .spawn() {
        Ok(child) => child,
        Err(e) => {
            eprintln!("Unable to launch drill process: {e:?}");
            return ExitCode::from(1);
        }
    };

    match child.wait() {
        // Return 0 on 0 exit code
        Ok(status) if status.success() => ExitCode::from(0),
        // Return 1 on any other exit code
        Ok(_) => ExitCode::from(1),
        Err(e) => {
            eprintln!("Error waiting for drill process to finish: {e:?}");
            ExitCode::from(1)
        }
    }
}
