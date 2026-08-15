#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l2_build_chunk.py — Compilador de Chunks de Terreno Lineage II -> Godotage II

Lê arquivos .unr originais do Lineage II, descobre automaticamente a árvore
de diretórios do jogo (textures/, systextures/, staticmeshes/), e deriva
artefatos otimizados e isolados para Cliente (Godot 4.7) e Servidor (QuanticNet).

Uso:
    python tools/l2_build_chunk.py "C:\\...\\Lineage II\\maps\\16_24.unr" [opções]
"""

import argparse
import json
import os
import struct
import sys
import time
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

# Força UTF-8 no stdout/stderr no Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


UE2_PACKAGE_TAG = 0x9E2A83C1
L2_BLOWFISH_KEY = b"lineage2"
UU_TO_METERS_DEFAULT = 1.0 / 52.5  # 1 UU ≈ 0.0190476 metros (padrão Unreal / L2)


# ==============================================================================
# 1. DESENCRIPTADOR LINEAGE 2 (UE2 / L2 Blowfish & XOR)
# ==============================================================================
class L2Decryptor:
    @staticmethod
    def is_valid_ue2_header(data: bytes, pos: int = 0) -> bool:
        if len(data) < pos + 36:
            return False
        if struct.unpack_from("<I", data, pos)[0] != UE2_PACKAGE_TAG:
            return False
        file_version = struct.unpack_from("<I", data, pos + 4)[0] & 0xFFFF
        if not (60 <= file_version <= 300):
            return False
        name_count = struct.unpack_from("<I", data, pos + 12)[0]
        name_offset = struct.unpack_from("<I", data, pos + 16)[0]
        return name_count > 0 and pos <= name_offset < len(data)

    @staticmethod
    def decrypt(raw_data: bytes) -> bytes:
        if L2Decryptor.is_valid_ue2_header(raw_data, 0):
            return raw_data
        for pos in range(0, min(512, len(raw_data) - 36)):
            if L2Decryptor.is_valid_ue2_header(raw_data, pos):
                return raw_data[pos:]

        candidate_offsets = [28, 156, 128, 64, 32, 20, 0]
        target_magic = struct.pack("<I", UE2_PACKAGE_TAG)

        for offset in candidate_offsets:
            if offset + 4 > len(raw_data):
                continue
            k0 = raw_data[offset] ^ target_magic[0]
            k1 = raw_data[offset + 1] ^ target_magic[1]
            k2 = raw_data[offset + 2] ^ target_magic[2]
            k3 = raw_data[offset + 3] ^ target_magic[3]
            xor_key = bytes([k0, k1, k2, k3])
            payload = raw_data[offset:]
            key_block = (xor_key * (len(payload) // 4 + 1))[:len(payload)]
            dec = np.bitwise_xor(
                np.frombuffer(payload, dtype=np.uint8),
                np.frombuffer(key_block, dtype=np.uint8)
            ).tobytes()
            if L2Decryptor.is_valid_ue2_header(dec, 0):
                return dec

        for offset in candidate_offsets:
            if offset >= len(raw_data):
                continue
            dec = L2Decryptor._decrypt_blowfish_words_swapped(raw_data[offset:], L2_BLOWFISH_KEY)
            if L2Decryptor.is_valid_ue2_header(dec, 0):
                return dec
            tag_pos = dec.find(struct.pack("<I", UE2_PACKAGE_TAG))
            if tag_pos != -1 and L2Decryptor.is_valid_ue2_header(dec, tag_pos):
                return dec[tag_pos:]

        for offset in candidate_offsets:
            if offset >= len(raw_data):
                continue
            dec = L2Decryptor._decrypt_blowfish_raw(raw_data[offset:], L2_BLOWFISH_KEY)
            if L2Decryptor.is_valid_ue2_header(dec, 0):
                return dec
            tag_pos = dec.find(struct.pack("<I", UE2_PACKAGE_TAG))
            if tag_pos != -1 and L2Decryptor.is_valid_ue2_header(dec, tag_pos):
                return dec[tag_pos:]

        raise ValueError("Não foi possível sincronizar ou descriptografar a assinatura Unreal Package.")

    @staticmethod
    def _decrypt_blowfish_words_swapped(data: bytes, key: bytes) -> bytes:
        from Crypto.Cipher import Blowfish
        rem = len(data) % 8
        unpadded_len = len(data) - rem
        if unpadded_len <= 0:
            return data
        arr = np.frombuffer(data[:unpadded_len], dtype="<u4").copy()
        arr.byteswap(inplace=True)
        cipher = Blowfish.new(key, Blowfish.MODE_ECB)
        decrypted_bytes = cipher.decrypt(arr.tobytes())
        dec_arr = np.frombuffer(decrypted_bytes, dtype="<u4").copy()
        dec_arr.byteswap(inplace=True)
        res = dec_arr.tobytes()
        if rem > 0:
            res += data[unpadded_len:]
        return res

    @staticmethod
    def _decrypt_blowfish_raw(data: bytes, key: bytes) -> bytes:
        from Crypto.Cipher import Blowfish
        rem = len(data) % 8
        unpadded_len = len(data) - rem
        if unpadded_len <= 0:
            return data
        cipher = Blowfish.new(key, Blowfish.MODE_ECB)
        res = cipher.decrypt(data[:unpadded_len])
        if rem > 0:
            res += data[unpadded_len:]
        return res


# ==============================================================================
# 2. DECODIFICADORES DE TEXTURAS (DXT1, DXT5, G8)
# ==============================================================================
def decode_dxt1_to_image(data: bytes, width: int, height: int) -> Image.Image:
    bx = max(1, width // 4)
    by = max(1, height // 4)
    num_blocks = bx * by
    needed = num_blocks * 8
    if len(data) < needed:
        return None

    blocks = np.frombuffer(data[:needed], dtype=[('c0', '<u2'), ('c1', '<u2'), ('bits', '<u4')])
    c0 = blocks['c0'].astype(np.uint32)
    c1 = blocks['c1'].astype(np.uint32)
    bits = blocks['bits']

    r0 = (((c0 >> 11) & 0x1F) * 255 + 15) // 31
    g0 = (((c0 >> 5) & 0x3F) * 255 + 31) // 63
    b0 = ((c0 & 0x1F) * 255 + 15) // 31
    r1 = (((c1 >> 11) & 0x1F) * 255 + 15) // 31
    g1 = (((c1 >> 5) & 0x3F) * 255 + 31) // 63
    b1 = ((c1 & 0x1F) * 255 + 15) // 31

    palette = np.zeros((num_blocks, 4, 3), dtype=np.uint8)
    palette[:, 0, 0] = r0
    palette[:, 0, 1] = g0
    palette[:, 0, 2] = b0
    palette[:, 1, 0] = r1
    palette[:, 1, 1] = g1
    palette[:, 1, 2] = b1

    mask = c0 > c1
    palette[mask, 2, 0] = (2 * r0[mask] + r1[mask]) // 3
    palette[mask, 2, 1] = (2 * g0[mask] + g1[mask]) // 3
    palette[mask, 2, 2] = (2 * b0[mask] + b1[mask]) // 3
    palette[mask, 3, 0] = (r0[mask] + 2 * r1[mask]) // 3
    palette[mask, 3, 1] = (g0[mask] + 2 * g1[mask]) // 3
    palette[mask, 3, 2] = (b0[mask] + 2 * g1[mask]) // 3

    palette[~mask, 2, 0] = (r0[~mask] + r1[~mask]) // 2
    palette[~mask, 2, 1] = (g0[~mask] + g1[~mask]) // 2
    palette[~mask, 2, 2] = (b0[~mask] + b1[~mask]) // 2
    palette[~mask, 3, :] = 0

    shifts = np.arange(0, 32, 2, dtype=np.uint32)
    indices = (bits[:, None] >> shifts[None, :]) & 3
    block_pixels = np.take_along_axis(palette, indices[:, :, None], axis=1)
    block_pixels = block_pixels.reshape((by, bx, 4, 4, 3))
    img_arr = block_pixels.transpose((0, 2, 1, 3, 4)).reshape((by * 4, bx * 4, 3))
    return Image.fromarray(img_arr[:height, :width, :], mode='RGB')


def decode_dxt5_to_image(data: bytes, width: int, height: int) -> Image.Image:
    bx = max(1, width // 4)
    by = max(1, height // 4)
    num_blocks = bx * by
    needed = num_blocks * 16
    if len(data) < needed:
        return None
    color_bytes = bytearray(num_blocks * 8)
    for i in range(num_blocks):
        color_bytes[i * 8 : (i + 1) * 8] = data[i * 16 + 8 : (i + 1) * 16]
    return decode_dxt1_to_image(bytes(color_bytes), width, height)


# ==============================================================================
# 3. PARSER DE PACOTES UNREAL ENGINE 2 (.UNR / .UTX)
# ==============================================================================
class UnrealPackageReader:
    def __init__(self, filepath: Path):
        self.filepath = filepath
        raw = filepath.read_bytes()
        self.data = L2Decryptor.decrypt(raw)
        self.pos = 0
        self.names = []
        self.exports = []
        self.imports = []
        self._parse_header()

    def _parse_header(self):
        self.tag, self.file_version, self.pkg_flags = struct.unpack_from("<III", self.data, 0)
        self.pos = 12
        name_count, name_offset = struct.unpack_from("<II", self.data, self.pos)
        self.pos += 8
        export_count, export_offset = struct.unpack_from("<II", self.data, self.pos)
        self.pos += 8
        import_count, import_offset = struct.unpack_from("<II", self.data, self.pos)
        self.pos += 8

        self._read_names(name_count, name_offset)
        self._read_imports(import_count, import_offset)
        self._read_exports(export_count, export_offset)

    def read_compact_index(self, offset: int = None):
        if offset is not None:
            self.pos = offset
        b0 = self.data[self.pos]
        self.pos += 1
        sign = b0 & 0x80
        more = b0 & 0x40
        value = b0 & 0x3F

        if more:
            b1 = self.data[self.pos]
            self.pos += 1
            more = b1 & 0x80
            value |= (b1 & 0x7F) << 6
            if more:
                b2 = self.data[self.pos]
                self.pos += 1
                more = b2 & 0x80
                value |= (b2 & 0x7F) << 13
                if more:
                    b3 = self.data[self.pos]
                    self.pos += 1
                    more = b3 & 0x80
                    value |= (b3 & 0x7F) << 20
                    if more:
                        b4 = self.data[self.pos]
                        self.pos += 1
                        value |= (b4 & 0x1F) << 27
        return -value if sign else value

    def _read_names(self, count, offset):
        self.pos = offset
        for _ in range(count):
            length = self.read_compact_index()
            if length > 0:
                name_str = self.data[self.pos : self.pos + length - 1].decode("latin-1", errors="replace")
                self.pos += length
            elif length < 0:
                utf16_len = -length * 2
                name_str = self.data[self.pos : self.pos + utf16_len - 2].decode("utf-16le", errors="replace")
                self.pos += utf16_len
            else:
                name_str = ""
            self.pos += 4
            self.names.append(name_str)

    def _read_imports(self, count, offset):
        self.pos = offset
        for _ in range(count):
            class_pkg = self.read_compact_index()
            class_name = self.read_compact_index()
            outer = struct.unpack_from("<i", self.data, self.pos)[0]
            self.pos += 4
            obj_name = self.read_compact_index()
            self.imports.append({
                "class_package": self.names[class_pkg] if 0 <= class_pkg < len(self.names) else "",
                "class_name": self.names[class_name] if 0 <= class_name < len(self.names) else "",
                "outer": outer,
                "object_name": self.names[obj_name] if 0 <= obj_name < len(self.names) else "",
            })

    def _read_exports(self, count, offset):
        self.pos = offset
        for _ in range(count):
            class_idx = self.read_compact_index()
            super_idx = self.read_compact_index()
            outer_idx = struct.unpack_from("<i", self.data, self.pos)[0]
            self.pos += 4
            name_idx = self.read_compact_index()
            flags = struct.unpack_from("<I", self.data, self.pos)[0]
            self.pos += 4
            serial_size = self.read_compact_index()
            serial_offset = self.read_compact_index() if serial_size > 0 else 0

            class_name = "Class"
            if class_idx < 0:
                class_name = self.imports[-class_idx - 1]["object_name"]
            elif class_idx > 0:
                class_name = self.exports[class_idx - 1]["object_name"]

            obj_name = self.names[name_idx] if 0 <= name_idx < len(self.names) else f"Export_{len(self.exports)}"
            self.exports.append({
                "class_name": class_name,
                "object_name": obj_name,
                "class_idx": class_idx,
                "outer": outer_idx,
                "size": serial_size,
                "offset": serial_offset,
                "flags": flags,
            })

    def resolve_object_reference(self, index: int):
        if index == 0:
            return None
        chain = []
        curr = index
        class_name = ""

        if curr < 0:
            while curr < 0:
                imp_idx = -curr - 1
                if 0 <= imp_idx < len(self.imports):
                    imp = self.imports[imp_idx]
                    chain.append(imp["object_name"])
                    if not class_name:
                        class_name = imp["class_name"]
                    curr = imp["outer"]
                else:
                    break
            chain.reverse()
            pkg_name = chain[0] if len(chain) > 1 else (
                self.imports[-index - 1]["class_package"] if 0 <= -index - 1 < len(self.imports) else ""
            )
            return {
                "type": "import",
                "package": pkg_name,
                "object_name": chain[-1] if chain else "",
                "class_name": class_name,
                "full_path": ".".join(chain)
            }
        else:
            exp_idx = curr - 1
            if 0 <= exp_idx < len(self.exports):
                exp = self.exports[exp_idx]
                chain.append(exp["object_name"])
                class_name = exp["class_name"]
                outer = exp.get("outer", 0)
                while outer > 0:
                    p_idx = outer - 1
                    if 0 <= p_idx < len(self.exports):
                        p_exp = self.exports[p_idx]
                        chain.append(p_exp["object_name"])
                        outer = p_exp.get("outer", 0)
                    else:
                        break
            chain.reverse()
            return {
                "type": "export",
                "package": self.filepath.stem,
                "object_name": chain[-1] if chain else "",
                "class_name": class_name,
                "full_path": ".".join(chain)
            }

    def find_properties_start(self, exp_offset, exp_size):
        common_props = {
            "TerrainScale", "TerrainMap", "Location", "Rotation", "Layers", "Tag", "bHidden",
            "Format", "Palette", "bStaticLighting", "bUseAlpha", "TerrainSectorSize"
        }
        limit = min(exp_offset + 64, exp_offset + exp_size)
        for offset in range(exp_offset, limit):
            self.pos = offset
            try:
                name_idx = self.read_compact_index()
                if 0 <= name_idx < len(self.names):
                    prop_name = self.names[name_idx]
                    if prop_name in common_props:
                        info_byte = self.data[self.pos]
                        prop_type = info_byte & 0x0F
                        if 1 <= prop_type <= 14:
                            return offset
            except Exception:
                pass
        return exp_offset

    def read_properties(self, start_offset: int, max_bytes: int):
        self.pos = start_offset
        limit = start_offset + max_bytes
        props = {}

        while self.pos < limit:
            name_idx = self.read_compact_index()
            if name_idx < 0 or name_idx >= len(self.names):
                break
            prop_name = self.names[name_idx]
            if prop_name == "None":
                break

            info_byte = self.data[self.pos]
            self.pos += 1
            prop_type = info_byte & 0x0F
            size_type = (info_byte >> 4) & 0x07
            is_array = (info_byte >> 7) & 0x01

            struct_name = ""
            if prop_type == 10:  # StructProperty
                struct_name_idx = self.read_compact_index()
                struct_name = self.names[struct_name_idx] if 0 <= struct_name_idx < len(self.names) else ""

            size = 0
            if size_type == 0:
                size = 1
            elif size_type == 1:
                size = 2
            elif size_type == 2:
                size = 4
            elif size_type == 3:
                size = 12
            elif size_type == 4:
                size = 16
            elif size_type == 5:
                size = self.data[self.pos]
                self.pos += 1
            elif size_type == 6:
                size = struct.unpack_from("<H", self.data, self.pos)[0]
                self.pos += 2
            elif size_type == 7:
                size = struct.unpack_from("<I", self.data, self.pos)[0]
                self.pos += 4

            array_index = 0
            if is_array and prop_type != 3:
                array_index = self.read_compact_index()

            prop_data_start = self.pos
            val = None

            if prop_type == 1:
                if size == 1:
                    val = self.data[self.pos]
                else:
                    idx = self.read_compact_index()
                    val = self.names[idx] if 0 <= idx < len(self.names) else ""
            elif prop_type == 2:
                val = struct.unpack_from("<i", self.data, self.pos)[0]
            elif prop_type == 3:
                val = bool(is_array)
            elif prop_type == 4:
                val = struct.unpack_from("<f", self.data, self.pos)[0]
            elif prop_type == 5:
                val = self.resolve_object_reference(self.read_compact_index())
            elif prop_type == 6:
                idx = self.read_compact_index()
                val = self.names[idx] if 0 <= idx < len(self.names) else ""
            elif prop_type == 10:
                payload_len = prop_data_start + size - self.pos
                if struct_name == "Vector" and payload_len >= 12:
                    val = struct.unpack_from("<fff", self.data, self.pos)
                elif struct_name == "Rotator" and payload_len >= 12:
                    val = struct.unpack_from("<iii", self.data, self.pos)
                elif struct_name == "Color" and payload_len >= 4:
                    val = struct.unpack_from("<BBBB", self.data, self.pos)
                elif struct_name == "Plane" and payload_len >= 16:
                    v = struct.unpack_from("<ffff", self.data, self.pos)
                    val = {'X': v[0], 'Y': v[1], 'Z': v[2], 'W': v[3]}
                elif struct_name == "Matrix" and payload_len >= 64:
                    m = struct.unpack_from("<ffffffffffffffff", self.data, self.pos)
                    val = {
                        'XPlane': {'X': m[0], 'Y': m[1], 'Z': m[2], 'W': m[3]},
                        'YPlane': {'X': m[4], 'Y': m[5], 'Z': m[6], 'W': m[7]},
                        'ZPlane': {'X': m[8], 'Y': m[9], 'Z': m[10], 'W': m[11]},
                        'WPlane': {'X': m[12], 'Y': m[13], 'Z': m[14], 'W': m[15]}
                    }
                else:
                    val = self.read_properties(self.pos, payload_len)

            self.pos = prop_data_start + size

            if prop_name not in props:
                if is_array or array_index > 0:
                    props[prop_name] = {"_is_array": True, array_index: val}
                else:
                    props[prop_name] = val
            else:
                if not isinstance(props[prop_name], dict) or not props[prop_name].get("_is_array"):
                    old_v = props[prop_name]
                    props[prop_name] = {"_is_array": True, 0: old_v}
                props[prop_name][array_index] = val

        return props

    def extract_image_by_export_name(self, target_name: str) -> Image.Image:
        if not target_name:
            return None
        clean_target = target_name.lower().split('.')[-1]

        matched = next((e for e in self.exports if e["object_name"].lower() == clean_target), None)
        if not matched:
            matched = next((e for e in self.exports if clean_target in e["object_name"].lower()), None)
        if not matched:
            return None

        # Lê propriedades para descobrir formato exato e dimensões declaradas
        prop_start = self.find_properties_start(matched["offset"], matched["size"])
        props = self.read_properties(prop_start, matched["size"] - (prop_start - matched["offset"]))

        # Segue a referência do Shader/Material se aplicável
        if matched["class_name"] in ("Shader", "FinalBlend", "Combiner", "Material"):
            diff_ref = props.get("Diffuse") or props.get("Material") or props.get("Material1")
            if isinstance(diff_ref, dict) and diff_ref.get("_is_array"):
                diff_ref = diff_ref.get(0)
            if isinstance(diff_ref, dict) and "object_name" in diff_ref:
                return self.extract_image_by_export_name(diff_ref["object_name"])

        format_val = props.get("Format")
        u_size = props.get("USize", 0)
        v_size = props.get("VSize", 0)

        exp_data = self.data[matched["offset"] : matched["offset"] + matched["size"]]

        target_resolutions = []
        if isinstance(u_size, int) and isinstance(v_size, int) and u_size > 0 and v_size > 0:
            target_resolutions.append((u_size, v_size))
        for res in [2048, 1024, 512, 256, 128, 64]:
            if (res, res) not in target_resolutions:
                target_resolutions.append((res, res))

        for (rw, rh) in target_resolutions:
            footer_pattern = struct.pack("<II", rw, rh)
            pos = exp_data.rfind(footer_pattern)
            if pos != -1:
                # DXT1 (Format 3)
                if format_val == 3:
                    dxt1_sz = (rw * rh) // 2
                    if pos >= dxt1_sz:
                        img = decode_dxt1_to_image(exp_data[pos - dxt1_sz : pos], rw, rh)
                        if img:
                            return img
                # DXT3 / DXT5 (Format 5 ou 6)
                elif format_val in (5, 6):
                    dxt5_sz = rw * rh
                    if pos >= dxt5_sz:
                        img = decode_dxt5_to_image(exp_data[pos - dxt5_sz : pos], rw, rh)
                        if img:
                            return img
                # G8 / Grayscale (Format 7)
                elif format_val == 7:
                    g8_sz = rw * rh
                    if pos >= g8_sz:
                        g8_raw = exp_data[pos - g8_sz : pos]
                        arr = np.frombuffer(g8_raw, dtype=np.uint8).reshape((rh, rw))
                        return Image.fromarray(arr, mode='L')
                else:
                    # Fallback
                    dxt1_sz = (rw * rh) // 2
                    if pos >= dxt1_sz:
                        img = decode_dxt1_to_image(exp_data[pos - dxt1_sz : pos], rw, rh)
                        if img:
                            return img
        return None


# ==============================================================================
# 4. AMBIENTE E AUTO-DESCOBERTA DE DIRETÓRIOS DO LINEAGE II
# ==============================================================================
class L2Environment:
    def __init__(self, input_file: Path, l2_root: Path = None):
        self.input_file = input_file.resolve()
        self.l2_root = self._resolve_l2_root(l2_root)
        self.textures_dir = self.l2_root / "textures" if self.l2_root else None
        self.systextures_dir = self.l2_root / "systextures" if self.l2_root else None
        self.maps_dir = self.l2_root / "maps" if self.l2_root else None
        self.staticmeshes_dir = self.l2_root / "staticmeshes" if self.l2_root else None

        self.available_utx = {}
        self.package_cache = {}
        self._index_packages()

    def _resolve_l2_root(self, explicit_root: Path) -> Path:
        if explicit_root and explicit_root.is_dir():
            return explicit_root.resolve()

        # Tenta inferir subindo a partir de maps/16_24.unr
        candidate = self.input_file.parent
        if candidate.name.lower() == "maps" and (candidate.parent / "textures").is_dir():
            return candidate.parent.resolve()

        if (self.input_file.parent / "textures").is_dir():
            return self.input_file.parent.resolve()

        return self.input_file.parent.resolve()

    def _index_packages(self):
        search_dirs = [self.textures_dir, self.systextures_dir, self.maps_dir, self.input_file.parent]
        for d in search_dirs:
            if d and d.is_dir():
                for f in d.iterdir():
                    if f.is_file() and f.suffix.lower() == ".utx":
                        self.available_utx[f.stem.lower()] = f

    def get_package(self, pkg_name: str) -> UnrealPackageReader:
        if not pkg_name:
            return None
        clean_name = pkg_name.lower().replace(".utx", "").replace(".usx", "").replace(".u", "")
        if clean_name in self.package_cache:
            return self.package_cache[clean_name]

        if clean_name in self.available_utx:
            try:
                reader = UnrealPackageReader(self.available_utx[clean_name])
                self.package_cache[clean_name] = reader
                return reader
            except Exception:
                pass
        return None


# ==============================================================================
# 5. GERADOR DE MALHA 3D (.GLB BINÁRIO PURO)
# ==============================================================================
def build_terrain_mesh(heights: np.ndarray, scale: tuple, location: tuple, unit_scale: float = UU_TO_METERS_DEFAULT, step: int = 1):
    if step > 1:
        heights = heights[::step, ::step]
    rows, cols = heights.shape
    sx = float(scale[0]) * step * unit_scale
    sz_world = float(scale[1]) * step * unit_scale  # Em Godot, Z é profundidade horizontal
    sy_scale = float(scale[2]) * unit_scale        # Em Godot, Y é altitude

    # Centraliza a malha em torno da origem local do chunk
    xs = (np.arange(cols, dtype=np.float32) - (cols / 2.0)) * sx
    zs = (np.arange(rows, dtype=np.float32) - (rows / 2.0)) * sz_world

    grid_x, grid_z = np.meshgrid(xs, zs)
    # Altitude em metros
    world_y = (heights.astype(np.float32) - 32768.0) * (sy_scale / 128.0)

    # Normais de superfície
    dz, dx = np.gradient(world_y, sz_world, sx)
    nx = -dx
    ny = np.ones_like(world_y)
    nz = -dz
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    normals = np.stack([nx * inv_len, ny * inv_len, nz * inv_len], axis=-1).reshape(-1, 3).astype(np.float32)

    positions = np.stack([grid_x, world_y, grid_z], axis=-1).reshape(-1, 3).astype(np.float32)

    # Coordenadas UV [0..1]
    us = np.linspace(0.0, 1.0, cols, dtype=np.float32)
    vs = np.linspace(0.0, 1.0, rows, dtype=np.float32)
    gu, gv = np.meshgrid(us, vs)
    uvs = np.stack([gu, gv], axis=-1).reshape(-1, 2).astype(np.float32)

    # Triângulos
    row_indices = np.arange(rows - 1, dtype=np.uint32)
    col_indices = np.arange(cols - 1, dtype=np.uint32)
    rr, cc = np.meshgrid(row_indices, col_indices, indexing="ij")

    a = rr * cols + cc
    b = a + 1
    d = a + cols
    e = d + 1
    triangle_a = np.stack([a, d, b], axis=-1).reshape(-1, 3)
    triangle_b = np.stack([b, d, e], axis=-1).reshape(-1, 3)
    triangles = np.concatenate([triangle_a, triangle_b], axis=0)

    return positions, normals, uvs, triangles, world_y


def write_glb(filepath: Path, name: str, positions: np.ndarray, normals: np.ndarray, uvs: np.ndarray, triangles: np.ndarray):
    position_data = np.ascontiguousarray(positions, dtype="<f4")
    normal_data = np.ascontiguousarray(normals, dtype="<f4")
    uv_data = np.ascontiguousarray(uvs, dtype="<f4")
    index_data = np.ascontiguousarray(triangles.reshape(-1), dtype="<u4")

    raw_buffers = [position_data.tobytes(), normal_data.tobytes(), uv_data.tobytes(), index_data.tobytes()]

    blobs = []
    buffer_views = []
    offset = 0
    for data in raw_buffers:
        padding = (-len(data)) % 4
        padded = data + b"\x00" * padding
        blobs.append(padded)
        buffer_views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data)})
        offset += len(padded)

    binary_chunk = b"".join(blobs)
    vertex_count = int(len(position_data))

    pbr_config = {
        "metallicFactor": 0.0,
        "roughnessFactor": 0.85,
        "baseColorFactor": [0.75, 0.75, 0.78, 1.0]
    }

    gltf = {
        "asset": {"version": "2.0", "generator": "l2_build_chunk.py (Godotage II)"},
        "scene": 0,
        "scenes": [{"nodes": [0], "name": name}],
        "nodes": [{"mesh": 0, "name": name}],
        "materials": [{"name": "TerrainMaterial", "doubleSided": True, "pbrMetallicRoughness": pbr_config}],
        "meshes": [{
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                "indices": 3,
                "material": 0,
                "mode": 4
            }]
        }],
        "buffers": [{"byteLength": len(binary_chunk)}],
        "bufferViews": buffer_views,
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC3",
                "min": position_data.min(axis=0).tolist(),
                "max": position_data.max(axis=0).tolist()
            },
            {
                "bufferView": 1,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC3"
            },
            {
                "bufferView": 2,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC2"
            },
            {
                "bufferView": 3,
                "componentType": 5125,
                "count": int(index_data.size),
                "type": "SCALAR"
            },
        ],
    }

    json_chunk = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * ((-len(json_chunk)) % 4)
    total_length = 12 + 8 + len(json_chunk) + 8 + len(binary_chunk)

    with open(filepath, "wb") as file:
        file.write(struct.pack("<III", 0x46546C67, 2, total_length))
        file.write(struct.pack("<II", len(json_chunk), 0x4E4F534A))
        file.write(json_chunk)
        file.write(struct.pack("<II", len(binary_chunk), 0x004E4942))
        file.write(binary_chunk)


# ==============================================================================
# 6. COMPILADOR PRINCIPAL DE CHUNK
# ==============================================================================
class L2ChunkCompiler:
    def __init__(self, input_file: Path, output_dir: Path, l2_root: Path = None, unit_scale: float = UU_TO_METERS_DEFAULT):
        self.input_file = input_file.resolve()
        self.env = L2Environment(self.input_file, l2_root)
        self.pkg = UnrealPackageReader(self.input_file)
        self.unit_scale = unit_scale

        self.clean_stem = self.input_file.stem
        if self.clean_stem.lower().startswith("t_"):
            self.clean_stem = self.clean_stem[2:]

        self.chunk_dir = output_dir / self.clean_stem
        self.server_dir = self.chunk_dir / "server"
        self.client_dir = self.chunk_dir / "client"
        self.client_textures_dir = self.client_dir / "textures"

    def compile(self, step: int = 1, pack_splatmaps: bool = True):
        start_time = time.time()
        self._print_banner()

        # Cria pastas de saída
        self.server_dir.mkdir(parents=True, exist_ok=True)
        self.client_textures_dir.mkdir(parents=True, exist_ok=True)

        # 1. Extração do TerrainInfo
        terrains = self._extract_terrains()
        if not terrains:
            sys.exit(f"[ERRO] Nenhum TerrainInfo encontrado em {self.input_file.name}")

        t_info = terrains[0]
        scale = t_info.get("scale", (64.0, 64.0, 32.0))
        location = t_info.get("location", (0.0, 0.0, 0.0))

        # 2. Extração do Heightmap G16
        heights = self._extract_heightmap(t_info)
        if heights is None:
            sys.exit(f"[ERRO] Não foi possível decodificar o Heightmap G16 de {self.input_file.name}")

        # 3. Construção da Malha e Cálculo de Altitudes
        positions, normals, uvs, triangles, world_y_matrix = build_terrain_mesh(
            heights, scale, location, self.unit_scale, step
        )

        h_min = float(world_y_matrix.min())
        h_max = float(world_y_matrix.max())
        h_delta = h_max - h_min

        # 4. Impressão de Dados de Domínio
        self._print_terrain_info(scale, location, heights.shape, h_min, h_max, h_delta)
        self._print_layers_table(t_info.get("layers", []))

        # 5. Geração de Artefatos do Servidor
        server_files = self._generate_server_artifacts(heights, world_y_matrix, scale, location, h_min, h_max)

        # 6. Geração de Artefatos do Cliente
        client_files = self._generate_client_artifacts(t_info, heights, positions, normals, uvs, triangles, pack_splatmaps)

        # 7. Resumo de Artefatos Gerados
        self._print_artifacts_summary(server_files, client_files, time.time() - start_time)

    def _extract_terrains(self):
        terrains = []
        for exp in self.pkg.exports:
            if exp["class_name"] == "TerrainInfo":
                prop_start = self.pkg.find_properties_start(exp["offset"], exp["size"])
                props = self.pkg.read_properties(prop_start, exp["size"] - (prop_start - exp["offset"]))

                scale = props.get("TerrainScale", (64.0, 64.0, 32.0))
                location = props.get("Location", (0.0, 0.0, 0.0))
                terrain_map_ref = props.get("TerrainMap", None)

                if isinstance(scale, dict) and scale.get("_is_array"):
                    scale = scale.get(0, (64.0, 64.0, 32.0))
                if isinstance(location, dict) and location.get("_is_array"):
                    location = location.get(0, (0.0, 0.0, 0.0))
                if isinstance(terrain_map_ref, dict) and terrain_map_ref.get("_is_array"):
                    terrain_map_ref = terrain_map_ref.get(0)

                layers = []
                raw_layers = props.get("Layers")
                if isinstance(raw_layers, dict) and raw_layers.get("_is_array"):
                    for k in sorted([idx for idx in raw_layers.keys() if isinstance(idx, int)]):
                        l_data = raw_layers[k]
                        if isinstance(l_data, dict):
                            t_ref = l_data.get("Texture") or l_data.get("Material")
                            a_ref = l_data.get("AlphaMap")
                            u_sc = l_data.get("UScale", 1.0)
                            v_sc = l_data.get("VScale", 1.0)

                            if isinstance(t_ref, dict) and t_ref.get("_is_array"):
                                t_ref = t_ref.get(0)
                            if isinstance(a_ref, dict) and a_ref.get("_is_array"):
                                a_ref = a_ref.get(0)
                            if isinstance(u_sc, dict) and u_sc.get("_is_array"):
                                u_sc = u_sc.get(0, 1.0)
                            if isinstance(v_sc, dict) and v_sc.get("_is_array"):
                                v_sc = v_sc.get(0, 1.0)

                            layers.append({
                                "index": k,
                                "texture_ref": t_ref,
                                "alpha_ref": a_ref,
                                "u_scale": float(u_sc or 1.0),
                                "v_scale": float(v_sc or 1.0),
                            })

                terrains.append({
                    "name": exp["object_name"],
                    "scale": scale,
                    "location": location,
                    "map_ref": terrain_map_ref,
                    "layers": layers,
                })
        return terrains

    def _extract_heightmap(self, terrain_info):
        t_map = terrain_info.get("map_ref")
        packages_to_search = [self.pkg]

        pkg_t = self.env.get_package(f"t_{self.clean_stem}") or self.env.get_package(self.clean_stem)
        if pkg_t:
            packages_to_search.insert(0, pkg_t)

        if t_map and isinstance(t_map, dict):
            obj_name = t_map.get("object_name", "")
            if obj_name:
                for package in packages_to_search:
                    arr = self._decode_heightmap_from_pkg(package, obj_name)
                    if arr is not None:
                        return arr

        for package in packages_to_search:
            for exp in package.exports:
                name_lower = exp["object_name"].lower()
                if any(name_lower.endswith(suf) for suf in ("_c", "_d", "_s1", "_s2", "_s3", "_s4", "_s5")):
                    continue
                if "_t00" in name_lower or name_lower.endswith("t00") or name_lower == self.clean_stem:
                    arr = self._decode_heightmap_from_pkg(package, exp["object_name"])
                    if arr is not None:
                        return arr
        return None

    def _decode_heightmap_from_pkg(self, package, obj_name):
        clean_target = obj_name.lower()
        matched = next((e for e in package.exports if e["object_name"].lower() == clean_target), None)
        if not matched:
            matched = next((e for e in package.exports if clean_target in e["object_name"].lower()), None)
        if not matched:
            return None

        exp_data = package.data[matched["offset"] : matched["offset"] + matched["size"]]
        ci_131072 = b"\x40\x80\x10"
        footer_256 = struct.pack("<IIBB", 256, 256, 8, 8)

        ci_pos = exp_data.find(ci_131072)
        if ci_pos != -1:
            start = ci_pos + len(ci_131072)
            end = start + 131072
            if end + 10 <= len(exp_data) and exp_data[end : end + 10] == footer_256:
                return np.frombuffer(exp_data[start:end], dtype="<u2").reshape((256, 256))

        pos = exp_data.rfind(footer_256)
        if pos >= 131072:
            raw_bytes = exp_data[pos - 131072 : pos]
            return np.frombuffer(raw_bytes, dtype="<u2").reshape((256, 256))
        return None

    def _generate_server_artifacts(self, heights_g16: np.ndarray, world_y_matrix: np.ndarray, scale, location, h_min, h_max):
        # 1. heightfield.bin (Float32 Linear Buffer em Metros)
        hf_path = self.server_dir / "heightfield.bin"
        hf_data = np.ascontiguousarray(world_y_matrix, dtype="<f4")
        with open(hf_path, "wb") as f:
            f.write(hf_data.tobytes())

        # 2. chunk_meta.json
        coords = [int(p) for p in self.clean_stem.split("_") if p.isdigit()]
        chunk_x = coords[0] if len(coords) > 0 else 0
        chunk_y = coords[1] if len(coords) > 1 else 0

        rows, cols = heights_g16.shape
        sx_meters = float(scale[0]) * self.unit_scale
        sz_meters = float(scale[1]) * self.unit_scale

        meta = {
            "chunk_name": self.clean_stem,
            "chunk_indices": [chunk_x, chunk_y],
            "grid_resolution": [cols, rows],
            "unit_scale": self.unit_scale,
            "scale_uu": [float(scale[0]), float(scale[1]), float(scale[2])],
            "location_uu": [float(location[0]), float(location[1]), float(location[2])],
            "cell_size_meters": [sx_meters, sz_meters],
            "chunk_dimensions_meters": [cols * sx_meters, rows * sz_meters],
            "world_origin_meters": [float(location[0]) * self.unit_scale, float(location[2]) * self.unit_scale, float(location[1]) * self.unit_scale],
            "altitude_meters": {
                "min": round(h_min, 3),
                "max": round(h_max, 3),
                "delta": round(h_max - h_min, 3)
            }
        }
        meta_path = self.server_dir / "chunk_meta.json"
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=4)

        return [hf_path, meta_path]

    def _generate_client_artifacts(self, terrain_info, heights, positions, normals, uvs, triangles, pack_splatmaps):
        generated = []

        # 1. 16_24_visual.glb
        glb_path = self.client_dir / f"{self.clean_stem}_visual.glb"
        write_glb(glb_path, self.clean_stem, positions, normals, uvs, triangles)
        generated.append(glb_path)

        # 2. heightmap_16bit.png
        hm_path = self.client_dir / "heightmap_16bit.png"
        Image.fromarray(heights.astype(np.uint16)).save(hm_path, format="PNG")
        generated.append(hm_path)

        # 3. Macro Lightmap (_C)
        pkg_terrain = self.env.get_package(f"t_{self.clean_stem}") or self.env.get_package(self.clean_stem) or self.pkg
        lightmap_file = None
        if pkg_terrain:
            for exp in pkg_terrain.exports:
                if exp["object_name"].lower().endswith("_c") or exp["object_name"].lower() == f"{self.clean_stem}_c":
                    lm_img = pkg_terrain.extract_image_by_export_name(exp["object_name"])
                    if lm_img:
                        lm_path = self.client_dir / "lightmap.png"
                        lm_img.save(lm_path, format="PNG")
                        lightmap_file = "lightmap.png"
                        generated.append(lm_path)
                        break

        # 4. Texturas Difusas e Máscaras
        layers = terrain_info.get("layers", [])
        layer_masks = []
        recipe_layers = []

        for l in layers:
            idx = l["index"]
            t_ref = l.get("texture_ref")
            a_ref = l.get("alpha_ref")
            u_sc = l.get("u_scale", 1.0)
            v_sc = l.get("v_scale", 1.0)

            diff_file = None
            if isinstance(t_ref, dict) and "object_name" in t_ref:
                pkg_t = self.env.get_package(t_ref["package"]) or pkg_terrain or self.pkg
                t_img = pkg_t.extract_image_by_export_name(t_ref["object_name"])
                if t_img:
                    t_filename = f"layer_{idx}_tex_{t_ref['object_name']}.png"
                    t_path = self.client_textures_dir / t_filename
                    t_img.save(t_path, format="PNG")
                    diff_file = f"textures/{t_filename}"
                    generated.append(t_path)

            mask_img = None
            if isinstance(a_ref, dict) and "object_name" in a_ref:
                pkg_a = self.env.get_package(a_ref["package"]) or pkg_terrain or self.pkg
                a_img = pkg_a.extract_image_by_export_name(a_ref["object_name"])
                if a_img:
                    mask_img = a_img.convert("L")

            layer_masks.append((idx, mask_img))
            recipe_layers.append({
                "layer_index": idx,
                "texture_file": diff_file,
                "u_scale": u_sc,
                "v_scale": v_sc,
                "splatmap_index": -1,
                "splatmap_channel": "BASE"
            })

        # 5. Empacotamento de Splatmaps RGBA (4 canais por textura)
        splatmap_files = []
        if pack_splatmaps:
            active_masks = [(idx, img) for (idx, img) in layer_masks if idx > 0 and img is not None]
            splat_idx = 0
            channels = ["R", "G", "B", "A"]

            if not active_masks:
                # Chunk sem camadas extras (ex: oceano puro 17_24): cria splatmap zerado
                empty_splat = np.zeros((256, 256, 4), dtype=np.uint8)
                splat_filename = "splatmap_0.png"
                splat_path = self.client_dir / splat_filename
                Image.fromarray(empty_splat, mode="RGBA").save(splat_path, format="PNG")
                splatmap_files.append(splat_filename)
                generated.append(splat_path)
            else:
                for i in range(0, len(active_masks), 4):
                    batch = active_masks[i : i + 4]
                    # Garante resolução mínima de 1024x1024 para interpolação suave
                    splat_w = max(1024, max(m.size[0] for _, m in batch))
                    splat_h = max(1024, max(m.size[1] for _, m in batch))
                    rgba_arr = np.zeros((splat_h, splat_w, 4), dtype=np.uint8)

                    for ch_idx, (layer_orig_idx, m_img) in enumerate(batch):
                        # Interpolação bicúbica suave + filtro leve para eliminar serrilhado
                        m_resized = m_img.resize((splat_w, splat_h), resample=Image.Resampling.BICUBIC)
                        m_resized = m_resized.filter(ImageFilter.GaussianBlur(radius=0.75))
                        rgba_arr[:, :, ch_idx] = np.array(m_resized)

                        # Atualiza a receita
                        for r_l in recipe_layers:
                            if r_l["layer_index"] == layer_orig_idx:
                                r_l["splatmap_index"] = splat_idx
                                r_l["splatmap_channel"] = channels[ch_idx]

                    splat_filename = f"splatmap_{splat_idx}.png"
                    splat_path = self.client_dir / splat_filename
                    Image.fromarray(rgba_arr, mode="RGBA").save(splat_path, format="PNG")
                    splatmap_files.append(splat_filename)
                    generated.append(splat_path)
                    splat_idx += 1

        # 6. terrain_recipe.json
        recipe = {
            "chunk_name": self.clean_stem,
            "lightmap": lightmap_file,
            "splatmaps": splatmap_files,
            "layers": recipe_layers
        }
        recipe_path = self.client_dir / "terrain_recipe.json"
        with open(recipe_path, "w", encoding="utf-8") as f:
            json.dump(recipe, f, indent=4)
        generated.append(recipe_path)

        return generated

    # ==========================================================================
    # LOGS ESTRUTURADOS DE TERMINAL
    # ==========================================================================
    def _print_banner(self):
        print("\n" + "=" * 80)
        print(f"[*] COMPILADOR DE CHUNKS LINEAGE II -> GODOTAGE II")
        print(f"[*] MAPA: {self.input_file.name} | PACOTE: Unreal Engine 2 (L2 Encrypted)")
        print("=" * 80)
        print("\n[+] 1. DESCOBERTA DE AMBIENTE & DIRETÓRIOS")
        print(f"    -> Raiz do Lineage II : {self.env.l2_root}")
        print(f"    -> Pacotes .UTX Disp. : {len(self.env.available_utx)} encontrados")
        print(f"    -> Pasta de Saída     : {self.chunk_dir.resolve()}")

    def _print_terrain_info(self, scale, location, res, h_min, h_max, h_delta):
        sx_m = float(scale[0]) * self.unit_scale
        sz_m = float(scale[1]) * self.unit_scale
        print("\n[+] 2. DADOS DE DOMÍNIO DO TERRENO (TerrainInfo)")
        print(f"    -> Escala do Terreno  : {scale} UU")
        print(f"    -> Localização Base   : {location} UU")
        print(f"    -> Resolução da Grade : {res[1]} x {res[0]} células ({res[1]+1} x {res[0]+1} vértices)")
        print(f"    -> Dimensão Lateral   : {res[1] * sx_m:.1f}m x {res[0] * sz_m:.1f}m")
        print(f"    -> Altitude em Metros : Min = {h_min:.1f}m | Max = {h_max:.1f}m | Desnível = {h_delta:.1f}m")

    def _print_layers_table(self, layers):
        print("\n[+] 3. TABELA DE CAMADAS DO TERRENO (TerrainLayers)")
        print(" +------+------------------------------+------------------------------+------------+------------+")
        print(" | Lyr  | Textura / Material           | Mascara / Alpha              | UScale     | VScale     |")
        print(" +------+------------------------------+------------------------------+------------+------------+")
        for l in layers:
            idx = l["index"]
            t_ref = l.get("texture_ref")
            a_ref = l.get("alpha_ref")
            t_str = t_ref.get("full_path", "None") if isinstance(t_ref, dict) else "None"
            a_str = a_ref.get("full_path", "[BASE / 100%]") if isinstance(a_ref, dict) else "[BASE / 100%]"
            print(f" | {idx:<4} | {t_str:<28} | {a_str:<28} | {l['u_scale']:<10.1f} | {l['v_scale']:<10.1f} |")
        print(" +------+------------------------------+------------------------------+------------+------------+")

    def _print_artifacts_summary(self, server_files, client_files, elapsed):
        print("\n[+] 4. GERAÇÃO DE ARTEFATOS OTIMIZADOS")
        print("    [SERVIDOR (Física & Bounds)]")
        for sf in server_files:
            sz_kb = sf.stat().st_size / 1024.0
            print(f"     -> {sf.name:<25} ({sz_kb:.1f} KB)")

        print("    [CLIENTE (Godot 4.7 Rendering & Splatmaps)]")
        for cf in client_files:
            sz_kb = cf.stat().st_size / 1024.0
            unit = "KB" if sz_kb < 1024 else "MB"
            val = sz_kb if sz_kb < 1024 else sz_kb / 1024.0
            rel_name = cf.relative_to(self.client_dir)
            print(f"     -> {str(rel_name):<25} ({val:.1f} {unit})")

        print(f"\n[*] Compilação concluída com sucesso em {elapsed:.2f}s!")
        print("=" * 80 + "\n")


# ==============================================================================
# 7. PONTO DE ENTRADA CLI
# ==============================================================================
def main():
    parser = argparse.ArgumentParser(description="Compilador de Chunks de Terreno Lineage II -> Godotage II")
    parser.add_argument("input", help="Caminho do arquivo .unr ou nome do chunk (ex: 16_24.unr)")
    parser.add_argument("-o", "--output-dir", default=None, help="Diretório de destino (padrão: demos/XX_godot_age_2/assets/maps)")
    parser.add_argument("--l2-root", default=None, help="Caminho raiz da instalação do Lineage II")
    parser.add_argument("--step", type=int, default=1, help="Downsampling da malha 3D (1 = 100%, 2 = 50%)")
    parser.add_argument("--no-splat", action="store_true", help="Desativa o empacotamento em Splatmaps RGBA")
    parser.add_argument("--unit-scale", type=float, default=UU_TO_METERS_DEFAULT, help="Escala de conversão UU para Metros")

    args = parser.parse_args()

    input_path = Path(args.input)
    # Se passou apenas '16_24' ou '16_24.unr', procura na raiz do L2
    if not input_path.is_file():
        if args.l2_root:
            cand = Path(args.l2_root) / "maps" / (input_path.name if input_path.suffix else f"{input_path.name}.unr")
            if cand.is_file():
                input_path = cand
        elif (Path("C:/Users/LEONARDO/Documents/Lineage II/maps") / f"{input_path.stem}.unr").is_file():
            input_path = Path("C:/Users/LEONARDO/Documents/Lineage II/maps") / f"{input_path.stem}.unr"

    if not input_path.is_file():
        sys.exit(f"[ERRO] Arquivo .unr não encontrado: {args.input}")

    if args.output_dir:
        out_dir = Path(args.output_dir)
    else:
        # Padrão do projeto
        out_dir = Path(__file__).resolve().parent.parent / "assets" / "maps"

    compiler = L2ChunkCompiler(
        input_file=input_path,
        output_dir=out_dir,
        l2_root=Path(args.l2_root) if args.l2_root else None,
        unit_scale=args.unit_scale
    )
    compiler.compile(step=args.step, pack_splatmaps=not args.no_splat)


if __name__ == "__main__":
    main()
