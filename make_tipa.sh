#!/bin/bash
# 在 Mac 上运行：构建 AXInjectDemo 并打包成 .tipa（TrollStore 直接安装；或交给全能签类企业签名服务重签后分发给非越狱设备）
set -e
cd "$(dirname "$0")"

echo "== 构建（无签名，产物供 TrollStore / 全能签 / AltStore 重签） =="
xcodebuild -project AXInjectDemo.xcodeproj \
           -target AXInjectDemo \
           -configuration Release \
           -sdk iphoneos \
           -arch arm64 \
           CODE_SIGNING_ALLOWED=NO \
           build

APP=$(find build/Release-iphoneos -maxdepth 2 -name "AXInjectDemo.app" -type d | head -1)
[ -n "$APP" ] || { echo "未找到 .app 产物"; exit 1; }

rm -rf Payload AXInjectDemo.tipa
mkdir -p Payload
cp -R "$APP" Payload/
zip -r AXInjectDemo.tipa Payload >/dev/null

echo "== 完成：$(pwd)/AXInjectDemo.tipa =="
echo "安装方式："
echo "  A. TrollStore：打开 AXInjectDemo.tipa → 安装（免越狱）"
echo "  B. 全能签类企业签名：上传 AXInjectDemo.tipa/ipa → 企业证书重签 → 描述文件信任后安装"
echo "  C. 自签（Apple ID）：Xcode 里选自己的 Team 直接跑真机"
