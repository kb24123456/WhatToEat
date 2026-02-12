#!/bin/bash

# Superpowers Skills 安装脚本

SOURCE_DIR="/Users/papertiger/Downloads/superpowers-main/skills"
TARGET_DIR="/Users/papertiger/.trae-cn/skills"

echo "正在安装 Superpowers Skills..."
echo ""

# 创建目标目录
mkdir -p "$TARGET_DIR"

# 遍历所有 skill 目录
for skill_dir in "$SOURCE_DIR"/*/; do
    if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")
        
        # 检查是否存在 SKILL.md
        if [ -f "$skill_dir/SKILL.md" ]; then
            echo "📦 安装: $skill_name"
            
            # 复制整个 skill 目录
            cp -r "$skill_dir" "$TARGET_DIR/"
        else
            echo "⚠️  跳过: $skill_name (缺少 SKILL.md)"
        fi
    fi
done

echo ""
echo "✅ Superpowers Skills 安装完成！"
echo ""
echo "安装路径: $TARGET_DIR"
echo ""
echo "已安装的 Skills:"
ls -1 "$TARGET_DIR/"
