# BRutus — Testing Notes

_Last updated: 2026-04-26_

---

## Como Testar Manualmente

### Setup básico
1. Instalar o addon em `Interface/AddOns/BRutus/`
2. Entrar no WoW com um personagem que está em uma guild
3. Ter pelo menos um outro jogador online com BRutus instalado (para testar sync)

### Reload rápido
```
/reload
```
Após qualquer alteração de código, `/reload` recarrega o addon sem reiniciar o jogo.

---

## Cenários de Teste por Feature

### Roster
```
1. /brutus → janela abre
2. Membros aparecem com nome, classe, nível, ilvl
3. Colunas são clicáveis (sort por coluna)
4. Botão Online/Offline filtra corretamente
5. Hover em membro mostra tooltip
6. Click em membro abre MemberDetail
7. Stats bar mostra total, online, addon-users
```

### Sync de Dados
```
1. /brutus sync → broadcast manual
2. Outros membros BRutus recebem seus dados (verificar com /brutus na outra conta)
3. Dados de gear/profs aparecem no roster do outro jogador
4. Após /reload, dados persistem (SavedVariables ok)
```

### Atunamentos
```
1. Abrir MemberDetail de um membro atunado
2. Verificar que atunamentos aparecem na lista
3. Para conta-wide: linkar um alt via MemberDetail → atunamentos do alt aparecem no main
```

### Raid Tracking
```
1. Entrar em uma instance de raid (ex: Karazhan)
2. Aguardar snapshot automático (ou disparar com mechânica de boss)
3. Sair da instance após >10min
4. Verificar aba Raids: sessão aparece com dados
```

### Consumable Checker (requer ser RL/Assist em raid)
```
1. Estar em raid como RL ou assist
2. HUD de cooldowns deve aparecer se habilitado
3. /brutus → Raids tab → botão de check consumíveis
4. Popup mostra quem tem e quem não tem consumíveis
```

### Master Looter (requer ser ML em raid)
```
1. Estar em raid como Master Looter
2. Abrir loot de um boss
3. Loot frame do BRutus aparece com itens Rare+
4. Clicar item → anúncio no raid com roll ou wishlist
5. Roll termina → vencedor anunciado
6. /brutus → Loot tab → item aparece no histórico
```

### Receitas
```
1. Abrir uma trade skill (ex: Blacksmithing)
2. BRutus escaneia automaticamente após 5s
3. /brutus → Recipes tab (se existir) → receitas aparecem
4. Outro membro com BRutus → suas receitas também aparecem após sync
```

### Trials (officer only)
```
1. Ser oficial de guild
2. /brutus → Trials tab
3. Adicionar um trial member
4. Outro oficial com BRutus recebe o trial após sync
```

---

## Comandos Slash Úteis para Debug

| Comando | O que testa |
|---|---|
| `/brutus` | Toggle roster window |
| `/brutus scan` | Re-coleta dados locais, verifica DataCollector |
| `/brutus sync` | Broadcast manual, verifica CommSystem |
| `/brutus reset` | Limpa SavedVariables — use para testar DB fresh |
| `/reload` | Recarrega addon — verifica persistência |
| `/script BRutus.Logger.debug = true` | Ativa logs de debug |
| `/script BRutus.LootMaster.testMode = true` | Testa LootMaster sem estar em raid |
| `/script print(BRutus.VERSION)` | Verifica versão carregada |

---

## Validações Antes de Empacotar

### Luacheck (obrigatório)
```powershell
C:\Users\danie\bin\luacheck.exe . --config .luacheckrc
```
**Deve retornar**: `0 warnings / 0 errors`

### Checklist Manual
- [ ] `/reload` sem erros Lua no chat
- [ ] `/brutus` abre a janela do roster
- [ ] Roster lista membros sem erros
- [ ] Clicar em membro abre MemberDetail sem erros
- [ ] `/brutus sync` envia sem erros
- [ ] Tabs de features (Raids, Loot) abrem sem erros
- [ ] Configurações (Settings tab) carregam sem erros
- [ ] BRutus.db não está vazio após reload (persistência ok)
- [ ] Sem taint warnings em combate

---

## Bugs Conhecidos e Pendências

| Bug/Pendência | Severidade | Módulo | Status |
|---|---|---|---|
| `GetLootMethod()` retorna nil | Workaround implementado em `LootMaster:IsMasterLooter()` | LootMaster | ✅ Mitigado |
| `welcomedRecently` cresce sem ser limpo | Baixo (só em sessão) | RecruitmentSystem | ⚠️ Pendente |
| CommSystem ticker sem referência para Cancel | Baixo risco de duplicata | CommSystem | ⚠️ Pendente |
| Magic strings WL/LP/ON/RC/TR não em MSG_TYPES | Médio — manutenção | CommSystem | 🔲 Fase 3 |
| UI/MemberDetail escreve altLinks direto | Baixo — funcional mas acoplado | MemberDetail | 🔲 Fase 2 |
| lootMaster.awardHistory sem limite | Baixo (cresce devagar) | LootMaster | 🔲 Fase 2 |
| raidTracker.sessions sem limite | Baixo | RaidTracker | 🔲 Fase 2 |

---

## TestMode do LootMaster

```lua
-- Ativar no console para testar sem estar em raid:
/script BRutus.State.lootMaster.testMode = true

-- Verificar estado:
/script print(BRutus.State.lootMaster.testMode)

-- Desativar:
/script BRutus.State.lootMaster.testMode = false
```

Com testMode ativo:
- `IsMasterLooter()` retorna true mesmo fora de raid
- Chat/addon messages são printados localmente em vez de enviados

---

## Verificar Dados Salvos (Debug)

```lua
-- Ver estrutura do DB atual:
/script local k,v=next(BRutusDB); print(k, type(v))

-- Ver membros armazenados:
/script local c=0; for k,_ in pairs(BRutus.db.members or {}) do c=c+1 end; print("Members:", c)

-- Ver raids armazenadas:
/script print("Sessions:", #(BRutus.db.raidTracker and BRutus.db.raidTracker.sessions or {}))

-- Ver pendingMessages:
/script local c=0; for _ in pairs(BRutus.State.comm.pendingMessages) do c=c+1 end; print("Pending:", c)
```
