#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const https = require("node:https");

const SKIP_DOWNLOAD_ENV = "GUARDRAILS_INSTALL_SKIP_DOWNLOAD";
const DEFAULT_REPO = "bbondy/guardrails";
const repo = process.env.GUARDRAILS_REPO || DEFAULT_REPO;
const pkg = require(path.join(__dirname, "../../package.json"));
const version = pkg.version;

if (process.env[SKIP_DOWNLOAD_ENV] === "1") {
  console.log(`Skipping guardrails binary download because ${SKIP_DOWNLOAD_ENV}=1`);
  process.exit(0);
}

const target = resolveTarget(process.platform, process.arch);
if (!target) {
  console.error(`Unsupported platform/arch: ${process.platform}/${process.arch}`);
  process.exit(1);
}

const tag = `v${version}`;
const url = `https://github.com/${repo}/releases/download/${tag}/${target.asset}`;
const destination = path.join(__dirname, "..", "bin", target.binaryName);

download(url, destination)
  .then(() => {
    if (process.platform !== "win32") {
      fs.chmodSync(destination, 0o755);
    }
    console.log(`Installed guardrails binary: ${destination}`);
  })
  .catch((error) => {
    console.error(`Failed to download guardrails binary from ${url}`);
    console.error(error.message);
    process.exit(1);
  });

function resolveTarget(platform, arch) {
  if (platform === "darwin" && arch === "arm64") {
    return { asset: "guardrails-darwin-arm64", binaryName: "guardrails-bin" };
  }
  if (platform === "darwin" && arch === "x64") {
    return { asset: "guardrails-darwin-amd64", binaryName: "guardrails-bin" };
  }
  if (platform === "linux" && arch === "arm64") {
    return { asset: "guardrails-linux-arm64", binaryName: "guardrails-bin" };
  }
  if (platform === "linux" && arch === "x64") {
    return { asset: "guardrails-linux-amd64", binaryName: "guardrails-bin" };
  }
  if (platform === "win32" && arch === "arm64") {
    return { asset: "guardrails-windows-arm64.exe", binaryName: "guardrails-bin.exe" };
  }
  if (platform === "win32" && arch === "x64") {
    return { asset: "guardrails-windows-amd64.exe", binaryName: "guardrails-bin.exe" };
  }
  return null;
}

function download(url, destination) {
  return new Promise((resolve, reject) => {
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    const file = fs.createWriteStream(destination);

    fetchWithRedirect(url, 0, (error, response) => {
      if (error) {
        file.close();
        fs.rmSync(destination, { force: true });
        reject(error);
        return;
      }

      response.pipe(file);
      file.on("finish", () => {
        file.close(() => resolve());
      });
      file.on("error", (fileError) => {
        file.close();
        fs.rmSync(destination, { force: true });
        reject(fileError);
      });
    });
  });
}

function fetchWithRedirect(url, redirectCount, callback) {
  if (redirectCount > 5) {
    callback(new Error("Too many redirects while downloading guardrails binary."));
    return;
  }

  const request = https.get(
    url,
    {
      headers: {
        "User-Agent": "@brianbondy/guardrails-installer"
      }
    },
    (response) => {
      if (
        response.statusCode &&
        response.statusCode >= 300 &&
        response.statusCode < 400 &&
        response.headers.location
      ) {
        response.resume();
        fetchWithRedirect(response.headers.location, redirectCount + 1, callback);
        return;
      }

      if (response.statusCode !== 200) {
        response.resume();
        callback(new Error(`Unexpected HTTP status ${response.statusCode}`));
        return;
      }

      callback(null, response);
    }
  );

  request.on("error", (error) => callback(error));
}
