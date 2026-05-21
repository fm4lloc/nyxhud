# NyxHud

HUD minimalista, modular e de baixo consumo para Linux focado em desempenho,
auditabilidade e filosofia Unix.

NyxHud é um overlay desktop baseado em coletores, projetado para ambientes
Linux/X11 utilizando uma arquitetura shell-first com pipeline de renderização
separado.

O projeto prioriza:

* simplicidade
* modularidade
* baixo overhead
* portabilidade
* transparência
* código inspecionável
* manutenção de longo prazo

---

# Filosofia

NyxHud segue uma filosofia estritamente orientada à engenharia.

Princípios centrais:

* Offline-first
* Coletores modulares
* Arquitetura shell-first com foco em POSIX
* Renderer separado dos coletores
* Quantidade mínima de dependências
* Workflow focado em X11
* Compatibilidade com desktops hardened
* Auditabilidade acima de abstração
* Filosofia de pipeline Unix
* Licenciamento copyleft (GPLv3-or-later)

O projeto evita intencionalmente:

* Electron
* runtimes baseados em navegador
* dependência de cloud
* telemetria
* frameworks desktop monolíticos
* abstrações desnecessárias
* sistemas pesados de widgets
* daemons excessivos

NyxHud é intencionalmente opinativo.

O projeto prioriza:

* clareza de engenharia
* comportamento determinístico
* controle de baixo nível
* manutenção

em vez de:

* excesso visual
* complexidade de frameworks
* feature bloat

---

# Não Objetivos

NyxHud intencionalmente não busca fornecer:

* um desktop environment completo
* um framework de widgets
* suporte Wayland-first
* gerenciamento integrado de pacotes
* sincronização em cloud
* plataformas de telemetria
* camadas de sandbox/plugins
* extensibilidade estilo Electron

---

# Arquitetura

NyxHud utiliza uma arquitetura baseada em pipeline dividido.

```text
Coletores (Shell/POSIX)
        ↓
nyx-collectord.sh
        ↓
Renderer (Python)
        ↓
Janela overlay X11
```

Essa separação mantém o projeto:

* modular
* substituível
* portátil
* mais fácil de depurar
* mais fácil de auditar

Os coletores obtêm os dados.

O renderer manipula apenas a visualização.

O renderer permanece intencionalmente stateless em relação à lógica dos coletores.

---

# Estrutura do Projeto

```text
nyxhud/
├── LICENSE
├── README.md
├── README-pt-br.md
└── src
    ├── main
    │   ├── collectors
    │   │   ├── 01_system.sh
    │   │   ├── 02_gpu.sh
    │   │   ├── 03_network.sh
    │   │   ├── 04_wireguard.sh
    │   │   ├── 05_sandbox.sh
    │   │   ├── 06_markets.sh
    │   │   └── 07_diskio.sh
    │   ├── nyx-collectord.sh
    │   └── nyx-renderer.py
    └── start.sh
```

---

# Componentes Principais

## Collectors

Collectors são módulos shell independentes responsáveis por coletar
informações do sistema.

Exemplos:

```text
collectors/
├── 01_cpu.sh
├── 02_gpu.sh
├── 03_memory.sh
├── 04_network.sh
├── 05_wireguard.sh
├── 06_sandbox.sh
├── 07_markets.sh
├── 08_battery.sh
├── 09_diskio.sh
└── 10_weather.sh
```

Collectors devem:

* fazer apenas uma coisa
* permanecer simples
* evitar efeitos colaterais
* evitar dependências desnecessárias
* gerar saída estruturada
* permanecer facilmente auditáveis

Collectors são intencionalmente orientados a shell.

O projeto favorece:

* POSIX shell
* awk
* sed
* grep
* coreutils

em vez de grandes runtimes.

---

## Collectord

`nyx-collectord.sh` atua como camada de orquestração.

Responsabilidades:

* agendamento
* execução dos coletores
* sincronização
* formatação
* cache
* coordenação do pipeline

O collectord evita intencionalmente:

* bancos de dados
* sistemas complexos de IPC
* schedulers com muitas dependências
* serviços ocultos em background

Collectors degradam graciosamente quando dependências opcionais não estão disponíveis.

---

## Renderer

O renderer é implementado em Python e atua estritamente como camada
de visualização.

Responsabilidades:

* desenho do overlay
* manipulação de transparência
* interação com compositor
* posicionamento
* renderização
* composição visual

O renderer permanece intencionalmente stateless em relação à lógica dos coletores.

Essa separação permite:

* substituição do renderer
* experimentos futuros
* depuração mais simples
* arquitetura mais limpa

---

# Transparência e Composição

NyxHud suporta transparência utilizando compositores X11 leves.

Compositor recomendado:

* picom (backend GLX)

Para renderização correta da transparência e exclusão de sombra da janela `nyxhud`, configure o `picom`:

```sh
mkdir -p ~/.config/picom/
touch ~/.config/picom/picom.conf
nano ~/.config/picom/picom.conf
```

Adicionar:

```conf
shadow-exclude = [
    "name = 'nyxhud'"
];
```

Inicializar com:

```sh
picom --backend glx &
```

Isso evita artefatos de sombra e permite transparência adequada no HUD.

---

NyxHud funciona melhor com:

* wallpapers pretos opacos
* composição mínima
* desktops leves
* ambientes X11 minimalistas

---

# Dependências

## Dependências Principais

Arch Linux:

```bash
sudo pacman -S \
    bash \
    coreutils \
    grep \
    sed \
    gawk \
    procps-ng \
    iproute2 \
    curl \
    jq \
    python \
    python-gobject \
    gtk3
```

# Font

Fonte primária recomendada:

```text
Iosevka Term 12
```

Recursos oficiais:

* [Iosevka Website](https://typeof.net/Iosevka/)
* [Iosevka GitHub Repository](https://github.com/be5invis/Iosevka)

Características recomendadas:

* fonte monoespaçada
* métricas compactas
* renderização orientada a terminal
* baixo ruído visual
* alta legibilidade em fundos escuros

Variantes Nerd Font são opcionais e não são necessárias.


## Dependências Opcionais

Pacotes opcionais utilizados por collectors específicos:

```bash
sudo pacman -S \
    picom \
    lm_sensors \
    wireguard-tools \
    nvidia-utils \
    firejail
```

| Pacote          | Finalidade                       | Módulo    |
| --------------- | -------------------------------- | --------- |
| picom           | Transparência/composição         | renderer  |
| lm_sensors      | Telemetria de temperatura da CPU | system    |
| wireguard-tools | Telemetria WireGuard             | wireguard |
| nvidia-utils    | Telemetria NVIDIA (`nvidia-smi`) | gpu       |
| firejail        | Telemetria de sandbox/isolamento | sandbox   |

---

# Instalação

Clonar o repositório:

```bash
git clone https://github.com/fm4lloc/nyxhud.git
cd nyxhud
```

Tornar os arquivos executáveis:

```bash
chmod +x ./src/*.sh
chmod +x ./src/main/*.sh
chmod +x ./src/main/*.py
chmod +x ./src/main/collectors/*.sh
```

---

# Execução

Iniciar o NyxHud:

```bash
./src/start.sh
```

---

# Compatibilidade POSIX

NyxHud prioriza compatibilidade POSIX sempre que possível.

Objetivos:

* evitar bashisms desnecessários
* preservar portabilidade
* manter collectors inspecionáveis
* reduzir inflação de dependências
* manter comportamento previsível
* preservar portabilidade shell sempre que razoável

Comportamentos não POSIX devem permanecer isolados e justificados.

---

# Performance

NyxHud foi projetado para minimizar:

* wakeups
* uso de CPU
* overhead de memória
* polling desnecessário
* complexidade de runtime

Collectors devem:

* cachear operações caras
* evitar loops infinitos
* evitar subprocessos excessivos
* evitar camadas desnecessárias de parsing

O projeto favorece:

* atualizações determinísticas
* renderização de baixa latência
* workflows desktop leves

---

# Filosofia de Segurança

NyxHud segue um modelo de engenharia defensiva.

Princípios:

* sem telemetria
* sem networking oculto
* sem APIs cloud por padrão
* dependências explícitas
* collectors auditáveis
* fluxo de execução previsível

O projeto foi projetado para integrar bem com:

* kernels hardened
* ambientes sandboxed
* desktops X11 minimalistas
* sistemas Linux focados em segurança

---

# Compatibilidade Desktop

Foco principal:

* X11
* desktops Linux leves
* workflows orientados a Unix

Ambientes alvo:

* BSPWM
* Openbox
* XFCE4
* i3
* DWM
* AwesomeWM

---

# Configuração

NyxHud atualmente segue uma estrutura autocontida.

Configuração e customização são realizadas diretamente através de:

* collectors
* lógica do renderer
* scripts de inicialização

Isso simplifica:

* deployment
* debugging
* auditoria
* portabilidade

O projeto evita intencionalmente:

* camadas complexas de configuração
* frameworks de plugins
* loaders runtime pesados

---

# Customização

Customizações podem ser realizadas através de:

* shell collectors
* parâmetros do renderer
* configurações do compositor
* scripts de inicialização

Modificações comuns:

* transparência
* posicionamento do overlay
* intervalos de collectors
* formatação de texto
* visuais do renderer

---

# Screenshots

![screen1](screenshots/desktop.png)

---

# Código Aberto

NyxHud é licenciado sob:

```text
GPL-3.0-or-later
```

Isso garante:

* forks permanecem open source
* modificações continuam auditáveis
* trabalhos derivados preservam liberdade de software

---

# Autores

## Fernando Magalhães

[fm4lloc@gmail.com](mailto:fm4lloc@gmail.com)
[nyx-eco@proton.me](mailto:nyx-eco@proton.me)

Criador, mantenedor e desenvolvedor principal.

---

## Nyx

Colaboração técnica, revisão de arquitetura
e assistência em engenharia de sistemas.

---

# Contribuição

Contribuições são bem-vindas desde que estejam alinhadas com a filosofia do projeto.

Contribuições preferenciais:

* melhorias de performance
* otimização de collectors
* melhorias de portabilidade
* limpeza do renderer
* tooling X11
* simplificação shell

Evitar:

* abstrações desnecessárias
* inflação de dependências
* reescritas baseadas em frameworks
* redesigns monolíticos

---

# Ecossistema

Componentes planejados:

```text
NyxHud
NyxBar
NyxCollectord
```

Objetivos futuros:

* melhor abstração de renderer
* melhor sistema de cache
* experimentos leves com IPC
* tooling adicional para X11
* utilitários desktop modulares

---

# Notas Finais

NyxHud não pretende se tornar um desktop environment completo.

O projeto é focado em:

* overlays leves
* pipelines modulares de informação
* integração desktop de baixo nível
* workflows orientados a Unix
* manutenção de longo prazo

Simplicidade é tratada como funcionalidade, não como limitação.
