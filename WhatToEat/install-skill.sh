#!/bin/bash

# SwiftUI Expert Skill 安装脚本

SKILL_SOURCE="/Users/papertiger/Downloads/SwiftUI-Agent-Skill-main/swiftui-expert-skill"
SKILL_TARGET="/Users/papertiger/Desktop/WhatToEat/.trae/skills/swiftui-expert-skill"

echo "正在安装 SwiftUI Expert Skill..."

# 创建目录
mkdir -p "$SKILL_TARGET/references"

# 复制主文件
cp "$SKILL_SOURCE/SKILL.md" "$SKILL_TARGET/"

# 复制参考文件
cp "$SKILL_SOURCE/references/"*.md "$SKILL_TARGET/references/"

echo "✅ SwiftUI Expert Skill 安装完成！"
echo ""
echo "安装路径: $SKILL_TARGET"
echo ""
echo "包含的参考文档:"
ls -1 "$SKILL_TARGET/references/"
