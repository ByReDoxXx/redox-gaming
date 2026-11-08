"""Builds app/roms/redox_test.nes: a tiny NES program written for RedoX Gaming.

It is our own code (no copyrighted game), used to check that video, input and
sound go through the emulator:
  * the whole screen shows one colour from the NES palette,
  * holding any button cycles the colour,
  * holding A plays a 440 Hz square-wave tone.

Usage:  python tools/make_test_rom.py
"""

from pathlib import Path

ORG = 0xC000  # 16 KB PRG is mirrored at $8000 and $C000


class Asm:
    def __init__(self):
        self.code = bytearray()
        self.labels = {}
        self.fixups = []  # (offset, label, kind)

    @property
    def pc(self):
        return ORG + len(self.code)

    def label(self, name):
        self.labels[name] = self.pc

    def emit(self, *b):
        self.code += bytes(b)

    def imm(self, op, v):
        self.emit(op, v & 0xFF)

    def zp(self, op, a):
        self.emit(op, a & 0xFF)

    def absolute(self, op, a):
        self.emit(op, a & 0xFF, a >> 8)

    def branch(self, op, name):
        self.emit(op, 0)
        self.fixups.append((len(self.code) - 1, name, "rel"))

    def jmp(self, name):
        self.emit(0x4C, 0, 0)
        self.fixups.append((len(self.code) - 2, name, "abs"))

    def resolve(self):
        for off, name, kind in self.fixups:
            target = self.labels[name]
            if kind == "rel":
                rel = target - (ORG + off + 1)
                assert -128 <= rel <= 127, name
                self.code[off] = rel & 0xFF
            else:
                self.code[off] = target & 0xFF
                self.code[off + 1] = target >> 8


# opcodes used
LDA_IMM, LDX_IMM = 0xA9, 0xA2
LDA_ZP, STA_ZP, INC_ZP, ROL_ZP = 0xA5, 0x85, 0xE6, 0x26
LDA_ABS, STA_ABS, STX_ABS, BIT_ABS = 0xAD, 0x8D, 0x8E, 0x2C
AND_IMM = 0x29
SEI, CLD, TXS, INX, DEX, LSR_A, PHA, PLA, RTI = 0x78, 0xD8, 0x9A, 0xE8, 0xCA, 0x4A, 0x48, 0x68, 0x40
BPL, BNE, BEQ = 0x10, 0xD0, 0xF0

COLOR, BUTTONS = 0x00, 0x01

a = Asm()

# ---- reset
a.label("reset")
a.emit(SEI, CLD)
a.imm(LDX_IMM, 0x40); a.absolute(STX_ABS, 0x4017)   # no APU frame IRQ
a.imm(LDX_IMM, 0xFF); a.emit(TXS, INX)               # stack, X = 0
a.absolute(STX_ABS, 0x2000)                          # NMI off
a.absolute(STX_ABS, 0x2001)                          # rendering off
a.absolute(STX_ABS, 0x4010)                          # no DMC IRQ
a.label("vwait1"); a.absolute(BIT_ABS, 0x2002); a.branch(BPL, "vwait1")
a.label("vwait2"); a.absolute(BIT_ABS, 0x2002); a.branch(BPL, "vwait2")

a.imm(LDA_IMM, 0x16); a.zp(STA_ZP, COLOR)            # start on red
a.imm(LDA_IMM, 0x01); a.absolute(STA_ABS, 0x4015)    # enable pulse 1
a.imm(LDA_IMM, 0xB0); a.absolute(STA_ABS, 0x4000)    # silent for now
a.imm(LDA_IMM, 0x08); a.absolute(STA_ABS, 0x4001)    # no sweep
a.imm(LDA_IMM, 0xFD); a.absolute(STA_ABS, 0x4002)    # ~440 Hz
a.imm(LDA_IMM, 0x08); a.absolute(STA_ABS, 0x4003)
a.imm(LDA_IMM, 0x80); a.absolute(STA_ABS, 0x2000)    # NMI on
a.label("forever"); a.jmp("forever")

# ---- NMI: read pad, update colour and tone, write backdrop colour
a.label("nmi")
a.emit(PHA)
a.imm(LDA_IMM, 1); a.absolute(STA_ABS, 0x4016)
a.imm(LDA_IMM, 0); a.absolute(STA_ABS, 0x4016)
a.imm(LDX_IMM, 8)
a.label("readpad")
a.absolute(LDA_ABS, 0x4016); a.emit(LSR_A); a.zp(ROL_ZP, BUTTONS)
a.emit(DEX); a.branch(BNE, "readpad")
# BUTTONS bit7 = A ... bit0 = Right

a.zp(LDA_ZP, BUTTONS); a.branch(BEQ, "no_cycle")
a.zp(INC_ZP, COLOR)
a.label("no_cycle")

a.zp(LDA_ZP, BUTTONS); a.branch(BPL, "silent")      # A not held
a.imm(LDA_IMM, 0xBF); a.absolute(STA_ABS, 0x4000); a.jmp("sound_done")
a.label("silent")
a.imm(LDA_IMM, 0xB0); a.absolute(STA_ABS, 0x4000)
a.label("sound_done")

a.absolute(LDA_ABS, 0x2002)                          # reset address latch
a.imm(LDA_IMM, 0x3F); a.absolute(STA_ABS, 0x2006)
a.imm(LDA_IMM, 0x00); a.absolute(STA_ABS, 0x2006)
a.zp(LDA_ZP, COLOR); a.imm(AND_IMM, 0x3F); a.absolute(STA_ABS, 0x2007)
# point the PPU back at $3F00 so the backdrop shows that colour
a.imm(LDA_IMM, 0x3F); a.absolute(STA_ABS, 0x2006)
a.imm(LDA_IMM, 0x00); a.absolute(STA_ABS, 0x2006)
a.emit(PLA, RTI)

a.label("irq")
a.emit(RTI)

a.resolve()

prg = bytearray(a.code) + bytearray(0x4000 - len(a.code))
vectors = [a.labels["nmi"], a.labels["reset"], a.labels["irq"]]
for i, v in enumerate(vectors):
    prg[0x3FFA + i * 2] = v & 0xFF
    prg[0x3FFA + i * 2 + 1] = v >> 8

header = b"NES\x1a" + bytes([1, 1, 0, 0]) + bytes(8)  # 16 KB PRG, 8 KB CHR, mapper 0
chr_rom = bytes(0x2000)

out = Path(__file__).resolve().parent.parent / "app" / "roms" / "redox_test.nes"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(header + prg + chr_rom)
print(f"wrote {out} ({len(a.code)} bytes of code)")
