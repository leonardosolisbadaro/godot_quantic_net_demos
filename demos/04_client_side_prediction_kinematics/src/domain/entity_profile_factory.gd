## @file entity_profile_factory.gd
## @path res://src/domain/entity_profile_factory.gd
##
## @description
## Factory de domínio responsável por ditar as regras de negócio de Tráfego
## de Rede, encapsulando a criação de perfis QNEntityProfile otimizados.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
class_name EntityProfileFactory
extends RefCounted


## Cria o perfil para um Jogador: Alta frequência (60Hz) e Prioridade Máxima
func create_player_profile() -> QNEntityProfile:
	var profile = QNEntityProfile.new()
	profile.init(60.0, 1.0, 20.0)
	return profile


## Cria o perfil genérico para um Prop (cenário): Baixa frequência (5Hz) e Baixa Prioridade
func create_prop_profile() -> QNEntityProfile:
	var profile = QNEntityProfile.new()
	profile.init(5.0, 0.5, 20.0)
	return profile
