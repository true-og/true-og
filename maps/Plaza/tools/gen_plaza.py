#!/usr/bin/env python3
"""Generate the Plaza BuildBattle map: 12 build plots in a ring around a central plaza.

Writes 1.19.4 (DataVersion 3337) Anvil region files. Heightmaps and light are left
for the server to compute on first load.
"""
import io, math, os, shutil, sys, zlib, time
import nbtlib
from nbtlib import Compound, List, String, Int, Long, Byte, LongArray, ByteArray

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'Template_World')
DST = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'Plaza')
DATA_VERSION = 3337
BIOME = 'minecraft:the_void'

# ---- layout ---------------------------------------------------------------
PLOT_HALF = 15          # 31x31 floor
PLOT_FLOOR_Y = 64
PLOT_TOP_Y = 96         # cuboid max Y (33 layers of air incl. floor layer)
PITCH = 44              # distance between plot centres (31 + 13 gap)
CENTRES = [-66, -22, 22, 66]
PLOTS = []              # (cx, cz)
for cz in CENTRES:
    for cx in CENTRES:
        if abs(cx) == 22 and abs(cz) == 22:
            continue    # inner 2x2 left open for the plaza
        PLOTS.append((cx, cz))
assert len(PLOTS) == 12
PLAZA_HALF = 20         # 41x41
SPAWN = (0.5, 65.0, 0.5)

FLOOR = 'minecraft:oak_log'          # BuildBattle-OG Floor.Material default (log -> oak_log)
FRAME = 'minecraft:polished_deepslate'
CORNER = 'minecraft:sea_lantern'
PED1 = 'minecraft:stone_bricks'
PED2 = 'minecraft:deepslate_bricks'
PED3 = 'minecraft:deepslate_tiles'
PED4 = 'minecraft:deepslate'
PLAZA_FLOOR = 'minecraft:smooth_stone'
PLAZA_RING = 'minecraft:polished_deepslate'
PLAZA_INLAY = 'minecraft:polished_andesite'
PLAZA_CENTER = 'minecraft:sea_lantern'
BARRIER = 'minecraft:barrier'

blocks = {}   # (x, y, z) -> block id

def fill(x1, y1, z1, x2, y2, z2, block):
    for x in range(min(x1, x2), max(x1, x2) + 1):
        for y in range(min(y1, y2), max(y1, y2) + 1):
            for z in range(min(z1, z2), max(z1, z2) + 1):
                blocks[(x, y, z)] = block

def ring(cx, cz, half, y, block):
    fill(cx - half, y, cz - half, cx + half, y, cz - half, block)
    fill(cx - half, y, cz + half, cx + half, y, cz + half, block)
    fill(cx - half, y, cz - half, cx - half, y, cz + half, block)
    fill(cx + half, y, cz - half, cx + half, y, cz + half, block)

def pedestal(cx, cz, half, top_y):
    # tapered island under a platform whose outer edge is `half`
    layers = [(half, PED1), (half - 2, PED2), (half - 4, PED2), (half - 7, PED3),
              (half - 10, PED4), (half - 13, PED4), (half - 15, PED4)]
    y = top_y - 1
    for h, block in layers:
        if h < 1:
            break
        fill(cx - h, y, cz - h, cx + h, y, cz + h, block)
        y -= 1

def plot(cx, cz):
    fill(cx - PLOT_HALF, PLOT_FLOOR_Y, cz - PLOT_HALF, cx + PLOT_HALF, PLOT_FLOOR_Y, cz + PLOT_HALF, FLOOR)
    ring(cx, cz, PLOT_HALF + 1, PLOT_FLOOR_Y, FRAME)
    for dx in (-1, 1):
        for dz in (-1, 1):
            blocks[(cx + dx * (PLOT_HALF + 1), PLOT_FLOOR_Y, cz + dz * (PLOT_HALF + 1))] = CORNER
    pedestal(cx, cz, PLOT_HALF + 1, PLOT_FLOOR_Y)

def plaza():
    fill(-PLAZA_HALF, PLOT_FLOOR_Y, -PLAZA_HALF, PLAZA_HALF, PLOT_FLOOR_Y, PLAZA_HALF, PLAZA_FLOOR)
    ring(0, 0, PLAZA_HALF, PLOT_FLOOR_Y, PLAZA_RING)
    ring(0, 0, 12, PLOT_FLOOR_Y, PLAZA_INLAY)
    ring(0, 0, 6, PLOT_FLOOR_Y, PLAZA_INLAY)
    fill(-1, PLOT_FLOOR_Y, -1, 1, PLOT_FLOOR_Y, 1, PLAZA_RING)
    blocks[(0, PLOT_FLOOR_Y, 0)] = PLAZA_CENTER
    for dx in (-PLAZA_HALF, PLAZA_HALF):
        for dz in (-PLAZA_HALF, PLAZA_HALF):
            blocks[(dx, PLOT_FLOOR_Y, dz)] = CORNER
    # invisible rail so spectators and waiting players cannot walk off
    for y in range(PLOT_FLOOR_Y + 1, PLOT_FLOOR_Y + 4):
        ring(0, 0, PLAZA_HALF, y, BARRIER)
    pedestal(0, 0, PLAZA_HALF, PLOT_FLOOR_Y)

for cx, cz in PLOTS:
    plot(cx, cz)
plaza()

# ---- chunk serialisation ---------------------------------------------------
def pack(indices, bits):
    per_long = 64 // bits
    longs = []
    cur = 0; n = 0
    for i, v in enumerate(indices):
        cur |= v << (bits * n)
        n += 1
        if n == per_long:
            longs.append(cur); cur = 0; n = 0
    if n:
        longs.append(cur)
    return [l - (1 << 64) if l >= (1 << 63) else l for l in longs]

def section(cx, sy, cz):
    ids = ['minecraft:air']
    idx = {}
    data = []
    nonair = False
    for y in range(16):
        for z in range(16):
            for x in range(16):
                b = blocks.get((cx * 16 + x, sy * 16 + y, cz * 16 + z), 'minecraft:air')
                if b not in idx:
                    idx[b] = len(ids) if b != 'minecraft:air' else 0
                    if b != 'minecraft:air':
                        ids.append(b)
                        nonair = True
                data.append(idx[b])
    palette = List[Compound]([Compound({'Name': String(n)}) for n in ids])
    bs = Compound({'palette': palette})
    if nonair:
        bits = max(4, math.ceil(math.log2(len(ids))))
        bs['data'] = LongArray(pack(data, bits))
    return Compound({
        'Y': Byte(sy),
        'block_states': bs,
        'biomes': Compound({'palette': List[String]([String(BIOME)])}),
    })

def chunk(cx, cz):
    return Compound({
        'DataVersion': Int(DATA_VERSION),
        'xPos': Int(cx), 'yPos': Int(-4), 'zPos': Int(cz),
        'Status': String('full'),
        'LastUpdate': Long(0), 'InhabitedTime': Long(0),
        'isLightOn': Byte(0),
        'sections': List[Compound]([section(cx, sy, cz) for sy in range(-4, 20)]),
        'block_entities': List[Compound]([]),
        'block_ticks': List[Compound]([]),
        'fluid_ticks': List[Compound]([]),
        'PostProcessing': List[List]([List[Short]([]) for _ in range(24)]) if False else List[List[nbtlib.Short]]([List[nbtlib.Short]([]) for _ in range(24)]),
        'structures': Compound({'References': Compound({}), 'starts': Compound({})}),
    })

def chunk_bytes(cx, cz):
    buf = io.BytesIO()
    nbtlib.File(chunk(cx, cz), root_name='').write(buf)
    return zlib.compress(buf.getvalue())

def write_region(rx, rz, chunks, path):
    # chunks: {(cx,cz): bytes}
    header_loc = bytearray(4096); header_ts = bytearray(4096)
    body = bytearray()
    sector = 2
    ts = int(time.time())
    for (cx, cz), payload in chunks.items():
        i = (cx & 31) + (cz & 31) * 32
        rec = len(payload) + 1
        block = (rec).to_bytes(4, 'big') + b'\x02' + payload
        pad = (-len(block)) % 4096
        block += b'\x00' * pad
        count = len(block) // 4096
        header_loc[i*4:i*4+3] = sector.to_bytes(3, 'big'); header_loc[i*4+3] = count
        header_ts[i*4:i*4+4] = ts.to_bytes(4, 'big')
        body += block
        sector += count
    with open(path, 'wb') as f:
        f.write(header_loc); f.write(header_ts); f.write(body)

# ---- world assembly --------------------------------------------------------
if os.path.exists(DST):
    shutil.rmtree(DST)
os.makedirs(os.path.join(DST, 'region'))
for name in ('LICENSE.md', 'paper-world.yml'):
    shutil.copy(os.path.join(SRC, name), DST)
for d in ('data', 'datapacks'):
    if os.path.isdir(os.path.join(SRC, d)):
        shutil.copytree(os.path.join(SRC, d), os.path.join(DST, d))

lvl = nbtlib.load(os.path.join(SRC, 'level.dat'))
lvl['Data']['LevelName'] = String('Plaza')
lvl['Data']['SpawnX'] = Int(0); lvl['Data']['SpawnY'] = Int(65); lvl['Data']['SpawnZ'] = Int(0)
lvl.save(os.path.join(DST, 'level.dat'))

xs = [p[0] for p in blocks]; zs = [p[2] for p in blocks]
cmin_x, cmax_x = (min(xs) >> 4) - 1, (max(xs) >> 4) + 1
cmin_z, cmax_z = (min(zs) >> 4) - 1, (max(zs) >> 4) + 1
regions = {}
for cx in range(cmin_x, cmax_x + 1):
    for cz in range(cmin_z, cmax_z + 1):
        regions.setdefault((cx >> 5, cz >> 5), {})[(cx, cz)] = chunk_bytes(cx, cz)
for (rx, rz), chunks in regions.items():
    write_region(rx, rz, chunks, os.path.join(DST, 'region', f'r.{rx}.{rz}.mca'))

print(f'blocks={len(blocks)} chunks={sum(len(c) for c in regions.values())} regions={len(regions)} -> {DST}')
print('PLOTS (min corner, max corner):')
for i, (cx, cz) in enumerate(PLOTS):
    print(f"  {i}: ({cx-PLOT_HALF},{PLOT_FLOOR_Y},{cz-PLOT_HALF}) ({cx+PLOT_HALF},{PLOT_TOP_Y},{cz+PLOT_HALF})")
