"""How an overgrown 2 x 2 block of the field looks (server/World/FarmArt):
its four obstacles, one in the middle of each tile, and rough grass in the
gaps between them. Items are (mesh, rigid transform, scale); obstacles
from their tile's top middle, the grass from the block's top middle. The
game turns the grass round by quarter turns block to block (it stays clear
of the obstacles) and each obstacle by its own angle.
"""
from meshkit import R, T, mul

OBSTACLES = {
    # (the kinds are Config/Land's; a "Bush" is a bramble)
    "Stump": [("Stump", T(0, 0, 0), 1.0)],
    "Rock": [("Rock", T(0, 0, 0), 1.2)],
    "Weeds": [("Weeds", T(0, 0, 0), 1.1)],
    "Bush": [("Bramble", T(0, 0, 0), 0.95)],
}

# rough grass round the four tiles' middles (+-6, +-6), clear of what stands there
GRASS = [
    ("GrassPatch", mul(T(0.0, 0, 0.0), R("y", 10)), 1.2),
    ("GrassPatch", mul(T(6.3, 0, -0.6), R("y", 80)), 1.0),
    ("GrassPatch", mul(T(-6.0, 0, 0.8), R("y", 200)), 1.05),
    ("GrassPatch", mul(T(0.6, 0, 6.5), R("y", 130)), 1.0),
    ("GrassPatch", mul(T(-0.5, 0, -6.2), R("y", 300)), 0.95),
    ("GrassTuft2", mul(T(9.4, 0, 2.6), R("y", 45)), 0.95),
    ("GrassPatch", mul(T(-8.9, 0, -2.6), R("y", 250)), 0.8),
    ("Wildflowers", mul(T(2.6, 0, -9.7), R("y", 20)), 1.2),
    ("GrassTuft1", mul(T(-2.6, 0, 9.6), R("y", 160)), 1.0),
    ("GrassPatch", mul(T(9.0, 0, -8.9), R("y", 230)), 0.75),
    ("Wildflowers", mul(T(-9.4, 0, 9.3), R("y", 95)), 1.1),
    ("GrassTuft3", mul(T(2.8, 0, 2.9), R("y", 300)), 0.9),
    ("GrassTuft1", mul(T(-3.1, 0, -3.0), R("y", 70)), 0.95),
]
