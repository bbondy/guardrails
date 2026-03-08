#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { spawnSync } = require("node:child_process");

const binaryName = process.platform === "win32" ? "guardrails-bin.exe" : "guardrails-bin";
const binaryPath = path.join(__dirname, binaryName);

if (!fs.existsSync(binaryPath)) {
  console.error(
    "guardrails binary is missing. Reinstall @brianbondy/guardrails to download the platform binary."
  );
  process.exit(1);
}

const result = spawnSync(binaryPath, process.argv.slice(2), { stdio: "inherit" });
if (result.error) {
  console.error(`Failed to run guardrails: ${result.error.message}`);
  process.exit(1);
}

if (result.status !== null) {
  process.exit(result.status);
}

if (result.signal) {
  const signalCode = os.constants.signals[result.signal];
  process.exit(typeof signalCode === "number" ? 128 + signalCode : 1);
}

process.exit(1);
