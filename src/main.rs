mod checker;
mod cli;
mod filter;
mod runner;

use clap::Parser;

use crate::cli::{Cli, parse_mode_and_args};

fn main() {
    let (mode, argv) = parse_mode_and_args();
    let cli = Cli::parse_from(argv);

    if cli.pty && cli.command.is_empty() {
        eprintln!("error: --pty requires a wrapped command");
        std::process::exit(2);
    }

    runner::run(mode, cli);
}
