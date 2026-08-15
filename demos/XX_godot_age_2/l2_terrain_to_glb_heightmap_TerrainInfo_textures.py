#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l2_terrain_to_glb.py

Lê o arquivo .unr, decodifica o cabeçalho binário e a receita completa de camadas
do TerrainInfo, gera a malha 3D (.glb) pura do Heightmap e, opcionalmente (--png / --export-textures),
extrai e salva todas as texturas, máscaras e o heightmap 16-bit em PNG em uma pasta dedicada.
"""

import argparse
import json
import os
import struct
import sys
import time
from pathlib import Path
import numpy as np
from PIL import Image

UE2_PACKAGE_TAG = 0x9E2A83C1
L2_BLOWFISH_KEY = b"lineage2"


# ==============================================================================
# 1. DESENCRIPTADOR LINEAGE 2
# ==============================================================================
class L2Decryptor:
    @staticmethod
    def is_valid_ue2_header(data: bytes, pos: int = 0) -> bool:
        if len(data) < pos + 36: return False
        if struct.unpack_from("<I", data, pos)[0] != UE2_PACKAGE_TAG: return False
        file_version = struct.unpack_from("<I", data, pos + 4)[0] & 0xFFFF
        if not (60 <= file_version <= 300): return False
        name_count = struct.unpack_from("<I", data, pos + 12)[0]
        name_offset = struct.unpack_from("<I", data, pos + 16)[0]
        return name_count > 0 and pos <= name_offset < len(data)

    @staticmethod
    def decrypt(raw_data: bytes) -> bytes:
        if L2Decryptor.is_valid_ue2_header(raw_data, 0): return raw_data
        for pos in range(0, min(512, len(raw_data) - 36)):
            if L2Decryptor.is_valid_ue2_header(raw_data, pos): return raw_data[pos:]

        candidate_offsets = [28, 156, 128, 64, 32, 20, 0]
        target_magic = struct.pack("<I", UE2_PACKAGE_TAG)

        for offset in candidate_offsets:
            if offset + 4 > len(raw_data): continue
            k0 = raw_data[offset] ^ target_magic[0]
            k1 = raw_data[offset + 1] ^ target_magic[1]
            k2 = raw_data[offset + 2] ^ target_magic[2]
            k3 = raw_data[offset + 3] ^ target_magic[3]
            xor_key = bytes([k0, k1, k2, k3])
            payload = raw_data[offset:]
            key_block = (xor_key * (len(payload) // 4 + 1))[:len(payload)]
            dec = np.bitwise_xor(np.frombuffer(payload, dtype=np.uint8), np.frombuffer(key_block, dtype=np.uint8)).tobytes()
            if L2Decryptor.is_valid_ue2_header(dec, 0): return dec

        for offset in candidate_offsets:
            if offset >= len(raw_data): continue
            dec = L2Decryptor._decrypt_blowfish_words_swapped(raw_data[offset:], L2_BLOWFISH_KEY)
            if L2Decryptor.is_valid_ue2_header(dec, 0): return dec
            tag_pos = dec.find(struct.pack("<I", UE2_PACKAGE_TAG))
            if tag_pos != -1 and L2Decryptor.is_valid_ue2_header(dec, tag_pos): return dec[tag_pos:]

        for offset in candidate_offsets:
            if offset >= len(raw_data): continue
            dec = L2Decryptor._decrypt_blowfish_raw(raw_data[offset:], L2_BLOWFISH_KEY)
            if L2Decryptor.is_valid_ue2_header(dec, 0): return dec
            tag_pos = dec.find(struct.pack("<I", UE2_PACKAGE_TAG))
            if tag_pos != -1 and L2Decryptor.is_valid_ue2_header(dec, tag_pos): return dec[tag_pos:]

        raise ValueError("Não foi possível sincronizar a assinatura Unreal Package.")

    @staticmethod
    def _decrypt_blowfish_words_swapped(data: bytes, key: bytes) -> bytes:
        from Crypto.Cipher import Blowfish
        rem = len(data) % 8
        unpadded_len = len(data) - rem
        if unpadded_len <= 0: return data
        arr = np.frombuffer(data[:unpadded_len], dtype="<u4").copy()
        arr.byteswap(inplace=True)
        cipher = Blowfish.new(key, Blowfish.MODE_ECB)
        decrypted_bytes = cipher.decrypt(arr.tobytes())
        dec_arr = np.frombuffer(decrypted_bytes, dtype="<u4").copy()
        dec_arr.byteswap(inplace=True)
        res = dec_arr.tobytes()
        if rem > 0: res += data[unpadded_len:]
        return res

    @staticmethod
    def _decrypt_blowfish_raw(data: bytes, key: bytes) -> bytes:
        from Crypto.Cipher import Blowfish
        rem = len(data) % 8
        unpadded_len = len(data) - rem
        if unpadded_len <= 0: return data
        cipher = Blowfish.new(key, Blowfish.MODE_ECB)
        res = cipher.decrypt(data[:unpadded_len])
        if rem > 0: res += data[unpadded_len:]
        return res


# ==============================================================================
# 2. DECODIFICADORES DE TEXTURAS (DXT1, DXT5, G8)
# ==============================================================================
def decode_dxt1_to_image(data: bytes, width: int, height: int) -> Image.Image:
    bx = max(1, width // 4); by = max(1, height // 4)
    num_blocks = bx * by; needed = num_blocks * 8
    if len(data) < needed: return None

    blocks = np.frombuffer(data[:needed], dtype=[('c0', '<u2'), ('c1', '<u2'), ('bits', '<u4')])
    c0 = blocks['c0'].astype(np.uint32); c1 = blocks['c1'].astype(np.uint32); bits = blocks['bits']

    r0 = (((c0 >> 11) & 0x1F) * 255 + 15) // 31
    g0 = (((c0 >> 5) & 0x3F) * 255 + 31) // 63
    b0 = ((c0 & 0x1F) * 255 + 15) // 31
    r1 = (((c1 >> 11) & 0x1F) * 255 + 15) // 31
    g1 = (((c1 >> 5) & 0x3F) * 255 + 31) // 63
    b1 = ((c1 & 0x1F) * 255 + 15) // 31

    palette = np.zeros((num_blocks, 4, 3), dtype=np.uint8)
    palette[:, 0, 0] = r0; palette[:, 0, 1] = g0; palette[:, 0, 2] = b0
    palette[:, 1, 0] = r1; palette[:, 1, 1] = g1; palette[:, 1, 2] = b1

    mask = c0 > c1
    palette[mask, 2, 0] = (2 * r0[mask] + r1[mask]) // 3
    palette[mask, 2, 1] = (2 * g0[mask] + g1[mask]) // 3
    palette[mask, 2, 2] = (2 * b0[mask] + b1[mask]) // 3
    palette[mask, 3, 0] = (r0[mask] + 2 * r1[mask]) // 3
    palette[mask, 3, 1] = (g0[mask] + 2 * g1[mask]) // 3
    palette[mask, 3, 2] = (b0[mask] + 2 * b1[mask]) // 3

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
    bx = max(1, width // 4); by = max(1, height // 4)
    num_blocks = bx * by; needed = num_blocks * 16
    if len(data) < needed: return None
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
        name_count, name_offset = struct.unpack_from("<II", self.data, self.pos); self.pos += 8
        export_count, export_offset = struct.unpack_from("<II", self.data, self.pos); self.pos += 8
        import_count, import_offset = struct.unpack_from("<II", self.data, self.pos); self.pos += 8

        self._read_names(name_count, name_offset)
        self._read_imports(import_count, import_offset)
        self._read_exports(export_count, export_offset)

    def read_compact_index(self, offset: int = None):
        if offset is not None: self.pos = offset
        b0 = self.data[self.pos]; self.pos += 1
        sign = b0 & 0x80; more = b0 & 0x40; value = b0 & 0x3F

        if more:
            b1 = self.data[self.pos]; self.pos += 1
            more = b1 & 0x80; value |= (b1 & 0x7F) << 6
            if more:
                b2 = self.data[self.pos]; self.pos += 1
                more = b2 & 0x80; value |= (b2 & 0x7F) << 13
                if more:
                    b3 = self.data[self.pos]; self.pos += 1
                    more = b3 & 0x80; value |= (b3 & 0x7F) << 20
                    if more:
                        b4 = self.data[self.pos]; self.pos += 1
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
            else: name_str = ""
            self.pos += 4
            self.names.append(name_str)

    def _read_imports(self, count, offset):
        self.pos = offset
        for _ in range(count):
            class_pkg = self.read_compact_index()
            class_name = self.read_compact_index()
            outer = struct.unpack_from("<i", self.data, self.pos)[0]; self.pos += 4
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
            outer_idx = struct.unpack_from("<i", self.data, self.pos)[0]; self.pos += 4
            name_idx = self.read_compact_index()
            flags = struct.unpack_from("<I", self.data, self.pos)[0]; self.pos += 4
            serial_size = self.read_compact_index()
            serial_offset = self.read_compact_index() if serial_size > 0 else 0

            class_name = "Class"
            if class_idx < 0: class_name = self.imports[-class_idx - 1]["object_name"]
            elif class_idx > 0: class_name = self.exports[class_idx - 1]["object_name"]

            obj_name = self.names[name_idx] if 0 <= name_idx < len(self.names) else f"Export_{len(self.exports)}"
            self.exports.append({
                "class_name": class_name, "object_name": obj_name, "class_idx": class_idx, "outer": outer_idx,
                "size": serial_size, "offset": serial_offset, "flags": flags,
            })

    def resolve_object_reference(self, index: int):
        if index == 0: return None
        chain = []; curr = index; class_name = ""

        if curr < 0:
            while curr < 0:
                imp_idx = -curr - 1
                if 0 <= imp_idx < len(self.imports):
                    imp = self.imports[imp_idx]
                    chain.append(imp["object_name"])
                    if not class_name: class_name = imp["class_name"]
                    curr = imp["outer"]
                else: break
            chain.reverse()
            pkg_name = chain[0] if len(chain) > 1 else (self.imports[-index - 1]["class_package"] if 0 <= -index - 1 < len(self.imports) else "")
            return {"type": "import", "package": pkg_name, "object_name": chain[-1] if chain else "", "class_name": class_name, "full_path": ".".join(chain)}
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
                    else: break
            chain.reverse()
            return {"type": "export", "package": self.filepath.stem, "object_name": chain[-1] if chain else "", "class_name": class_name, "full_path": ".".join(chain)}

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
            except: pass
        return exp_offset

    def read_properties(self, start_offset: int, max_bytes: int):
        self.pos = start_offset
        limit = start_offset + max_bytes
        props = {}

        while self.pos < limit:
            name_idx = self.read_compact_index()
            if name_idx < 0 or name_idx >= len(self.names): break
            prop_name = self.names[name_idx]
            if prop_name == "None": break

            info_byte = self.data[self.pos]; self.pos += 1
            prop_type = info_byte & 0x0F
            size_type = (info_byte >> 4) & 0x07
            is_array = (info_byte >> 7) & 0x01

            struct_name = ""
            if prop_type == 10:  # StructProperty
                struct_name_idx = self.read_compact_index()
                struct_name = self.names[struct_name_idx] if 0 <= struct_name_idx < len(self.names) else ""

            size = 0
            if size_type == 0: size = 1
            elif size_type == 1: size = 2
            elif size_type == 2: size = 4
            elif size_type == 3: size = 12
            elif size_type == 4: size = 16
            elif size_type == 5: size = self.data[self.pos]; self.pos += 1
            elif size_type == 6: size = struct.unpack_from("<H", self.data, self.pos)[0]; self.pos += 2
            elif size_type == 7: size = struct.unpack_from("<I", self.data, self.pos)[0]; self.pos += 4

            array_index = 0
            if is_array and prop_type != 3:
                array_index = self.read_compact_index()

            prop_data_start = self.pos
            val = None

            if prop_type == 1:
                if size == 1: val = self.data[self.pos]
                else: 
                    idx = self.read_compact_index()
                    val = self.names[idx] if 0 <= idx < len(self.names) else ""
            elif prop_type == 2: val = struct.unpack_from("<i", self.data, self.pos)[0]
            elif prop_type == 3: val = bool(is_array)
            elif prop_type == 4: val = struct.unpack_from("<f", self.data, self.pos)[0]
            elif prop_type == 5: val = self.resolve_object_reference(self.read_compact_index())
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
                if is_array or array_index > 0: props[prop_name] = {"_is_array": True, array_index: val}
                else: props[prop_name] = val
            else:
                if not isinstance(props[prop_name], dict) or not props[prop_name].get("_is_array"):
                    old_v = props[prop_name]
                    props[prop_name] = {"_is_array": True, 0: old_v}
                props[prop_name][array_index] = val

        return props

    def extract_image_by_export_name(self, target_name: str) -> Image.Image:
        """Localiza uma textura no pacote ou segue a referência Diffuse de um Shader."""
        if not target_name: return None
        clean_target = target_name.lower().split('.')[-1]
        
        matched = next((e for e in self.exports if e["object_name"].lower() == clean_target), None)
        if not matched:
            matched = next((e for e in self.exports if clean_target in e["object_name"].lower()), None)
        if not matched: return None

        # Segue a referência do Shader
        if matched["class_name"] in ("Shader", "FinalBlend", "Combiner", "Material"):
            prop_start = self.find_properties_start(matched["offset"], matched["size"])
            sh_props = self.read_properties(prop_start, matched["size"] - (prop_start - matched["offset"]))
            diff_ref = sh_props.get("Diffuse") or sh_props.get("Material") or sh_props.get("Material1")
            if isinstance(diff_ref, dict) and diff_ref.get("_is_array"): diff_ref = diff_ref.get(0)
            if isinstance(diff_ref, dict) and "object_name" in diff_ref:
                return self.extract_image_by_export_name(diff_ref["object_name"])

        # Decodifica Mipmap
        exp_data = self.data[matched["offset"] : matched["offset"] + matched["size"]]
        for res in [2048, 1024, 512, 256, 128, 64]:
            dxt1_sz = (res * res) // 2
            dxt5_sz = res * res
            footer_pattern = struct.pack("<II", res, res)
            pos = exp_data.rfind(footer_pattern)
            if pos != -1:
                if pos >= dxt1_sz:
                    img = decode_dxt1_to_image(exp_data[pos - dxt1_sz : pos], res, res)
                    if img: return img
                if pos >= dxt5_sz:
                    img = decode_dxt5_to_image(exp_data[pos - dxt5_sz : pos], res, res)
                    if img: return img
                if pos >= dxt5_sz:
                    g8_raw = exp_data[pos - dxt5_sz : pos]
                    arr = np.frombuffer(g8_raw, dtype=np.uint8).reshape((res, res))
                    return Image.fromarray(arr, mode='L')
        return None


# ==============================================================================
# 4. EXTRATOR DE TERRENO E DEPENDÊNCIAS
# ==============================================================================
class L2TerrainExtractor:
    def __init__(self, target_path: Path):
        self.target_path = target_path
        self.pkg = UnrealPackageReader(target_path)
        self.package_cache = {}
        
        root_dir = Path.cwd()
        self.search_dirs = [
            root_dir,
            root_dir / "textures",
            root_dir / "Textures",
            target_path.parent,
            target_path.parent / "textures"
        ]
        self.available_utx = {}
        self._map_available_textures()

    def _map_available_textures(self):
        for d in self.search_dirs:
            if d.exists() and d.is_dir():
                for f in d.iterdir():
                    if f.is_file() and f.suffix.lower() == ".utx":
                        self.available_utx[f.stem.lower()] = f

    def get_package(self, pkg_name: str) -> UnrealPackageReader:
        clean_name = pkg_name.lower().replace(".utx", "").replace(".usx", "").replace(".u", "")
        if clean_name in self.package_cache:
            return self.package_cache[clean_name]
            
        if clean_name in self.available_utx:
            try:
                reader = UnrealPackageReader(self.available_utx[clean_name])
                self.package_cache[clean_name] = reader
                return reader
            except: pass
        return None

    def extract_terrain_infos(self, print_log=True):
        terrains = []
        for exp in self.pkg.exports:
            if exp["class_name"] == "TerrainInfo":
                prop_start = self.pkg.find_properties_start(exp["offset"], exp["size"])
                props = self.pkg.read_properties(prop_start, exp["size"] - (prop_start - exp["offset"]))
                
                scale = props.get("TerrainScale", (64.0, 64.0, 32.0))
                location = props.get("Location", (0.0, 0.0, 0.0))
                terrain_map_ref = props.get("TerrainMap", None)

                if isinstance(scale, dict) and scale.get("_is_array"): scale = scale.get(0, (64.0, 64.0, 32.0))
                if isinstance(location, dict) and location.get("_is_array"): location = location.get(0, (0.0, 0.0, 0.0))
                if isinstance(terrain_map_ref, dict) and terrain_map_ref.get("_is_array"): terrain_map_ref = terrain_map_ref.get(0)

                t_map_full_path = terrain_map_ref.get("full_path", "Unknown") if isinstance(terrain_map_ref, dict) else "None"

                if print_log:
                    print(f"[*] Export Encontrado : '{exp['object_name']}'")
                    print(f"[*] Deslocamento Raw  : {exp['offset']} bytes")
                    print(f"[*] Início Propriedades: {prop_start} bytes (pulando cabeçalho de {prop_start - exp['offset']} bytes)\n")
                    
                    print("--- PROPRIEDADES GERAIS DE TERRENO ---")
                    print(f" -> TerrainScale : {scale}")
                    print(f" -> Location     : {location}")
                    print(f" -> TerrainMap   : {t_map_full_path}\n")

                layers = []
                raw_layers = props.get("Layers")
                if isinstance(raw_layers, dict) and raw_layers.get("_is_array"):
                    if print_log:
                        print("--- ARRAY DE CAMADAS (TerrainLayer) ---\n")

                    for k in sorted([idx for idx in raw_layers.keys() if isinstance(idx, int)]):
                        l_data = raw_layers[k]
                        if isinstance(l_data, dict):
                            t_ref = l_data.get("Texture") or l_data.get("Material")
                            a_ref = l_data.get("AlphaMap")
                            u_sc = l_data.get("UScale", 1.0)
                            v_sc = l_data.get("VScale", 1.0)

                            if isinstance(t_ref, dict) and t_ref.get("_is_array"): t_ref = t_ref.get(0)
                            if isinstance(a_ref, dict) and a_ref.get("_is_array"): a_ref = a_ref.get(0)
                            if isinstance(u_sc, dict) and u_sc.get("_is_array"): u_sc = u_sc.get(0, 1.0)
                            if isinstance(v_sc, dict) and v_sc.get("_is_array"): v_sc = v_sc.get(0, 1.0)

                            t_path = t_ref.get("full_path") if isinstance(t_ref, dict) else "None"
                            a_path = a_ref.get("full_path") if isinstance(a_ref, dict) else "[TEXTURA BASE / 100% COBERTURA]"

                            if print_log:
                                print(f"Camada [{k}]:")
                                print(f"   * Material/Textura : {t_path}")
                                print(f"   * Máscara / Alpha  : {a_path}")
                                print(f"   * Fator de Escala  : UScale = {u_sc}, VScale = {v_sc}\n")

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

    def print_dependencies(self):
        print("\n" + "=" * 80)
        print("[*] LISTA COMPLETA DE DEPENDÊNCIAS EXTERNAS REGISTRADAS NO .UNR:")
        print("=" * 80)
        imported_pkgs = set()
        for imp in self.pkg.imports:
            if imp["class_name"] == "Package" and imp["outer"] == 0:
                imported_pkgs.add(imp["object_name"])
            elif imp["outer"] < 0:
                curr = imp
                while curr["outer"] < 0: curr = self.pkg.imports[-curr["outer"] - 1]
                imported_pkgs.add(curr["object_name"])

        for p_name in sorted(imported_pkgs):
            is_present = p_name.lower() in self.available_utx
            status = f"[ENCONTRADO -> textures/{self.available_utx[p_name.lower()].name}]" if is_present else "[PACOTE EXTERNO / ÁUDIO / MESH]"
            print(f"    -> {p_name:<25} {status}")
        print("=" * 80 + "\n")

    def _decode_heightmap(self, package, obj_name):
        clean_target = obj_name.lower()
        matched = next((e for e in package.exports if e["object_name"].lower() == clean_target), None)
        if not matched: 
            matched = next((e for e in package.exports if clean_target in e["object_name"].lower()), None)
        if not matched: return None

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

    def extract_exact_t00_heightmap(self, terrain_info):
        t_map = terrain_info.get("map_ref")
        packages_to_search = [self.pkg]
        
        raw_stem = self.target_path.stem.lower()
        clean_stem = raw_stem[2:] if raw_stem.startswith("t_") else raw_stem
        for d in self.search_dirs:
            if d.exists() and d.is_dir():
                utx_path = d / f"t_{clean_stem}.utx"
                if utx_path.exists():
                    try:
                        packages_to_search.insert(0, UnrealPackageReader(utx_path))
                    except: pass

        if t_map and isinstance(t_map, dict):
            obj_name = t_map.get("object_name", "")
            if obj_name:
                for package in packages_to_search:
                    img_arr = self._decode_heightmap(package, obj_name)
                    if img_arr is not None:
                        print(f"[OK] Heightmap G16 '{obj_name}' extraído da propriedade TerrainMap ({img_arr.shape[1]}x{img_arr.shape[0]}).")
                        return img_arr

        for package in packages_to_search:
            for exp in package.exports:
                name_lower = exp["object_name"].lower()
                if any(name_lower.endswith(suf) for suf in ("_c", "_d", "_s1", "_s2", "_s3", "_s4", "_s5")): continue
                if "_t00" in name_lower or name_lower.endswith("t00") or name_lower == clean_stem:
                    img_arr = self._decode_heightmap(package, exp["object_name"])
                    if img_arr is not None:
                        print(f"[OK] Heightmap G16 '{exp['object_name']}' extraído via busca ({img_arr.shape[1]}x{img_arr.shape[0]}).")
                        return img_arr
        return None

    def export_all_textures_png(self, terrain_info: dict, heights: np.ndarray, export_dir: Path):
        """Exporta Heightmap (16-bit), Lightmap (_C), texturas difusas e máscaras em PNG."""
        export_dir.mkdir(parents=True, exist_ok=True)
        print("\n" + "=" * 80)
        print(f"[*] EXPORTANDO TEXTURAS E MÁSCARAS EM PNG PARA: {export_dir.resolve()}")
        print("=" * 80)

        manifest = {
            "map_name": self.target_path.stem,
            "scale": terrain_info.get("scale"),
            "location": terrain_info.get("location"),
            "heightmap": "heightmap_16bit.png",
            "layers": []
        }

        # 1. Exporta Heightmap 16-bit
        if heights is not None:
            hm_path = export_dir / "heightmap_16bit.png"
            hm_img = Image.fromarray(heights.astype(np.uint16))
            hm_img.save(hm_path, format="PNG")
            print(f"  [PNG 16-BIT] Heightmap salvo em -> {hm_path.name}")

        # 2. Exporta Macro Lightmap (_C)
        raw_stem = self.target_path.stem.lower()
        clean_stem = raw_stem[2:] if raw_stem.startswith("t_") else raw_stem
        pkg_terrain = self.get_package(f"t_{clean_stem}") or self.get_package(clean_stem) or self.pkg
        
        if pkg_terrain:
            for exp in pkg_terrain.exports:
                if exp["object_name"].lower().endswith("_c") or exp["object_name"].lower() == f"{clean_stem}_c":
                    lm_img = pkg_terrain.extract_image_by_export_name(exp["object_name"])
                    if lm_img:
                        lm_path = export_dir / f"lightmap_{exp['object_name']}.png"
                        lm_img.save(lm_path, format="PNG")
                        manifest["lightmap"] = lm_path.name
                        print(f"  [PNG RGB]    Lightmap salvo em -> {lm_path.name} ({lm_img.size[0]}x{lm_img.size[1]})")
                        break

        # 3. Exporta Texturas e Máscaras de cada Camada
        layers = terrain_info.get("layers", [])
        for l in layers:
            idx = l["index"]
            t_ref = l.get("texture_ref")
            a_ref = l.get("alpha_ref")
            u_sc = l.get("u_scale", 1.0)
            v_sc = l.get("v_scale", 1.0)

            layer_info = {
                "index": idx,
                "u_scale": u_sc,
                "v_scale": v_sc,
                "texture_file": None,
                "mask_file": None
            }

            # Textura Difusa
            if isinstance(t_ref, dict) and "object_name" in t_ref:
                pkg_t = self.get_package(t_ref["package"]) or pkg_terrain or self.pkg
                t_img = pkg_t.extract_image_by_export_name(t_ref["object_name"])
                if t_img:
                    t_filename = f"layer_{idx}_tex_{t_ref['object_name']}.png"
                    t_path = export_dir / t_filename
                    t_img.save(t_path, format="PNG")
                    layer_info["texture_file"] = t_filename
                    print(f"  [PNG RGB]    Layer [{idx}] Textura : {t_filename} ({t_img.size[0]}x{t_img.size[1]})")

            # Máscara / AlphaMap
            if isinstance(a_ref, dict) and "object_name" in a_ref:
                pkg_a = self.get_package(a_ref["package"]) or pkg_terrain or self.pkg
                a_img = pkg_a.extract_image_by_export_name(a_ref["object_name"])
                if a_img:
                    a_gray = a_img.convert("L")
                    a_filename = f"layer_{idx}_mask_{a_ref['object_name']}.png"
                    a_path = export_dir / a_filename
                    a_gray.save(a_path, format="PNG")
                    layer_info["mask_file"] = a_filename
                    print(f"  [PNG L8]     Layer [{idx}] Máscara : {a_filename} ({a_gray.size[0]}x{a_gray.size[1]})")

            manifest["layers"].append(layer_info)

        # Salva o arquivo de receita JSON
        recipe_path = export_dir / "terrain_recipe.json"
        with open(recipe_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=4)
        print(f"\n  [JSON]       Receita do Terreno salva em -> {recipe_path.name}")
        print("=" * 80 + "\n")


# ==============================================================================
# 5. CONVERSÃO PARA MALHA 3D E EXPORTAÇÃO GLB PURO
# ==============================================================================
def build_terrain_mesh(heights: np.ndarray, scale: tuple, location: tuple, step: int = 1, center_mesh: bool = True):
    if step > 1: heights = heights[::step, ::step]
    rows, cols = heights.shape
    sx, sy, sz = float(scale[0]) * step, float(scale[1]) * step, float(scale[2])
    loc_x, loc_y, loc_z = float(location[0]), float(location[1]), float(location[2])

    if center_mesh:
        xs = (np.arange(cols, dtype=np.float32) - (cols / 2.0)) * sx
        zs = (np.arange(rows, dtype=np.float32) - (rows / 2.0)) * sy
    else:
        xs = loc_x + np.arange(cols, dtype=np.float32) * sx
        zs = loc_y + np.arange(rows, dtype=np.float32) * sy

    grid_x, grid_z = np.meshgrid(xs, zs)
    world_y = loc_z + (heights.astype(np.float32) - 32768.0) * (sz / 128.0)
    if center_mesh: world_y -= float(world_y.min())

    h_min, h_max = float(world_y.min()), float(world_y.max())
    print(f"[*] Altitude calculada: Min = {h_min:.1f} UU, Max = {h_max:.1f} UU (Desnível = {h_max - h_min:.1f} UU)")

    positions = np.stack([grid_x, world_y, grid_z], axis=-1).reshape(-1, 3).astype(np.float32)
    dz, dx = np.gradient(world_y, sy, sx)
    nx = -dx; ny = np.ones_like(world_y); nz = -dz
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    normals = np.stack([nx * inv_len, ny * inv_len, nz * inv_len], axis=-1).reshape(-1, 3).astype(np.float32)

    us = np.linspace(0.0, 1.0, cols, dtype=np.float32)
    vs = np.linspace(0.0, 1.0, rows, dtype=np.float32)
    gu, gv = np.meshgrid(us, vs)
    uvs = np.stack([gu, gv], axis=-1).reshape(-1, 2).astype(np.float32)

    row_indices = np.arange(rows - 1, dtype=np.uint32)
    col_indices = np.arange(cols - 1, dtype=np.uint32)
    rr, cc = np.meshgrid(row_indices, col_indices, indexing="ij")

    a = rr * cols + cc; b = a + 1; d = a + cols; e = d + 1
    triangle_a = np.stack([a, d, b], axis=-1).reshape(-1, 3)
    triangle_b = np.stack([b, d, e], axis=-1).reshape(-1, 3)
    triangles = np.concatenate([triangle_a, triangle_b], axis=0)

    return positions, normals, uvs, triangles


def write_glb(filepath: Path, name: str, positions: np.ndarray, normals: np.ndarray, uvs: np.ndarray, triangles: np.ndarray):
    position_data = np.ascontiguousarray(positions, dtype="<f4")
    normal_data = np.ascontiguousarray(normals, dtype="<f4")
    uv_data = np.ascontiguousarray(uvs, dtype="<f4")
    index_data = np.ascontiguousarray(triangles.reshape(-1), dtype="<u4")

    raw_buffers = [position_data.tobytes(), normal_data.tobytes(), uv_data.tobytes(), index_data.tobytes()]

    blobs = []; buffer_views = []; offset = 0
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
        "asset": {"version": "2.0", "generator": "l2_terrain_to_glb.py"},
        "scene": 0, "scenes": [{"nodes": [0], "name": name}], "nodes": [{"mesh": 0, "name": name}],
        "materials": [{"name": "TerrainHeightmapMaterial", "doubleSided": True, "pbrMetallicRoughness": pbr_config}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0, "mode": 4}]}],
        "buffers": [{"byteLength": len(binary_chunk)}],
        "bufferViews": buffer_views,
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": vertex_count, "type": "VEC3", "min": position_data.min(axis=0).tolist(), "max": position_data.max(axis=0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": vertex_count, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": vertex_count, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5125, "count": int(index_data.size), "type": "SCALAR"},
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


def main():
    parser = argparse.ArgumentParser(description="Extrai Heightmap (.glb) com relatório do UE2 e exporta texturas em PNG.")
    parser.add_argument("input", help="Caminho do arquivo .unr")
    parser.add_argument("--step", type=int, default=1, help="Downsample da malha (1 = total, 2 = metade)")
    parser.add_argument("--no-center", action="store_true", help="Mantém coordenadas absolutas de mundo")
    parser.add_argument("--output-dir", default=None, help="Diretório de saída para o GLB")
    parser.add_argument("--png", "--export-textures", dest="export_textures", action="store_true", 
                        help="Exporta todas as texturas, máscaras e heightmap em PNG na pasta do mapa")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.is_file(): sys.exit(f"[ERRO] Arquivo não encontrado: {input_path}")
    
    out_dir = Path(args.output_dir) if args.output_dir else input_path.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    start = time.time()

    print(f"\n================================================================================")
    print(f"[*] DECODIFICANDO MAPA: {input_path.name}")
    print(f"================================================================================\n")
    
    extractor = L2TerrainExtractor(input_path)
    extractor.print_dependencies()

    terrains = extractor.extract_terrain_infos(print_log=True)
    if not terrains:
        sys.exit("[!] Nenhum TerrainInfo encontrado no arquivo .unr.")

    t_info = terrains[0]
    
    heights = extractor.extract_exact_t00_heightmap(t_info)
    if heights is None:
        sys.exit("[!] Não foi possível decodificar o Heightmap G16 do terreno.")

    # Se a flag --png / --export-textures for acionada
    if args.export_textures:
        clean_stem = input_path.stem[2:] if input_path.stem.lower().startswith("t_") else input_path.stem
        export_folder = Path.cwd() / clean_stem
        extractor.export_all_textures_png(t_info, heights, export_folder)

    print("[*] CONSTRUINDO GEOMETRIA DO HEIGHTMAP...")
    positions, normals, uvs, triangles = build_terrain_mesh(
        heights, t_info.get("scale", (64.0, 64.0, 32.0)), t_info.get("location", (0.0, 0.0, 0.0)),
        step=args.step, center_mesh=not args.no_center
    )

    clean_stem = input_path.stem[2:] if input_path.stem.lower().startswith("t_") else input_path.stem
    out_glb = out_dir / f"{clean_stem}.glb"
    write_glb(out_glb, clean_stem, positions, normals, uvs, triangles)

    print(f"\n[OK] GLB da Malha (Heightmap Puro) gerado com sucesso: {out_glb.name} ({len(positions):,} vértices, {len(triangles):,} faces)")
    print(f"[Local]: {out_glb}")
    print(f"[*] Processamento concluído em {time.time() - start:.2f}s")


if __name__ == "__main__":
    main()