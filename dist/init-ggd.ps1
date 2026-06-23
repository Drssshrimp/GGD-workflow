# GGD 工作流初始化脚本
# 用法：在项目根目录执行 init-ggd

$TemplateDir = "$PSScriptRoot\ggd-template"
$TargetDir = ".claude"

Write-Host " 正在初始化 GGD 工作流..." -ForegroundColor Cyan

# 创建目录
New-Item -ItemType Directory -Force -Path "$TargetDir/ggd" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetDir/hooks" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetDir/docs" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetDir/docs/architecture" | Out-Null


# 复制文件（如果不存在则复制，存在则跳过）
$files = @(
    @{Src="$TemplateDir\state.json"; Dst="$TargetDir\ggd\state.json"},
    @{Src="$TemplateDir\enforce_ggd.py"; Dst="$TargetDir\hooks\enforce_ggd.py"},
    @{Src="$TemplateDir\setting.json"; Dst="$TargetDir\setting.json"},
    @{Src="$TemplateDir\settings.local.json"; Dst="$TargetDir\settings.local.json"},
    @{Src="$TemplateDir\PROJECT.md"; Dst="$TargetDir\docs\PROJECT.md"},
    @{Src="$TemplateDir\REQUIREMENTS.md"; Dst="$TargetDir\docs\REQUIREMENTS.md"},
    @{Src="$TemplateDir\ROADMAP.md"; Dst="$TargetDir\docs\ROADMAP.md"},
    @{Src="$TemplateDir\STATE.md"; Dst="$TargetDir\docs\STATE.md"}
)

foreach ($f in $files) {
    if (-not (Test-Path $f.Dst)) {
        Copy-Item $f.Src -Destination $f.Dst
        Write-Host "  ✅ 复制 $(Split-Path $f.Dst -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "  ⏭️ $(Split-Path $f.Dst -Leaf) 已存在，跳过" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host " GGD 工作流初始化完成！" -ForegroundColor Cyan
