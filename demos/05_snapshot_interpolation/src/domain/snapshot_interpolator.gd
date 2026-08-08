## @file snapshot_interpolator.gd
## @path res://src/domain/snapshot_interpolator.gd
##
## @description
## Entidade de domínio matemático puramente dedicada ao lerping de posições
## baseado em peso/delta, isolando essa lógica dos visualizadores (Nodes).
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name SnapshotInterpolator
extends RefCounted

## Interpola entre o vetor atual e o alvo baseado em um peso de 0.0 a 1.0
static func interpolate(current_pos: Vector3, target_pos: Vector3, weight: float) -> Vector3:
	var clamped_weight = clamp(weight, 0.0, 1.0)
	return current_pos.lerp(target_pos, clamped_weight)
