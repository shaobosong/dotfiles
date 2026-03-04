#!/usr/bin/env bun

import { resolve, basename } from "path";
import { existsSync, statSync } from "fs";

type Section = {
  virtualAddress: number;
  virtualSize: number;
  rawPointer: number;
  rawSize: number;
};

type CliOptions = {
  programName: string;
  searchDirs: string[];
  files: string[];
};

type ParseResult =
  | { ok: true; options: CliOptions }
  | { ok: false; exitCode: number };

class PEFileReader {
  constructor(
    private readonly file: Blob,
    private readonly fileLength: number,
  ) {}

  async parseImportedDlls(): Promise<string[]> {
    const dosHeader = await this.readAt(0, 64);
    if (this.readHex(dosHeader, 0, 2) !== "4d5a") {
      throw new Error("File format not recognized");
    }

    const peOffset = this.readUInt32LE(dosHeader, 0x3c);
    const peAndCoff = await this.readAt(peOffset, 24);
    if (this.readHex(peAndCoff, 0, 4) !== "50450000") {
      throw new Error("PE file's NT_HEADER_SIGNATURE parse error");
    }

    const numberOfSections = this.readUInt16LE(peAndCoff, 6);
    const sizeOfOptionalHeader = this.readUInt16LE(peAndCoff, 20);
    const optionalOffset = peOffset + 24;
    const optionalHeader = await this.readAt(optionalOffset, sizeOfOptionalHeader);

    const optionalMagic = this.readUInt16LE(optionalHeader, 0);
    if (![0x010b, 0x020b, 0x0107].includes(optionalMagic)) {
      throw new Error("PE file's OPTIONAL_HEADER_MAGIC parse error");
    }
    if (optionalMagic === 0x0107) return [];

    const rvaAndSizesOffset = optionalMagic === 0x010b ? 92 : 108;
    const numberOfRvaAndSizes = this.readUInt32LE(optionalHeader, rvaAndSizesOffset);
    if (numberOfRvaAndSizes < 2) return [];

    const dataDirectoryOffset = optionalMagic === 0x010b ? 96 : 112;
    const importDirectoryOffset = dataDirectoryOffset + 8;
    const importRva = this.readUInt32LE(optionalHeader, importDirectoryOffset);
    const importSize = this.readUInt32LE(optionalHeader, importDirectoryOffset + 4);
    if (importRva === 0 || importSize === 0) return [];

    const sections = await this.readSections(optionalOffset + sizeOfOptionalHeader, numberOfSections);
    const importOffset = this.rvaToOffset(importRva, sections);
    if (importOffset === null) return [];

    return this.readImportDescriptors(importOffset, importSize, sections);
  }

  private async readSections(sectionTableOffset: number, numberOfSections: number): Promise<Section[]> {
    const sectionTable = await this.readAt(sectionTableOffset, numberOfSections * 40);
    const sections: Section[] = [];

    for (let i = 0; i < numberOfSections; i++) {
      const sectionOffset = i * 40;
      sections.push({
        virtualSize: this.readUInt32LE(sectionTable, sectionOffset + 8),
        virtualAddress: this.readUInt32LE(sectionTable, sectionOffset + 12),
        rawSize: this.readUInt32LE(sectionTable, sectionOffset + 16),
        rawPointer: this.readUInt32LE(sectionTable, sectionOffset + 20),
      });
    }

    return sections;
  }

  private async readImportDescriptors(
    importOffset: number,
    importSize: number,
    sections: Section[],
  ): Promise<string[]> {
    const dlls: string[] = [];
    const seen = new Set<string>();
    const maxDescriptors = Math.max(1, Math.floor(importSize / 20) + 1);

    for (let index = 0; index < maxDescriptors; index++) {
      const descriptorOffset = importOffset + index * 20;
      if (descriptorOffset + 20 > this.fileLength) break;

      const descriptor = await this.readAt(descriptorOffset, 20);
      const originalFirstThunk = this.readUInt32LE(descriptor, 0);
      const timeDateStamp = this.readUInt32LE(descriptor, 4);
      const forwarderChain = this.readUInt32LE(descriptor, 8);
      const nameRva = this.readUInt32LE(descriptor, 12);
      const firstThunk = this.readUInt32LE(descriptor, 16);

      if (
        originalFirstThunk === 0 &&
        timeDateStamp === 0 &&
        forwarderChain === 0 &&
        nameRva === 0 &&
        firstThunk === 0
      ) {
        break;
      }

      if (nameRva === 0) continue;
      const nameOffset = this.rvaToOffset(nameRva, sections);
      if (nameOffset === null) continue;

      const dllName = (await this.readCStringAt(nameOffset)).trim();
      if (!dllName || seen.has(dllName)) continue;

      seen.add(dllName);
      dlls.push(dllName);
    }

    return dlls;
  }

  private async readAt(offset: number, length: number): Promise<Uint8Array> {
    this.ensureRange(offset, length);
    return new Uint8Array(await this.file.slice(offset, offset + length).arrayBuffer());
  }

  private async readCStringAt(offset: number, maxLength = 512): Promise<string> {
    const length = Math.min(maxLength, Math.max(0, this.fileLength - offset));
    if (length === 0) return "";
    return this.bytesToCString(await this.readAt(offset, length));
  }

  private readUInt16LE(bytes: Uint8Array, offset: number): number {
    this.ensureBufferRange(bytes, offset, 2);
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  private readUInt32LE(bytes: Uint8Array, offset: number): number {
    this.ensureBufferRange(bytes, offset, 4);
    return (
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24)
    ) >>> 0;
  }

  private readHex(bytes: Uint8Array, offset: number, length: number): string {
    this.ensureBufferRange(bytes, offset, length);
    let out = "";
    for (let i = offset; i < offset + length; i++) {
      out += bytes[i].toString(16).padStart(2, "0");
    }
    return out;
  }

  private bytesToCString(bytes: Uint8Array): string {
    let end = 0;
    while (end < bytes.length && bytes[end] !== 0) end++;
    let out = "";
    for (let i = 0; i < end; i++) out += String.fromCharCode(bytes[i]);
    return out;
  }

  private rvaToOffset(rva: number, sections: Section[]): number | null {
    for (const section of sections) {
      const span = Math.max(section.virtualSize, section.rawSize);
      if (rva < section.virtualAddress || rva >= section.virtualAddress + span) continue;

      const delta = rva - section.virtualAddress;
      if (delta >= section.rawSize) continue;

      const offset = section.rawPointer + delta;
      if (offset >= 0 && offset < this.fileLength) return offset;
    }

    if (rva >= 0 && rva < this.fileLength) return rva;
    return null;
  }

  private ensureRange(offset: number, length: number): void {
    if (offset < 0 || length < 0 || offset + length > this.fileLength) {
      throw new Error("PE parse out-of-range read");
    }
  }

  private ensureBufferRange(bytes: Uint8Array, offset: number, length: number): void {
    if (offset < 0 || length < 0 || offset + length > bytes.length) {
      throw new Error("PE parse out-of-range read");
    }
  }
}

function printHelp(programName: string): void {
  console.log(`Usage: ${programName} [options] file
  --help              Print this message
  --dir=<directory>   Append a search directory. Default '.'`);
}

function parseCliArgs(argv: string[]): ParseResult {
  const programName = basename(argv[1] || "ldd.ts");
  const searchDirs: string[] = [process.cwd()];
  const files: string[] = [];
  const args = argv.slice(2);

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (/^-(?:[?]|-?h|--?hel|--?help)$/.test(arg)) {
      printHelp(programName);
      return { ok: false, exitCode: 0 };
    }

    if (arg.startsWith("--dir=")) {
      const newpath = resolve(arg.substring("--dir=".length));
      const index = searchDirs.indexOf(newpath);
      if (index > -1) searchDirs.splice(index, 1);
      searchDirs.push(newpath);
      continue;
    }

    if (arg.startsWith("-")) {
      console.error(`Error: Unknown option '${arg}', see --help for list of valid ones.`);
      return { ok: false, exitCode: 1 };
    }

    files.push(arg);
  }

  if (files.length === 0) {
    console.error(`${programName} missing file arguments`);
    console.error(`Try \`${programName} --help' for more information.`);
    return { ok: false, exitCode: 1 };
  }

  return { ok: true, options: { programName, searchDirs, files } };
}

function resolveSearchPath(fileArg: string): string {
  return fileArg.includes("/") || fileArg.includes("\\") ? fileArg : `./${fileArg}`;
}

function findDependencyLocations(dep: string, searchDirs: string[]): string[] {
  const locations: string[] = [];
  for (const dir of searchDirs) {
    const depPath = resolve(dir, dep);
    if (existsSync(depPath) && statSync(depPath).isFile()) {
      locations.push(dir);
    }
  }
  return locations;
}

function printDependencyResult(dep: string, locations: string[]): void {
  if (locations.length === 0) {
    console.log(`\t${dep} => Not found`);
    return;
  }

  console.log(`\t${dep} => ${locations[0]}`);
  for (let i = 1; i < locations.length; i++) {
    const padding = " ".repeat(dep.length);
    console.log(`\t${padding} => ${locations[i]}`);
  }
}

async function processFile(fileArg: string, options: CliOptions, singleFile: boolean): Promise<number> {
  if (!singleFile) console.log(`${fileArg}:`);

  const fullPath = resolveSearchPath(fileArg);
  if (!existsSync(fullPath)) {
    console.error(`${options.programName}: ${fileArg}: No such file or directory`);
    return 1;
  }

  const stat = statSync(fullPath);
  if (!stat.isFile()) {
    console.error(`${options.programName}: ${fileArg}: not regular file`);
    return 1;
  }

  let deps: string[] = [];
  try {
    deps = await new PEFileReader(Bun.file(fullPath), stat.size).parseImportedDlls();
  } catch (error) {
    const message = error instanceof Error ? error.message : "File format not recognized";
    console.error(`${options.programName}: ${fileArg}: ${message}`);
    return 1;
  }

  if (deps.length === 0) {
    console.error(`${options.programName}: ${fileArg}: not a dynamic executable`);
    return 1;
  }

  for (const dep of deps) {
    printDependencyResult(dep, findDependencyLocations(dep, options.searchDirs));
  }

  return 0;
}

async function main(argv: string[]): Promise<number> {
  const parsed = parseCliArgs(argv);
  if (!parsed.ok) return parsed.exitCode;

  const { options } = parsed;
  const singleFile = options.files.length === 1;
  for (const fileArg of options.files) {
    const code = await processFile(fileArg, options, singleFile);
    if (code !== 0) return code;
  }

  return 0;
}

process.exit(await main(process.argv));
