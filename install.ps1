# GGD Workflow 安装脚本
# 用法:
#   .\install.ps1          全局安装到 ~/.claude/
#   .\install.ps1 -Local   安装到当前项目 .claude/

param(
    [switch]$Local
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistDir = "$ScriptDir\dist"

# === 确定目标路径 ===
if ($Local) {
    $TargetDir = "$PWD\.claude"
    Write-Host "📁 安装模式: 项目级 ($TargetDir)" -ForegroundColor Cyan
} else {
    $TargetDir = "$env:USERPROFILE\.claude"
    Write-Host "📁 安装模式: 全局 ($TargetDir)" -ForegroundColor Cyan
}

# === 检查 dist 目录 ===
if (-not (Test-Path $DistDir)) {
    Write-Host "❌ 找不到 dist/ 目录，请从仓库根目录运行此脚本" -ForegroundColor Red
    exit 1
}

# === 创建目标目录 ===
$dirs = @("agents", "commands", "templates", "hooks")
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path "$TargetDir\$d" | Out-Null
}

# === 复制文件并替换占位符 ===
Write-Host "📋 正在复制文件..." -ForegroundColor Yellow

$items = @(
    @{Src="agents";     Dst="$TargetDir\agents"},
    @{Src="commands";   Dst="$TargetDir\commands"},
    @{Src="templates";  Dst="$TargetDir\templates"},
    @{Src="hooks";      Dst="$TargetDir\hooks"}
)

# ggd-template 处理
if ($Local) {
    # 项目级：ggd-template 内容直接合并到 .claude/ 下
    Write-Host "  🔧 项目级安装: 合并 ggd-template 到项目 .claude/" -ForegroundColor Yellow
    Copy-Item "$DistDir\ggd-template\*" -Destination "$TargetDir\" -Force
} else {
    # 全局：ggd-template 保持独立目录 + 放置 init-ggd.ps1
    New-Item -ItemType Directory -Force -Path "$TargetDir\ggd-template" | Out-Null
    Copy-Item "$DistDir\ggd-template\*" -Destination "$TargetDir\ggd-template\" -Force
    Copy-Item "$DistDir\init-ggd.ps1" -Destination "$TargetDir\init-ggd.ps1" -Force
    Write-Host "  ✅ init-ggd.ps1"
}

foreach ($item in $items) {
    Copy-Item "$DistDir\$($item.Src)\*" -Destination "$($item.Dst)\" -Force
    Write-Host "  ✅ $($item.Src)/"
}

# === 路径替换：__CLAUDE_HOME__ → 实际路径 ===
Write-Host "🔄 正在替换占位符..." -ForegroundColor Yellow

$targetForward = $TargetDir.Replace('\', '/')
$targetBack = $TargetDir

$files = Get-ChildItem -Recurse -Path $TargetDir -Include *.md,*.py,*.json | Where-Object {
    $_.FullName -notmatch '\\projects\\|\\file-history\\|\\shell-snapshots\\|\\paste-cache\\'
}

foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($content -match '__CLAUDE_HOME__') {
        $content = $content.Replace('__CLAUDE_HOME__/', $targetForward + '/')
        $content = $content.Replace('__CLAUDE_HOME__\', $targetBack + '\')
        Set-Content $f.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  🔧 $($f.Name)"
    }
}

# === 合并 hook 配置到 settings.local.json ===
Write-Host "⚙️  正在配置 hook..." -ForegroundColor Yellow

$settingsFile = "$TargetDir\settings.local.json"
$hookEntry = @{
    PreToolUse = @(
        @{
            matcher = "Write|Edit"
            hooks = @(
                @{
                    type = "command"
                    command = "python .claude/hooks/enforce_ggd.py"
                    timeout = 30
                }
            )
        },
        @{
            matcher = "Read"
            hooks = @(
                @{
                    type = "command"
                    command = "python .claude/hooks/enforce_ggd.py"
                    timeout = 30
                }
            )
        }
    )
}

if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
} else {
    $settings = @{}
}

if (-not $settings.hooks) {
    $settings | Add-Member -MemberType NoteProperty -Name hooks -Value $hookEntry -Force
} else {
    $existing = $settings.hooks
    if (-not $existing.PreToolUse) {
        $existing | Add-Member -MemberType NoteProperty -Name PreToolUse -Value $hookEntry.PreToolUse -Force
    } else {
        # 检查是否已存在 enforce_ggd.py
        $already = $false
        foreach ($h in $existing.PreToolUse) {
            if ($h.hooks[0].command -match 'enforce_ggd') {
                $already = $true
                break
            }
        }
        if (-not $already) {
            $existing.PreToolUse += $hookEntry.PreToolUse
        } else {
            Write-Host "  ⏭️  hook 已存在，跳过" -ForegroundColor Yellow
        }
    }
}

$settings | ConvertTo-Json -Depth 6 | Set-Content $settingsFile -Encoding UTF8

# === 追加 GGD 函数到 PowerShell Profile ===
Write-Host "📝 正在配置 PowerShell 命令..." -ForegroundColor Yellow

$ggdFunctions = @'

# ===== GGD 工作流命令（由 install.ps1 自动添加）=====
function ggd-status {
    Get-Content .claude/ggd/state.json | ConvertFrom-Json | ConvertTo-Json
}
function ggd-approve-plan {
    '{"current_phase":"waiting_requirements","plan_approved":true,"requirements_approved":false}' | Set-Content .claude/ggd/state.json
    Write-Host "✅ 已批准 plan，当前状态: waiting_requirements" -ForegroundColor Green
}
function ggd-approve-reqs {
    '{"current_phase":"developing","plan_approved":true,"requirements_approved":true}' | Set-Content .claude/ggd/state.json
    Write-Host "✅ 已批准需求文档，当前状态: developing（可以开始开发）" -ForegroundColor Green
}
function ggd-done {
    '{"current_phase":"done","plan_approved":true,"requirements_approved":true}' | Set-Content .claude/ggd/state.json
    Write-Host "🎉 项目完成，当前状态: done" -ForegroundColor Green
}
function ggd-reset {
    '{"current_phase":"planning","plan_approved":false,"requirements_approved":false}' | Set-Content .claude/ggd/state.json
    Write-Host "🔄 已重置状态: planning" -ForegroundColor Yellow
}
function init-ggd {
    & "$env:USERPROFILE\.claude\init-ggd.ps1"
}
# ===== GGD END =====
'@

$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Force -Path $profilePath | Out-Null
}

$profileContent = Get-Content $profilePath -Raw -Encoding UTF8
if ($profileContent -notmatch '===== GGD 工作流命令 =====') {
    Add-Content -Path $profilePath -Value $ggdFunctions -Encoding UTF8
    Write-Host "  ✅ 已追加 GGD 命令到 PowerShell Profile" -ForegroundColor Green
} else {
    Write-Host "  ⏭️  GGD 命令已存在，跳过" -ForegroundColor Yellow
}

# === 完成 ===
Write-Host ""
Write-Host "✅ GGD 工作流安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "下一步：" -ForegroundColor Cyan
Write-Host "  执行“. `$PROFILE“ 重载 PowerShell 配置" -ForegroundColor White
if (-not $Local) {
    Write-Host "   在项目目录执行 init-ggd  初始化项目" -ForegroundColor White
}
Write-Host ""
