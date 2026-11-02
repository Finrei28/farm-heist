"""Every colour the crop meshes use (one swatch each in the palette
texture). Tones run shadow -> sunlit; Roblox's lighting shades on top, so
the steps between them stay small."""
from scene import GROUND

COLOURS = {
    # leaves
    "leafDeep": (44, 100, 44), "leafDark": (56, 128, 48), "leaf": (78, 159, 61), "leafLight": (106, 180, 72),
    "leafSun": (138, 198, 88), "stem": (84, 146, 58), "stemDark": (64, 118, 46),
    "frond": (86, 168, 62), "frondLight": (118, 192, 80), "frondDark": (62, 138, 50),
    "yellowing": (158, 160, 72), "yellowingLight": (184, 176, 86), "olive": (120, 134, 60),
    # carrot
    "carrot": (242, 136, 38), "carrotDark": (220, 110, 28), "carrotLight": (250, 162, 66), "carrotCrown": (170, 150, 60),
    # wheat
    "wheat": (232, 196, 96), "wheatDark": (206, 164, 72), "wheatLight": (246, 218, 136), "wheatStalk": (214, 178, 88),
    "twine": (146, 100, 52), "twineDark": (118, 78, 40), "stubble": (190, 158, 84),
    # potato
    "potato": (182, 134, 84), "potatoDark": (156, 110, 66), "potatoLight": (202, 158, 106), "potatoEye": (118, 82, 50),
    # lettuce
    "lettuceHeart": (200, 234, 140), "lettuce": (150, 208, 94), "lettuceDark": (108, 176, 68), "lettuceDeep": (82, 150, 56),
    "lettuceRib": (222, 242, 186),
    # corn
    "kernel": (246, 208, 58), "kernelDark": (226, 178, 36), "kernelLight": (252, 228, 112),
    "husk": (130, 180, 78), "huskLight": (172, 206, 112), "huskDry": (210, 196, 128), "silk": (196, 136, 72),
    "tassel": (214, 182, 108), "tasselDark": (178, 140, 76), "cornStalk": (102, 160, 66),
    # onion
    "onion": (204, 140, 72), "onionDark": (170, 104, 50), "onionLight": (228, 176, 112), "onionNeck": (196, 166, 112),
    "onionRoot": (220, 206, 170),
    # strawberry
    "berry": (226, 46, 56), "berryDark": (186, 26, 42), "berryLight": (246, 92, 86), "seed": (250, 222, 120),
    "calyx": (66, 146, 52), "petal": (250, 250, 240), "petalShade": (226, 228, 216), "flowerEye": (250, 206, 60),
    # tomato
    "tomato": (224, 60, 44), "tomatoDark": (190, 40, 32), "tomatoLight": (242, 104, 78), "tomatoGreen": (150, 190, 70),
    # wood
    "wood": (156, 116, 72), "woodDark": (124, 90, 54), "woodLight": (182, 142, 94), "bark": (112, 82, 54),
    "barkDark": (86, 62, 42), "barkLight": (136, 102, 68), "wire": (150, 150, 150),
    # pepper
    "pepper": (244, 198, 40), "pepperDark": (222, 164, 22), "pepperLight": (252, 224, 104), "pepperStem": (76, 136, 52),
    # pumpkin
    "pumpkin": (240, 128, 30), "pumpkinDark": (212, 98, 20), "pumpkinLight": (250, 160, 62), "pumpkinStem": (110, 116, 56),
    "pumpkinStemDark": (82, 86, 40), "vine": (92, 150, 58), "vineDark": (70, 124, 48),
    # watermelon
    "melon": (122, 182, 88), "melonLight": (150, 200, 108), "melonStripe": (44, 108, 52), "melonStripeDark": (32, 88, 42),
    # blueberry
    "blue": (70, 92, 196), "blueDark": (50, 66, 156), "blueDusty": (116, 138, 210), "blueCrown": (40, 42, 92),
    "blueLeaf": (64, 132, 70), "blueLeafDark": (48, 108, 58),
    # pineapple
    "pine": (230, 178, 50), "pineDark": (196, 136, 40), "pineBrown": (156, 104, 42), "pineEye": (110, 74, 36),
    "pineLeaf": (92, 142, 88), "pineLeafDark": (64, 112, 72), "pineLeafRed": (156, 100, 84),
    # cocoa
    "cocoa": (204, 116, 44), "cocoaDark": (168, 82, 34), "cocoaYellow": (230, 170, 60), "cocoaRed": (182, 66, 42),
    "cocoaLeaf": (60, 120, 52), "cocoaLeafLight": (92, 150, 66), "cocoaLeafRed": (166, 104, 70),
    # dragonfruit
    "dragon": (232, 60, 140), "dragonDark": (196, 36, 110), "dragonLight": (246, 110, 172), "bract": (152, 200, 82),
    "bractDark": (112, 168, 62), "cactus": (80, 152, 74), "cactusLight": (112, 178, 92), "cactusDark": (58, 122, 58),
    # grapes
    "grape": (122, 60, 162), "grapeDark": (92, 42, 128), "grapeLight": (156, 96, 196), "grapeBloom": (176, 146, 206),
    "vineLeaf": (82, 150, 62), "vineLeafDark": (60, 124, 50), "vineLeafLight": (112, 172, 76),
    # moonmelon
    "moon": (178, 200, 244), "moonDark": (146, 170, 224), "moonLight": (210, 224, 252), "moonStripe": (236, 244, 255),
    "silver": (146, 174, 160), "silverLight": (178, 202, 190), "silverDark": (116, 144, 132),
    # starfruit
    "star": (250, 220, 80), "starDark": (226, 184, 48), "starLight": (254, 236, 136), "starEdge": (184, 196, 70),
    # golden apple
    "gold": (238, 176, 26), "goldDark": (204, 138, 16), "goldLight": (252, 214, 92), "appleStem": (96, 70, 44),
    # crystal rose
    "crystal": (150, 220, 255), "crystalDark": (98, 172, 232), "crystalLight": (206, 242, 255), "crystalDeep": (72, 128, 210),
    "roseLeaf": (58, 128, 74), "roseLeafLight": (86, 156, 92), "thorn": (120, 96, 70),
    # phoenix pepper
    "fire1": (200, 28, 24), "fire2": (220, 44, 22), "fire3": (234, 74, 24), "fire4": (246, 116, 30), "fire5": (252, 160, 42),
    "fire6": (255, 208, 70), "emberLeaf": (66, 104, 52), "emberLeafDark": (50, 82, 42), "emberLeafRed": (150, 70, 42),
    # dragon's eye pumpkin
    "dragonEye": (158, 44, 126), "dragonEyeDark": (120, 28, 96), "dragonEyeLight": (188, 74, 154), "dragonStem": (60, 44, 48),
    "dragonVine": (70, 98, 62), "dragonVineDark": (52, 76, 50), "pupil": (28, 18, 24), "horn": (226, 214, 180),
    # seedlings
    "sprout": (120, 196, 84), "sproutDark": (88, 164, 62),
    # baskets, crates, punnets
    "wicker": (198, 152, 86), "wickerDark": (150, 104, 54), "wickerLight": (218, 178, 112),
    "crate": (196, 158, 104), "crateDark": (160, 124, 78), "punnet": (66, 150, 76), "punnetDark": (48, 122, 58),
    "white": (250, 250, 246), "dark": (40, 34, 30),
}
COLOURS.update(GROUND)
