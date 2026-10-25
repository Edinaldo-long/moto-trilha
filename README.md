# 🏍️ Moto Trilha

Jogo de moto em trilha feito com **Flutter + Flame**. Acelere por terrenos cheios de morros e pedras, junte moedas, pegue combustível, faça **flips** no ar e complete as 5 fases!

## ✨ Recursos

- 5 fases com cenários e dificuldade crescentes
- Física própria da moto: suspensão, empinar, abaixar a frente e giros no ar
- Moedas, galões de combustível e bônus por **flips**
- Recorde e fases liberadas salvos no aparelho
- Controles por **teclado**, **gamepad** (com tela para configurar os botões) e **toque**
- Piloto arremessado na queda, poeira, tremor de tela e HUD com indicador de comandos

## 🗺️ Fases

| Fase | Cenário | Meta |
|---|---|---|
| 1 | Campo Verde | 300 m |
| 2 | Deserto | 450 m |
| 3 | Entardecer | 600 m |
| 4 | Montanha Gelada | 800 m |
| 5 | Vulcão | 1000 m |

Ao chegar na meta, a próxima fase é liberada. Se você cair ou ficar sem combustível, a fase recomeça. As moedas coletadas continuam contando.

## 🎮 Controles

### Teclado

| Ação | Tecla |
|---|---|
| Acelerar | `→` ou `D` |
| Frear | `←` ou `A` |
| Empinar | `↑` ou `W` |
| Abaixar a frente | `↓` ou `S` |
| Começar / jogar de novo | `Enter` ou `Espaço` |

### Controle (gamepad)

Clique em **CONFIGURAR CONTROLE** no menu e aperte, na ordem, o botão (ou a direção) que você quer para **acelerar**, **frear**, **empinar** e **abaixar a frente**. A configuração fica salva. Funciona também com controles genéricos de botões numerados.

Padrão para controles reconhecidos: `A` / `RT` acelera, `B` / `LT` frea, `X` / `L1` / D-pad ↑ empina, `Y` / `R1` / D-pad ↓ abaixa a frente.

O botão escolhido para **acelerar** também inicia e reinicia o jogo. Durante a partida, as caixinhas **ACEL / FREIO / EMP / ABX** acendem para você conferir se o comando chegou.

### Toque

Botões na tela: giro para trás e para a frente (esquerda), freio e acelerador (direita).

## 🛠️ Como rodar

**Requisitos:** [Flutter](https://docs.flutter.dev/get-started/install) instalado.

```bash
git clone https://github.com/Edinaldo-long/moto-trilha.git
cd moto-trilha
flutter pub get
flutter run
```

Para escolher a plataforma, use por exemplo `flutter run -d windows` ou `flutter run -d chrome`.

### Dependências

```bash
flutter pub add flame shared_preferences gamepads
```

- [`flame`](https://pub.dev/packages/flame): motor do jogo
- [`shared_preferences`](https://pub.dev/packages/shared_preferences): salva recorde, moedas e fases liberadas
- [`gamepads`](https://pub.dev/packages/gamepads): leitura de controles

> **Android:** o pacote `gamepads` exige um `MainActivity` que repassa os eventos do controle. O exemplo está no README do pacote.

## 🧩 Estrutura

Todo o jogo está em um único arquivo, `lib/main.dart`:

- **Modelos:** terreno infinito, moedas, galões, partículas e `LevelDef` (definição das fases)
- **`TrailGame`:** física da moto, entradas, geração do mundo, câmera e desenho
- **Telas:** menu, fim de jogo, fase concluída e botões de toque

## ⚙️ Ajustes rápidos

- **Dificuldade das fases:** edite a lista `kLevels` (meta, altura dos morros, quantidade de pedras, distância entre galões e consumo de combustível).
- **Suspensão:** na função `_step`, a linha `final cc = vn < 0 ? c : 400.0;` controla o quanto a moto quica (valor maior = menos quique).
- **Força da inclinação:** a variável `lean`, também em `_step`.

## 🩺 Problemas comuns

- **O controle não responde:** rode com `flutter run` e veja no console as linhas `RAW ...`, que mostram o nome de cada botão. Refaça **CONFIGURAR CONTROLE** e confira a linha "Último sinal recebido".
- **Empinar e abaixar parecem invertidos no analógico:** troque o sinal do eixo vertical (`_ay`) na função `_applyPad`.


