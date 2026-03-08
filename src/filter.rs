#[derive(Debug)]
pub struct FilteredOutput {
    pub stdout: String,
    pub stderr: String,
    pub detected_prompt_injection: Option<bool>,
}

pub fn clamp_output_for_checker(bytes: &[u8], max_output_bytes: Option<usize>) -> String {
    let Some(limit) = max_output_bytes else {
        return String::from_utf8_lossy(bytes).into_owned();
    };

    if bytes.len() <= limit {
        return String::from_utf8_lossy(bytes).into_owned();
    }

    let truncated = String::from_utf8_lossy(&bytes[..limit]).into_owned();
    let dropped = bytes.len().saturating_sub(limit);
    format!("{truncated}\n[TRUNCATED {dropped} BYTES]")
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clamp_output_for_checker_truncates_and_marks_payload() {
        let input = b"abcdef";
        let clamped = clamp_output_for_checker(input, Some(4));
        assert_eq!(clamped, "abcd\n[TRUNCATED 2 BYTES]");
    }
}
