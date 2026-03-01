import os

# Базовая структура папок
folders = [
    "Art/Environment/Tiles",
    "Art/Environment/Backgrounds",
    "Art/Player/Animations",
    "Art/Player/Abilities",
    "Art/Enemies/Slime",
    "Art/Enemies/Skull",
    "Art/Enemies/Bat",
    "Art/Enemies/Spider",
    "Art/UI/Theme",
    "Art/UI/Icons",
    "Art/UI/Fonts",
    "Art/Audio/Music",
    "Art/Audio/SFX/Weapons",
    "Art/Audio/SFX/Enemies",
    "Art/Audio/SFX/UI",
]

# Создаем папки
for folder in folders:
    os.makedirs(folder, exist_ok=True)
    print(f"✅ {folder}")

print("\nГотово! Все папки созданы.")