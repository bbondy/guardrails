mod checker;
mod cli;
mod filter;
mod runner;

use clap::Parser;

use crate::cli::{Cli, Mode, parse_mode_and_args};

fn main() {
    let (mode, argv) = parse_mode_and_args();
    let cli = Cli::parse_from(argv);

    if cli.streaming && matches!(mode, Mode::Filter) {
        eprintln!("error: --streaming cannot be used with filter mode");
        std::process::exit(2);
    }
    if cli.streaming && cli.command.is_empty() {
        eprintln!("error: --streaming requires a wrapped command");
        std::process::exit(2);
    }

    runner::run(mode, cli);
}
