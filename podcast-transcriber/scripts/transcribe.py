#!/usr/bin/env python3
"""
Podcast Transcriber - 將 Podcast 音頻轉為文字稿

用法：
    python3 transcribe.py --podcast "<頻道名稱>" [--episode <集數>] [--format full|summary]
    
範例：
    python3 transcribe.py --podcast "股癌"
    python3 transcribe.py --podcast "股癌" --episode 639
    python3 transcribe.py --podcast "股癌" --format summary
"""

import argparse
import subprocess
import json
import os
import sys
import re
import urllib.parse

# 常量
WHISPER_VENV = "/tmp/whisper-venv/bin/python3"
OUTPUT_DIR = "/tmp/podcast-transcribe"
NOTEBOOKLM_CLI = "/opt/homebrew/bin/notebooklm"
MARKETING_NOTEBOOK_ID = "12e590d2-e85c-49b5-a5b2-5c30aff1fc48"

def run_cmd(cmd, capture=True):
    """執行 shell 命令"""
    print(f"執行: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=capture, text=True)
    if result.returncode != 0:
        print(f"錯誤: {result.stderr}")
        return None
    return result.stdout if capture else True

def search_podcast(name):
    """使用 Apple Podcasts API 搜尋 Podcast"""
    print(f"\n🔍 搜尋 Podcast: {name}")
    encoded_name = urllib.parse.quote(name)
    cmd = [
        "curl", "-s",
        f"https://itunes.apple.com/search?term={encoded_name}&media=podcast&entity=podcast&limit=1&country=TW"
    ]
    output = run_cmd(cmd)
    if not output:
        return None
    
    try:
        data = json.loads(output)
        if data.get("resultCount", 0) == 0:
            print(f"❌ 找不到: {name}")
            return None
        
        podcast = data["results"][0]
        print(f"✅ 找到: {podcast['trackName']}")
        print(f"   作者: {podcast['artistName']}")
        print(f"   平臺: {podcast.get('feedUrl', 'N/A')[:50]}...")
        return podcast
    except json.JSONDecodeError:
        print("❌ JSON 解析失敗")
        return None

def get_audio_url(feed_url, episode=None):
    """從 RSS 取得音頻 URL"""
    print(f"\n📥 解析 RSS: {feed_url}")
    
    # 下載 RSS
    cmd = ["curl", "-s", feed_url]
    rss_content = run_cmd(cmd)
    if not rss_content:
        return None
    
    # 解析最新集或指定集數
    # 這裡簡單抓第一個 enclosure url
    import xml.etree.ElementTree as ET
    
    try:
        root = ET.fromstring(rss_content)
        
        if episode:
            # 找指定集數（簡單實作：找包含 episode number 的 item）
            for item in root.findall(".//item"):
                title = item.find("title")
                if title is not None and str(episode) in title.text:
                    enclosure = item.find("enclosure")
                    if enclosure is not None:
                        return enclosure.get("url")
        else:
            # 取最新一集
            first_item = root.find(".//item")
            if first_item is not None:
                enclosure = first_item.find("enclosure")
                if enclosure is not None:
                    title = first_item.find("title")
                    if title is not None:
                        print(f"   最新集: {title.text}")
                    return enclosure.get("url")
        
        return None
    except ET.ParseError:
        print("❌ RSS 解析失敗")
        return None

def download_audio(audio_url, output_path):
    """使用 yt-dlp 下載音頻"""
    print(f"\n⬇️ 下載音頻...")
    cmd = [
        "yt-dlp",
        "-f", "bestaudio/best",
        "-o", output_path,
        "--no-playlist",
        audio_url
    ]
    
    if run_cmd(cmd):
        print(f"✅ 下載完成: {output_path}")
        return output_path
    return None

def transcribe_audio(audio_path, output_path):
    """使用 faster-whisper 轉文字"""
    print(f"\n🎤 轉文字中 (Whisper base)...")
    
    # 直接用 subprocess 執行 faster-whisper
    cmd = f"""
from faster_whisper import WhisperModel
model = WhisperModel("base", device="cpu", compute_type="int8")
segments, info = model.transcribe("{audio_path}", language="zh")
with open("{output_path}", "w", encoding="utf-8") as f:
    for segment in segments:
        f.write(segment.text + "\\n")
print("Done!")
"""
    
    result = subprocess.run(
        ["/tmp/whisper-venv/bin/python3", "-c", cmd],
        capture_output=True, text=True, timeout=600
    )
    
    print(result.stdout)
    if result.returncode == 0:
        print(f"✅ 轉文字完成: {output_path}")
        return output_path
    else:
        print(f"❌ 轉文字失敗: {result.stderr}")
        return None

def generate_summary(text_path, output_path):
    """過濾業配和閒聊，只保留重點"""
    print(f"\n📝 生成重點摘要...")
    
    with open(text_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 簡單的過濾關鍵字（可擴充）
    filter_keywords = [
        "業配", "贊助", "廣告", "感謝", "優惠", "折扣", 
        "來自", "粉絲團", "IG", "FB", "按讚", "分享",
        "片頭", "片尾", "音樂", "製作名單",
        "你好", "大家好", "今天天氣", "掰掰", "下次見"
    ]
    
    # 簡單實作：過濾包含這些關鍵字的句子
    lines = content.split("\n")
    important_lines = []
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        # 跳過太短的句子
        if len(line) < 20:
            continue
        
        # 跳過包含過濾關鍵字的句子
        skip = False
        for kw in filter_keywords:
            if kw in line:
                skip = True
                break
        
        if not skip:
            important_lines.append(line)
    
    summary = "\n".join(important_lines)
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("【重點摘要】\n\n")
        f.write(summary)
    
    print(f"✅ 重點摘要完成: {output_path}")
    return output_path

def main():
    parser = argparse.ArgumentParser(description="Podcast 轉文字工具")
    parser.add_argument("--podcast", required=True, help="Podcast 頻道名稱")
    parser.add_argument("--episode", help="集數（預設最新）")
    parser.add_argument("--format", choices=["full", "summary"], default="full", 
                        help="輸出格式：full=全文, summary=重點")
    
    args = parser.parse_args()
    
    # 建立輸出目錄
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Step 1: 搜尋 Podcast
    podcast = search_podcast(args.podcast)
    if not podcast:
        print("❌ 搜尋失敗")
        sys.exit(1)
    
    feed_url = podcast.get("feedUrl")
    if not feed_url:
        print("❌ 無 RSS feed")
        sys.exit(1)
    
    # Step 2: 取得音頻 URL
    audio_url = get_audio_url(feed_url, args.episode)
    if not audio_url:
        print("❌ 無法取得音頻")
        sys.exit(1)
    
    # Step 3: 下載音頻
    safe_name = re.sub(r'[^\w]', '_', args.podcast)
    audio_path = f"{OUTPUT_DIR}/{safe_name}.mp3"
    audio_path = download_audio(audio_url, audio_path)
    if not audio_path:
        print("❌ 下載失敗")
        sys.exit(1)
    
    # Step 4: 轉文字
    text_path = f"{OUTPUT_DIR}/{safe_name}.txt"
    text_path = transcribe_audio(audio_path, text_path)
    if not text_path:
        print("❌ 轉文字失敗")
        sys.exit(1)
    
    # Step 5: 輸出
    if args.format == "summary":
        summary_path = f"{OUTPUT_DIR}/{safe_name}_摘要.txt"
        generate_summary(text_path, summary_path)
        print(f"\n✅ 完成！輸出: {summary_path}")
    else:
        print(f"\n✅ 完成！輸出: {text_path}")

if __name__ == "__main__":
    main()
