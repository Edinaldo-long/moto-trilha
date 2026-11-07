# PLANO DE IMPLEMENTAÇÃO: GAME FEEL & MECÂNICAS DE ADRENALINA
**Projeto:** Moto Trilha (Flutter + Flame)  
**Versão:** 1.0  
**Perfil:** Game Designer & Gameplay Engineer Sênior  
**Documento de Origem:** `.specs/GAMEPLAY_SPEC.md`  

---

## 1. Diagnóstico do Estado Atual & Filosofia de Game Feel ("Juice")

### 1.1 Diagnóstico Técnico do Projeto Atual
A inspeção da base de código (`lib/main.dart`, ~1718 linhas) revela uma base sólida de física 2D customizada (modelo de molas e amortecedores nas duas rodas, suporte avançado a gamepads com calibração e geração procedural de terreno). Contudo, a experiência de pilotagem atual apresenta limitações cruciais de *Game Feel*:
1. **Suspensão Rígida Visualmente:** A física calcula a penetração das rodas, mas o desenho (`_drawBike`) utiliza coordenadas estáticas (`±32, 14`). O chassi não "afunda", a balança traseira e garfo dianteiro não comprimem visualmente, eliminando a sensação de peso e absorção de impacto.
2. **Câmera Estática e Shake Linear:** O zoom é estritamente geométrico (`size.y / 650`), sem resposta a velocidade ou altitude. O tremor de tela usa decaimento linear com ruído aleatório uniforme simples, sem direção de impacto nem micro-pausas (*hitstop/freeze-frame*).
3. **Partículas Rudimentares:** Apenas partículas circulares de poeira cinza/bege com baixa expressividade. Não há diferenciação de derrapagem (*skid/burnout*), faíscas ao raspar em pedras, choque de aterrissagem ou rastros de velocidade.
4. **Sistema de Risco/Recompensa Embrionário:** Apenas giros completos no ar (*flips*) concedem moedas. Não há detecção contínua de *wheelie* (grau), *stoppie* (empinar de frente), aterrissagens perfeitas, nem barra de adrenalina e mecânica de *turbo/nitro*.
5. **Arquitetura Monolítica:** Todo o jogo, física, partículas, HUD e menus estão em `lib/main.dart`, tornando arriscada a injeção contínua de novos subsistemas sem uma estruturação modular limpa.

### 1.2 Filosofia de Adrenalina: O Ciclo de Ação-Reação
O objetivo é transformar o jogo de uma simulação simples de obstáculos para uma experiência visceral de pilotagem de trilha extrema, baseada em 3 leis de Game Feel:
* **Peso e Elasticidade:** O jogador precisa sentir o peso da moto ao acelerar (compressão traseira / *squat*), ao frear (mergulho dianteiro / *dive*) e ao aterrissar (esmagamento elástico e recuperação amortecida).
* **Feedback de Impacto ("Juice"):** Cada colisão relevante deve entregar som/imagem correspondente com *Trauma-based screen shake* e *hitstop* de dezenas de milissegundos para congelar a tensão.
* **Tensão e Risco Dinâmico:** Andar no limite (grau em alta velocidade, passar raspando em pedras, aterrissar no ângulo exato do declive) alimenta instantaneamente o medidor de Adrenalina, permitindo acionar o **Turbo** para alcançar velocidades insanas.

---

## 2. Pilares de Engenharia & Game Design

```
+-----------------------------------------------------------------------------------+
|                           GAME FEEL & ADRENALINE LOOP                             |
+-----------------------------------------------------------------------------------+
|  [Manobras & Risco]        [Física & Visual]         [Impacto & Efeitos]          |
|  - Wheelie (Grau)    ===>  - Suspensão Dinâmica ===> - Camera Trauma & Shake     |
|  - Stoppie (RL)            - Postura do Piloto       - Speedlines & Zoom Dinâmico |
|  - Flips & Big Air         - Compressão de Chassi    - Roost, Sparks & Burnout    |
+-----------------------------------------------------------------------------------+
                                      ||
                                      \/
                     [BARRA DE ADRENALINA & COMBO]
                                      ||
                                      \/
                      [TURBO BOOST / SPRINT EXTREMO]
```

---

## 3. Especificação Detalhada por Módulo

### Módulo A: Suspensão Reativa & Cinemática da Moto
* **Objetivo:** Dar massa, flexibilidade mecânica e postura reativa ao conjunto moto-piloto.
* **Componentes de Engenharia:**
  1. **Deslocamento Dinâmico dos Eixos:**
     * Modelar a compressão independente da suspensão traseira ($d_{rear} \in [0, 14\text{px}]$) e dianteira ($d_{front} \in [0, 14\text{px}]$) baseada na força normal $f_n$ e velocidade de aproximação.
     * Amortecimento viscoelástico visual (mola secundária com resposta rápida e retorno amortecido para evitar sensação de borracha mole).
  2. **Pitch / Squat & Dive Dinâmico:**
     * Aceleração forte: o garfo dianteiro distende suavemente, a suspensão traseira afunda proporcionalmente ao torque do motor.
     * Frenagem brusca: afundamento do garfo dianteiro (compressão da suspensão da frente) e alívio da traseira.
  3. **Cinemática do Piloto (Ragdoll Procedural Leve):**
     * O tronco e braços do piloto ajustam seus ângulos em tempo real:
       * Inclinado para frente na aceleração e subidas íngremes.
       * Jogando o quadril para trás ao empinar ou amortecer aterrissagens violentas (joelhos flexionam visualmente no pouso).

### Módulo B: Câmera Dinâmica, Trauma Shake & Hitstop
* **Objetivo:** Transmitir sensação cinética de velocidade, altura e choque.
* **Componentes de Engenharia:**
  1. **Sistema de Trauma-based Shake (Padrão Eiserloh):**
     * A câmera possui uma variável contínua `trauma` $\in [0.0, 1.0]$.
     * Força do tremor: $\text{Shake} = \text{trauma}^2$ (sensação não-linear; pequenos solavancos tremem suavemente, grandes impactos explodem o feedback).
     * Tremor baseado em ruído direcional suave (deslocamento $X, Y$ + rotação angular de inclinação $\theta_{shake} \in [-3^\circ, 3^\circ]$) em vez de ruído branco de alta frequência.
  2. **Zoom Dinâmico (Speed & Altitude Cam):**
     * $Zoom_{target} = Zoom_{base} \times (1.0 - \text{clamp}(v_x / 1200, 0, 0.25) + \text{clamp}(airTime \times 0.05, 0, 0.15))$.
     * À medida que a moto atinge velocidades acima de 80 km/h ou ganha grande altitude, a câmera afasta (aumentando o campo de visão à frente).
     * No momento do pouso ou ativação de Turbo: **Punch Zoom** (micro contração e expansão elástica de 5% no zoom).
  3. **Hitstop / Micro-Freeze (Pausa Tátil):**
     * Em impactos de alta energia (quedas verticais de $v_y > 450$ px/s ou finalização de manobra complexa): pausar o avanço de tempo da física por $30\text{ms}$ a $50\text{ms}$.
     * Essa fração de segundo cria o clássico efeito de impacto cinemático (comum em jogos como *Smash Bros* e *Trials HD*).

### Módulo C: Partículas de Terreno, Trilha & Adrenalina
* **Objetivo:** Fazer o terreno reagir organicamente à potência e tração do pneu.
* **Componentes de Engenharia:**
  1. **Roost Conical Emitter (Terra / Cascalho Espirrando):**
     * Emitido na roda traseira quando há contato e aceleração ativa.
     * Partículas com velocidade vetorial orientada oposta ao avanço e dispersão cônica, herdando a cor exata do topo do solo do bioma atual (`lv.dirtLight` e `lv.dirtTop`).
  2. **Burnout & Skid Smoke (Fumaça de Pneu):**
     * Ativado quando a velocidade angular da roda excede a velocidade de deslocamento no solo (derrapagem/patinada) ou em frenagens com derrapagem. Fumaça cinza translúcida que se expande radialmente antes de sumir.
  3. **Scrape Sparks (Faíscas de Atrito):**
     * Quando o ângulo da moto ou o chassi raspa no terreno/lombadas com $v_x > 200$, disparar faíscas brilhantes amarelas/laranjas em arco rasante.
  4. **Landing Dust Shockwave (Impacto no Solo):**
     * No pouso de saltos, disparar uma onda bilateral de poeira para a esquerda e direita de cada roda que toca o chão.
  5. **Speedlines (Linhas de Velocidade Periféricas):**
     * Renderização direta no Canvas de traços radiais semitransparentes nos cantos da tela ao ultrapassar velocidades críticas ou em modo Turbo.
  6. **Sistema de Pooling de Partículas:**
     * Gerenciar as instâncias de partículas em fila pré-alocada para zerar sobrecarga de Garbage Collector no Flutter/Flame.

### Módulo D: Manobras, Combos & Turbo Boost
* **Objetivo:** Criar o loop viciante de risco vs. recompensa e dar ao jogador agência para correr mais rápido.
* **Componentes de Engenharia:**
  1. **Detector de Manobras em Tempo Real:**
     * **Wheelie (Grau):** Apenas roda traseira no chão (`contacts == 1 && rearInContact`), ângulo $\theta \ge 20^\circ$, mantido por $> 0.35\text{s}$. Incrementa pontos de adrenalina por segundo.
     * **Stoppie (RL / Endo):** Apenas roda dianteira no chão (`contacts == 1 && frontInContact`), desaceleração ativa ou ângulo invertido por $> 0.30\text{s}$.
     * **Air Tricks (Flips & Air Time):** Detecção contínua de rotações de $360^\circ$ (Backflip e Frontflip) combinada com tempo de vôo livre (*Big Air*).
     * **Aterrissagem Perfeita (Clean Landing):** Aterrissar com ângulo de chassi alinhado com a inclinação do terreno ($\Delta \theta \le 12^\circ$) sem bater a traseira ou frente bruscamente: recompensa com bônus instantâneo de velocidade e adrenalina.
  2. **Multiplicador e Janela de Combo:**
     * Conectar manobras em uma janela de tempo de $1.8\text{s}$.
     * Multiplicadores progressivos ($x1.2, x1.5, x2.0, x3.0$).
     * Tipografia flutuante dinâmica no HUD ("WHEELIE x2!", "CLEAN LANDING!", "SICK FLIP!").
  3. **Barra de Adrenalina & Mecânica de Turbo (Nitro):**
     * Barra de Adrenalina com capacidade de 0 a 100%, carregada exclusivamente por manobras arriscadas e velocidade contínua.
     * Acionamento de **TURBO BOOST**:
       * Botão dedicado na tela de toque, teclado (`Shift` ou `Barra de Espaço`) e gamepad (Gatilho `RT`, bumper `RB` ou botão `B`).
       * Efeito do Turbo: Aumento de tração $+40\%$, velocidade máxima elevada temporariamente de 680 para 950 px/s.
       * Feedback do Turbo: Chamas/plasma azul saindo do escapamento, distorção de câmera, vibração intensa e *speedlines* saturadas.

---

## 4. Plano de Implementação em 5 Etapas Estruturadas

Para manter o jogo sempre testável, estável e garantir validação a cada marco, dividimos a execução em **5 etapas consecutivas**:

```
+------------------------------------------------------------------------------------+
|                               ETAPAS DE IMPLEMENTAÇÃO                              |
+------------------------------------------------------------------------------------+
| [ETAPA 1] Refatoração Modular & Estrutura de Código                                |
|           Separar o monolito de 1718 linhas em módulos organizados e limpos.       |
|                                                                                    |
| [ETAPA 2] Suspensão Reativa & Cinemática Visual da Moto                            |
|           Molas dinâmicas nas rodas, chassi que afunda e postura do piloto.        |
|                                                                                    |
| [ETAPA 3] Câmera Cinética: Trauma Shake, Zoom Dinâmico & Hitstop                   |
|           Tremor direcional não-linear, zoom por velocidade e micro-pausa de salto.|
|                                                                                    |
| [ETAPA 4] Sistema de Partículas e Efeitos de Terreno                               |
|           Roost cônico, burnout, faíscas de chassi, choque de pouso e speedlines.  |
|                                                                                    |
| [ETAPA 5] Adrenalina, Detecção de Manobras (Grau/Flips) & Sistema de Turbo         |
|           Detecção de wheelie/stoppie, medidor de nitro, botão de boost e HUD.     |
+------------------------------------------------------------------------------------+
```

### Detalhamento das Etapas:

#### ETAPA 1: Refatoração Modular & Arquitetura Segura
* **Objetivo:** Isolar as responsabilidades do arquivo `main.dart` sem alterar o comportamento do jogo já existente.
* **Tarefas Técnicas:**
  * Criar estrutura de diretórios em `lib/`:
    * `lib/models/` (modelos de terreno, níveis, moedas, combustível).
    * `lib/physics/` (cálculo de forças, contatos, molas e sub-stepping).
    * `lib/entities/` (renderização e estado da moto, piloto e ragdoll).
    * `lib/effects/` (câmera, shake e partículas).
    * `lib/ui/` (overlays, menu, calibração de controle e HUD).
  * Manter `lib/main.dart` enxuto, orquestrando apenas a inicialização do app e os overlays.
* **Entregável / Validação:** Jogo compilando e rodando exatamente como antes, mas com código limpo e extensível.

#### ETAPA 2: Suspensão Reativa & Cinemática Visual da Moto
* **Objetivo:** Integrar visualmente a compressão de amortecedores e postura do piloto.
* **Tarefas Técnicas:**
  * Implementar variáveis de estado de suspensão `suspensionRear` e `suspensionFront` com amortecimento viscoelástico.
  * Atualizar o renderizador `_drawBike` para calcular as posições dos cubos de roda e braços da balança/garfo em função da compressão calculada.
  * Adicionar inclinação e flexão articular nos pontos de articulação do piloto (quadril, ombro, joelho) para reagir à inércia de aceleração, frenagem e choque de pouso.
* **Entregável / Validação:** Visualização clara da moto agachando ao acelerar, mergulhando na freada e amassando a suspensão ao absorver lombadas e saltos.

#### ETAPA 3: Câmera Cinética (Trauma Shake, Zoom Dinâmico & Hitstop)
* **Objetivo:** Ampliar dramaticamente a sensação de velocidade e a intensidade dos impactos.
* **Tarefas Técnicas:**
  * Implementar classe `DynamicCamera` com modelo de `trauma` cúbico/quadrático e decaimento contínuo.
  * Injetar rotação de câmera proporcional ao shake para que impactos inclinados façam a tela inclinar levemente.
  * Adicionar algoritmo de zoom dinâmico interpolado ($Zoom(v_x, airTime)$) e micro-efeito de *punch zoom*.
  * Implementar micro-pausa de física (`hitstopTimer`, 30 a 50ms) acionada em aterrissagens violentas e colisões.
* **Entregável / Validação:** A sensação de velocidade é reforçada pelo campo de visão expandido, e aterrissagens fortes geram solavancos com autoridade física.

#### ETAPA 4: Partículas de Terreno, Trilha e Velocidade
* **Objetivo:** Terreno visualmente vivo e reativo à tração do motor.
* **Tarefas Técnicas:**
  * Criar classe modular `ParticleSystem` com pool de objetos.
  * Adicionar emissor de terra (*roost*) na roda traseira que intensifica quando o pneu perde tração ou acelera com força.
  * Adicionar partículas de faíscas ao raspar chassi em pedras/terreno.
  * Adicionar fumaça de derrapagem ao frear forte em alta velocidade.
  * Implementar linhas de velocidade periféricas (*speedlines*) translúcidas desenhadas no Canvas em velocidade de ponta.
* **Entregável / Validação:** Efeitos visuais ricos e sem qualquer queda de framerate (mantendo 60fps constantes).

#### ETAPA 5: Adrenalina, Manobras (Grau/Flips) e Turbo Boost
* **Objetivo:** O clímax do Game Feel — premiar a pilotagem arriscada com supervelocidade.
* **Tarefas Técnicas:**
  * Implementar analisador de postura da moto para detecção contínua de:
    * *Wheelie* (grau na traseira com ângulo e tempo mínimo).
    * *Stoppie* (empinada na dianteira sob frenagem controlada).
    * *Flips* múltiplos e *Air Time* prolongado.
    * *Clean Landing* (pouso perfeito alinhado ao terreno).
  * Implementar medidor de Adrenalina e multiplicador de combo temporizado.
  * Adicionar mecânica de ativação de **Turbo Boost** (botão de toque adicional, tecla dedicada e botão de controle), com aceleração extrema e rastro de partículas de turbo no escapamento.
  * Adicionar textos flutuantes de impacto e barra de adrenalina estilizada no HUD.
* **Entregável / Validação:** O jogador ganha novo objetivo mecânico: mandar manobras para encher a barra de Adrenalina e disparar o Turbo para bater recordes.

---

## 5. Parâmetros de Balanceamento e Fórmulas de Engenharia

| Subsistema | Parâmetro | Valor Recomendado | Efeito no Jogo |
| :--- | :--- | :--- | :--- |
| **Suspensão** | Curso da Suspensão | `12.0 px` | Limite estético para evitar rodas invadindo o motor |
| **Suspensão** | Retorno Visual (Damping) | `18.0` | Velocidade com que a suspensão volta à posição de repouso |
| **Câmera** | Expoente de Trauma | `2.0` (Quadrático) | $\text{shake} = \text{trauma}^2 \times 16\text{px}$ |
| **Câmera** | Decaimento de Trauma | `1.4 / s` | Retorno ágil da câmera ao equilíbrio |
| **Câmera** | Hitstop em Aterrissagem | `0.040 s (40ms)` | Pausa de impacto nos saltos com $v_y > 450$ px/s |
| **Manobras** | Ângulo Mínimo Grau (Wheelie) | `22^\circ` | Evita falso positivo em pequenas oscilações de relevo |
| **Manobras** | Janela de Combo | `1.8 s` | Tempo para encadear a próxima manobra |
| **Turbo** | Ganho de Velocidade Máxima | `+40%` ($680 \to 950$ px/s) | Sensação drástica de arrancada e adrenalina |
| **Turbo** | Consumo de Adrenalina | `30% / s` | Turbo dura aproximadamente 3.3 segundos se cheio |

---

## 6. Critérios de Sucesso e Validação

1. **Testes de Usabilidade e Resposta:**
   * Nenhum comando de controle/teclado sofre perda de responsividade.
   * A moto mantém estabilidade de rolagem nas curvas sem capotagens artificiais.
2. **Avaliação do Game Feel:**
   * A compressão mecânica é claramente legível mesmo a 60 fps.
   * O impacto ao saltar de grandes alturas transmite peso convincente.
   * O Turbo passa sensação clara de risco (alta velocidade exige reflexos rápidos nas lombadas).
3. **Desempenho Técnico:**
   * Taxa de quadros estável em 60 fps (Android/Desktop/Web).
   * Alocação controlada de objetos em runtime através de *pools* de partículas.

---

## 7. Próximo Passo Recomendado
Apresentar este plano para validação do usuário. Após a aprovação, iniciar pontualmente pela **ETAPA 1 (Refatoração Modular)** ou pela etapa prioritária que o usuário preferir.
