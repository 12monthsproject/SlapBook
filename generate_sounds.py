#!/usr/bin/env python3
"""
SlapBook 音效生成脚本
使用 ElevenLabs API 生成性感女声和男声音效
运行前需要：pip install elevenlabs
并设置环境变量：export ELEVEN_API_KEY="你的API密钥"
免费账号每月有 10,000 字符额度，足够生成这套音效
"""

import os
import time

# 安装：pip install elevenlabs
try:
    from elevenlabs.client import ElevenLabs
    from elevenlabs import save
except ImportError:
    print("请先安装：pip install elevenlabs")
    exit(1)

# ─────────────────────────────────────
# 配置
# ─────────────────────────────────────

API_KEY = os.environ.get("ELEVEN_API_KEY", "YOUR_API_KEY_HERE")

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "SlapBook", "Sounds")
os.makedirs(OUTPUT_DIR, exist_ok=True)

client = ElevenLabs(api_key=API_KEY)

# ─────────────────────────────────────
# 音效文本定义
# ─────────────────────────────────────

FEMALE_SCRIPTS = {
    # 轻拍 - 轻柔、惊讶、撒娇
    "female_light_1": "Mm, that tickles~",
    "female_light_2": "Oh~ hello there",
    "female_light_3": "Hey~ be gentle",
    
    # 中等力度 - 享受、低吟
    "female_medium_1": "Mmm~ I like that",
    "female_medium_2": "Oh yes, right there",
    "female_medium_3": "Mmm~ don't stop",
    
    # 重击 - 惊叫、亢奋
    "female_hard_1": "Oh my god~ yes!",
    "female_hard_2": "Ahh~ so good!",
    "female_hard_3": "Yes! Like that!",
}

MALE_SCRIPTS = {
    # 轻拍 - 低沉、慵懒
    "male_light_1": "Hey~ what was that",
    "male_light_2": "Mmm, interesting",
    "male_light_3": "Oh~ I felt that",
    
    # 中等力度 - 低沉享受
    "male_medium_1": "Mmm~ keep going",
    "male_medium_2": "Yeah~ like that",
    "male_medium_3": "Ohh~ that's good",
    
    # 重击 - 低吼、爆发
    "male_hard_1": "Oh damn~ yes!",
    "male_hard_2": "Ahh~ don't stop!",
    "male_hard_3": "Yes! Give me more!",
}

# ─────────────────────────────────────
# ElevenLabs 推荐声音 ID
# （可在 elevenlabs.io/voice-library 搜索更多）
# ─────────────────────────────────────

# 性感女声：Rachel（温柔）或 Bella（性感）
FEMALE_VOICE_ID = "EXAVITQu4vr4xnSDxMaL"  # Bella - sensual female voice

# 性感男声：Adam（低沉）或 Antoni（温暖）
MALE_VOICE_ID = "ErXwobaYiN019PkySvjV"      # Antoni - warm male voice

# ─────────────────────────────────────
# 生成函数
# ─────────────────────────────────────

def generate_voice(text: str, voice_id: str, filename: str):
    """生成一条语音并保存为 mp3"""
    output_path = os.path.join(OUTPUT_DIR, filename + ".mp3")
    
    if os.path.exists(output_path):
        print(f"  ⏭  已存在，跳过: {filename}.mp3")
        return
    
    try:
        print(f"  🎙  生成: {filename}.mp3  →  \"{text}\"")
        audio = client.generate(
            text=text,
            voice=voice_id,
            model="eleven_multilingual_v2"
        )
        save(audio, output_path)
        print(f"  ✅  保存: {output_path}")
        time.sleep(0.5)  # 避免触发 rate limit
    except Exception as e:
        print(f"  ❌  生成失败 {filename}: {e}")


def main():
    print("\n🎙  SlapBook 音效生成器")
    print(f"📁  输出目录: {OUTPUT_DIR}")
    print("=" * 50)
    
    if API_KEY == "YOUR_API_KEY_HERE":
        print("\n❗ 请先设置 ElevenLabs API Key：")
        print("   export ELEVEN_API_KEY='你的密钥'")
        print("   python3 generate_sounds.py")
        print("\n💡 免费注册：https://elevenlabs.io/sign-up")
        print("   免费额度：每月 10,000 字符（足够生成所有音效）")
        return
    
    # 生成女声
    print("\n💋 生成性感女声 (Bella)...")
    for filename, text in FEMALE_SCRIPTS.items():
        generate_voice(text, FEMALE_VOICE_ID, filename)
    
    # 生成男声
    print("\n🔥 生成性感男声 (Antoni)...")
    for filename, text in MALE_SCRIPTS.items():
        generate_voice(text, MALE_VOICE_ID, filename)
    
    print("\n✅ 全部完成！")
    print(f"📁 音效文件保存在: {OUTPUT_DIR}")
    print("\n下一步：将 Sounds 文件夹拖入 Xcode 工程，确保勾选 'Add to target: SlapBook'")


if __name__ == "__main__":
    main()
