use clap::{Parser, ValueEnum};

#[derive(Parser)]
#[command(name = "guardrails", version)]
pub struct Cli {
    /// Tool to use for prompt-injection checks
    #[arg(long, value_enum)]
    pub checker: CheckerTool,

    /// Checker executable path. Defaults to checker-specific command names.
    #[arg(long)]
    pub checker_cmd: Option<String>,

    /// Extra args passed to the checker executable (repeatable). If provided, prompt is sent via stdin.
    #[arg(long)]
    pub checker_arg: Vec<String>,

    /// Extra context passed to the checker prompt payload (repeatable)
    #[arg(long)]
    pub checker_context: Vec<String>,

    /// Permission hints passed to the checker prompt payload (repeatable)
    #[arg(long)]
    pub checker_permission: Vec<String>,

    /// Wrapped command and arguments. Example: -- gh issue list
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    pub command: Vec<String>,

    /// Logical command name when scanning stdin (no wrapped command provided)
    #[arg(long, default_value = "stdin")]
    pub command_name: String,

    /// Exit code to return in stdin pass-through mode when verdict is safe
    #[arg(long, default_value_t = 0)]
    pub exit_code: i32,

    /// Marker printed to stderr when filtering is applied in filter mode
    #[arg(long, default_value = "<filtered/>")]
    pub filter_token: String,

    /// Timeout (milliseconds) for checker tool execution
    #[arg(long)]
    pub checker_timeout_ms: Option<u64>,

    /// Maximum bytes per stream (stdout/stderr) sent to checker
    #[arg(long)]
    pub max_output_bytes: Option<usize>,

    /// Stream wrapped command output directly (no checker pass; local detector still applies)
    #[arg(long)]
    pub streaming: bool,

    /// Run wrapped command under a pseudo-terminal in buffered mode to preserve TTY-style formatting
    #[arg(long)]
    pub pty: bool,
}

#[derive(Copy, Clone, Debug, ValueEnum)]
pub enum CheckerTool {
    Codex,
    Claude,
    Gemini,
    #[value(alias = "cursor-agent")]
    Agent,
}

impl CheckerTool {
    pub fn id(self) -> &'static str {
        match self {
            CheckerTool::Codex => "codex",
            CheckerTool::Claude => "claude",
            CheckerTool::Gemini => "gemini",
            CheckerTool::Agent => "agent",
        }
    }

    pub fn default_cmd(self) -> &'static str {
        match self {
            CheckerTool::Codex => "codex",
            CheckerTool::Claude => "claude",
            CheckerTool::Gemini => "gemini",
            CheckerTool::Agent => "agent",
        }
    }

    pub fn fallback_cmds(self) -> &'static [&'static str] {
        match self {
            CheckerTool::Codex | CheckerTool::Claude | CheckerTool::Gemini => &[],
            CheckerTool::Agent => &["cursor-agent"],
        }
    }
}

#[derive(Copy, Clone, Debug)]
pub enum Mode {
    Check,
    Filter,
}

pub fn parse_mode_and_args() -> (Mode, Vec<String>) {
    let mut argv: Vec<String> = std::env::args().collect();
    if argv.get(1).is_some_and(|arg| arg == "filter") {
        argv.remove(1);
        return (Mode::Filter, argv);
    }
    (Mode::Check, argv)
}
