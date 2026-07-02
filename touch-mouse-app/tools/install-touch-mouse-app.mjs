#!/usr/bin/env node
// 一键安装触摸滑动 App，并同步 Karabiner 配置。

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const scriptDir = path.dirname(new URL(import.meta.url).pathname);
const projectDir = path.resolve(scriptDir, '..');
const appName = 'SiriRemoteHIDProbe';
const appBundleName = `${appName}.app`;
const builtAppPath = path.join(projectDir, 'build', appBundleName);
const installedAppPath = `/Applications/${appBundleName}`;
const sourceKarabinerConfigPath = path.join(projectDir, 'karabiner-siri-remote-safe.json');
const installedKarabinerConfigPath = path.join(os.homedir(), '.config/karabiner/karabiner.json');
const backupDir = path.join(os.homedir(), '.config/karabiner/automatic_backups');
const configureScriptPath = path.join(projectDir, 'tools/configure-touch-toggle.mjs');
const karabinerCliPath = '/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli';
const appExecutablePath = `${installedAppPath}/Contents/MacOS/${appName}`;
const multitouchExtensionName = 'Karabiner-MultitouchExtension';

function timestamp() {
  return new Date().toISOString().replace(/[-:]/g, '').replace(/\..+$/, '');
}

function runCommand(command, args, options = {}) {
  const dryRun = options.dryRun ?? false;
  const cwd = options.cwd ?? projectDir;
  const label = [command, ...args].join(' ');

  if (dryRun) {
    console.log(`[dry-run] ${label}`);
    return;
  }

  console.log(`[run] ${label}`);
  const result = spawnSync(command, args, {
    cwd,
    stdio: 'inherit'
  });

  if (result.status !== 0) {
    throw new Error(`命令失败：${label}`);
  }
}

function copyFile(source, target, dryRun) {
  if (dryRun) {
    console.log(`[dry-run] copy ${source} -> ${target}`);
    return;
  }

  fs.copyFileSync(source, target);
}

function ensureDirectory(directoryPath, dryRun) {
  if (dryRun) {
    console.log(`[dry-run] mkdir -p ${directoryPath}`);
    return;
  }

  fs.mkdirSync(directoryPath, { recursive: true });
}

function backupKarabinerConfig(dryRun) {
  ensureDirectory(backupDir, dryRun);
  if (!fs.existsSync(installedKarabinerConfigPath)) {
    console.log('[skip] 当前没有已安装的 Karabiner 配置，跳过备份。');
    return;
  }

  const backupPath = path.join(backupDir, `karabiner-before-touch-mouse-install-${timestamp()}.json`);
  copyFile(installedKarabinerConfigPath, backupPath, dryRun);
}

function findProcessIds(pattern, dryRun) {
  if (dryRun) {
    console.log(`[dry-run] pgrep -f ${pattern}`);
    return [];
  }

  const result = spawnSync('/usr/bin/pgrep', ['-f', pattern], {
    encoding: 'utf8'
  });

  if (result.status !== 0 || !result.stdout.trim()) {
    return [];
  }

  return result.stdout
    .trim()
    .split('\n')
    .map((value) => Number(value))
    .filter((value) => Number.isInteger(value) && value > 0 && value !== process.pid);
}

function terminateProcesses(pattern, dryRun) {
  const pids = findProcessIds(pattern, dryRun);
  for (const pid of pids) {
    if (dryRun) {
      console.log(`[dry-run] kill -TERM ${pid}`);
      continue;
    }

    try {
      process.kill(pid, 'SIGTERM');
      console.log(`[run] kill -TERM ${pid}`);
    } catch (error) {
      console.log(`[skip] 无法结束进程 ${pid}：${error.message}`);
    }
  }
}

function createInstallPlan() {
  return [
    '生成 Karabiner 可配置触摸开关规则',
    '运行配置脚本自测',
    '编译触摸滑动 App 并运行自测',
    '打包 SiriRemoteHIDProbe.app',
    '备份当前 Karabiner 配置',
    '同步 Karabiner 配置',
    '复制 App 到 /Applications',
    '重启 App 和 Karabiner 多点触控扩展',
    '验证 Karabiner 配置与当前 profile'
  ];
}

function install(options = {}) {
  const dryRun = options.dryRun ?? false;

  console.log('安装计划：');
  for (const [index, step] of createInstallPlan().entries()) {
    console.log(`${index + 1}. ${step}`);
  }

  runCommand('node', [configureScriptPath], { dryRun });
  runCommand('node', [configureScriptPath, '--self-test'], { dryRun });
  runCommand('make', ['test'], { cwd: projectDir, dryRun });
  runCommand('make', ['app'], { cwd: projectDir, dryRun });
  runCommand(karabinerCliPath, ['--lint-complex-modifications', sourceKarabinerConfigPath], { dryRun });
  backupKarabinerConfig(dryRun);
  copyFile(sourceKarabinerConfigPath, installedKarabinerConfigPath, dryRun);
  runCommand('ditto', [builtAppPath, installedAppPath], { dryRun });
  terminateProcesses(appExecutablePath, dryRun);
  terminateProcesses(multitouchExtensionName, dryRun);
  runCommand('open', [installedAppPath], { dryRun });
  runCommand(karabinerCliPath, ['--lint-complex-modifications', installedKarabinerConfigPath], { dryRun });
  runCommand(karabinerCliPath, ['--show-current-profile-name'], { dryRun });

  console.log(dryRun ? '[dry-run] 预演完成，未修改系统。' : '[done] 触摸滑动 App 已安装并启动。');
}

function runSelfTest() {
  const plan = createInstallPlan();
  assert.equal(plan.length, 9);
  assert.equal(plan[0], '生成 Karabiner 可配置触摸开关规则');
  assert.equal(plan.at(-1), '验证 Karabiner 配置与当前 profile');
  assert.equal(path.basename(configureScriptPath), 'configure-touch-toggle.mjs');
  assert.equal(path.basename(installedAppPath), appBundleName);
  assert.equal(installedKarabinerConfigPath.endsWith('.config/karabiner/karabiner.json'), true);

  console.log('[self-test] passed');
}

function main() {
  const args = new Set(process.argv.slice(2));
  if (args.has('--self-test')) {
    runSelfTest();
    return;
  }

  install({ dryRun: args.has('--dry-run') });
}

main();
