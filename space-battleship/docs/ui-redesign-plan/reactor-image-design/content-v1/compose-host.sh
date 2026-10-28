#!/usr/bin/env bash
# Review-only montage. Original generated PNGs stay untouched; never import this into the game.
set -euo pipefail
art_dir="$(cd "$(dirname "$0")" && pwd)"
font_path=/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
for mode in four three; do
  input_path="$art_dir/reactor-${mode}-raw.png"
  output_path="$art_dir/reactor-${mode}-host-layout.png"
  temp_base="$(mktemp /tmp/reactor-content-host-XXXXXX.png)"
  trap 'rm -f "$temp_base"' EXIT
  magick "$art_dir/shared-host-reference.png" \
    \( "$input_path" -resize '808x' -gravity center -crop 808x835+0+0 +repage \) \
    -gravity northwest -geometry +0+65 -compose over -composite "$temp_base"
  args=("$temp_base" -font "$font_path" -stroke none
    -fill '#e7dbcc' -draw 'rectangle 53,256 258,301' -draw 'rectangle 548,256 753,301'
    -draw 'rectangle 53,607 258,653' -fill '#173b49' -pointsize 18
    -annotate +60+280 '武器增益 ×1.19' -annotate +555+280 '防御增益 ×1.15'
    -pointsize 16 -annotate +60+298 '手动 40 · 有效 40' -annotate +555+298 '手动 30 · 有效 30'
    -pointsize 18 -annotate +60+631 '铁产出 ×1.11'
    -pointsize 16 -annotate +60+649 '手动 20 · 有效 20')
  if [[ "$mode" == four ]]; then
    args+=(-fill '#e7dbcc' -draw 'rectangle 548,607 753,653' -fill '#173b49'
      -pointsize 18 -annotate +555+631 '碎片产出 ×1.06'
      -pointsize 16 -annotate +555+649 '手动 10 · 有效 10')
  fi
  args+=(-fill '#e7efec' -pointsize 16
    -annotate +46+756 '容量 100 · 已配 100 · 剩余 0'
    -annotate +46+807 '草稿与实际一致'
    -annotate +375+842 '结果提示与失败原因两行空间'
    -annotate +380+788 '升级 · 10 铀'
    -annotate +532+788 '均分'
    -annotate +613+788 '确认'
    -annotate +699+788 '还原'
    "$output_path")
  magick "${args[@]}"
  rm -f "$temp_base"
  trap - EXIT
done
