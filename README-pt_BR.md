# NyxHUD

HUD modular para compositores Wayland compatíveis com `wlr-layer-shell`.

Não é um framework de widgets, um sistema de plugins nem um daemon
monolítico: são dois programas independentes que se comunicam apenas
por arquivos de texto publicados em um diretório privado. Cada coletor
executa, publica exatamente um bloco e termina; o renderizador lê os
blocos e desenha. Nenhuma das partes conhece a implementação da outra.

![NyxHUD](screenshots/desktop.png)

## Arquitetura

```text
        ┌──────────────┐
        │  Collectors  │   executam, publicam e terminam
        └──────────────┘
                │  publicação atômica
                ▼
   $XDG_RUNTIME_DIR/nyxhud/render/*.render
                │
                ▼
        ┌──────────────┐
        │   Renderer   │   apenas desenha
        └──────────────┘
```

O fluxo é unidirecional. Coletores não conversam entre si e o
renderizador nunca os executa. Entre coletores e renderizador não existe
protocolo próprio de comunicação, RPC, D-Bus nem biblioteca
compartilhada — a única interface pública do projeto é o conjunto de
arquivos `.render`.

## Por que arquivos?

Usar arquivos de texto como interface reduz o acoplamento entre
componentes e dispensa protocolos internos, APIs e bibliotecas
compartilhadas. Também permite:

- inspecionar qualquer bloco com `cat`, `less` ou `tail`;
- implementar coletores em qualquer linguagem;
- substituir ou reiniciar módulos individualmente;
- depurar cada componente de forma isolada;
- publicar de forma atômica por `rename()`.

Para o renderizador, um bloco publicado é apenas texto. Sua origem é
irrelevante.

## Recursos

- Wayland nativo via `wlr-layer-shell`
- Coletores desacoplados, sem plugins e sem dependência entre módulos
- Publicação atômica por `rename()`
- Diretórios privados em `0700`, `umask 077`
- Estado temporário em `tmpfs`; só o cache de mercados é persistente
- Configuração por variáveis de ambiente, sem arquivo de configuração
- Shell POSIX, testado sob `dash`
- Falha local nunca interrompe os demais módulos

## Instalação

Exige um compositor que implemente `wlr-layer-shell`: sway, labwc,
river, Hyprland ou Wayfire. GNOME Shell não é suportado.

```sh
git clone https://github.com/fm4lloc/nyxhud.git
cd nyxhud
./start.sh
```

`start.sh` sobe o renderizador, o gerenciador de coletores e prepara o
ambiente em `$XDG_RUNTIME_DIR`.

## Dependências

Obrigatórias: Python 3, PyGObject, GTK 3, gtk-layer-shell (biblioteca
e typelib), `/bin/sh` POSIX, coreutils, awk e uma fonte monoespaçada
com os caracteres `U+2588` e `U+2591` — por padrão `Iosevka Term`.

Opcionais, usadas por um coletor cada:

| Ferramenta | Coletor |
|---|---|
| `iproute2` | rede |
| `lm_sensors` | temperatura |
| `nvidia-utils` | GPU NVIDIA |
| `firejail` | sandbox |
| `curl` e `jq` | mercados |

Ausente a ferramenta, apenas o coletor correspondente informa o
problema na tela. Os demais seguem normalmente.

### Fonte padrão

O renderizador usa **Iosevka Term 12** por padrão. Ela foi escolhida
pela legibilidade em corpo pequeno, pelo alinhamento monoespaçado
consistente e por cobrir os caracteres de bloco que o HUD desenha:
`U+2588` (`█`) e `U+2591` (`░`).

- GitHub: <https://github.com/be5invis/Iosevka>
- Site: <https://typeof.net/Iosevka/>

Qualquer fonte monoespaçada que contenha esses caracteres pode ser
utilizada.

Para alterar a fonte padrão do renderizador, edite a definição em
`main/nyx-renderer.py`:

```python
FONT = os.environ.get("NYXHUD_FONT", "Iosevka Term 12")
```

## Módulos

Os blocos aparecem na ordem do nome do arquivo do coletor: renumerar
um arquivo reordena o HUD, sem mais nada a alterar.

| Arquivo | Descrição |
|---|---|
| `01_system.sh` | kernel, hostname, horário, uptime, carga, memória, swap, partições, temperatura e processo com maior consumo de CPU |
| `02_gpu.sh` | modelo NVIDIA, temperatura, utilização, VRAM, velocidade da ventoinha e consumo |
| `03_network.sh` | interface padrão, endereço IPv4, gateway, download e upload |
| `04_wireguard.sh` | estado do túnel, interface e taxa de transferência |
| `05_sandbox.sh` | sandboxes Firejail em execução |
| `06_markets.sh` | BTC, ETH e SOL em USD e em moeda local |
| `07_diskio.sh` | leitura, escrita e ocupação por dispositivo |

Para desativar um módulo, remova a permissão de execução:

```sh
chmod -x main/collectors/06_markets.sh
```

O supervisor percebe a mudança no ciclo seguinte e retira o bloco da
tela. Nenhum outro arquivo precisa mudar e nada precisa ser
reiniciado.

## Configuração

Sem arquivo de configuração. Tudo é variável de ambiente, lida apenas
na inicialização — alterar qualquer valor exige reiniciar o NyxHUD.

| Variável | Padrão | Descrição |
|---|---|---|
| `NYXHUD_FONT` | `Iosevka Term 12` | fonte do renderizador |
| `NYXHUD_TEXT_COLOR` | `#E0E0E0` | cor do texto |
| `NYXHUD_TITLE_COLOR` | `#1793D1` | cor dos títulos |
| `NYXHUD_ANCHOR` | `bottom-left` | canto da tela |
| `NYXHUD_MARGIN` | `40` | margem externa |
| `NYXHUD_PADDING` | `24` | espaçamento interno |
| `NYXHUD_OUTPUT` | automático | conector do monitor, ex. `DP-1` |
| `NYXHUD_TTL` | `15` | validade de um bloco, em segundos |
| `NYXHUD_TIMEOUT` | `10` | tempo máximo de execução de um coletor |
| `NYXHUD_RUNTIME_DIR` | `$XDG_RUNTIME_DIR/nyxhud` | diretório de execução, caminho absoluto |
| `NYXHUD_CACHE_DIR` | `$XDG_CACHE_HOME/nyxhud` | cache persistente, caminho absoluto |
| `NYXHUD_MARKETS` | `on` | qualquer outro valor desliga o coletor de mercados |
| `NYXHUD_MARKETS_REFRESH` | `14400` | intervalo entre consultas à API |
| `NYXHUD_MARKETS_FIAT` | `brl` | moeda local, três letras |
| `NYXHUD_SANDBOX_MAX` | `8` | máximo de sandboxes exibidas |
| `NYXHUD_DISK_RE` | ver abaixo | regex dos dispositivos monitorados |

Padrão de `NYXHUD_DISK_RE`, cobrindo SATA, NVMe, eMMC, virtio, Xen, MD
e device-mapper:

```text
^(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+|vd[a-z]+|xvd[a-z]+|md[0-9]+|dm-[0-9]+)$
```

```sh
NYXHUD_FONT="JetBrains Mono 11" \
NYXHUD_TITLE_COLOR="#8EC07C" \
NYXHUD_ANCHOR=top-right \
NYXHUD_OUTPUT=DP-1 \
./start.sh
```

## Validade dos blocos

Publicar é o único sinal de vida. O renderizador exibe um bloco
enquanto sua idade for menor que `NYXHUD_TTL` e o oculta quando o
coletor para de publicar.

Mantenha `INTERVAL ≤ NYXHUD_TTL / 2` para que cada bloco seja
republicado ao menos duas vezes antes de expirar; acima disso ele
pisca.

## Acesso à rede

Todos os coletores usam apenas `/proc`, `/sys` e ferramentas locais,
com uma exceção: `06_markets.sh` consulta a API pública da CoinGecko a
cada quatro horas, expondo o endereço IP e o horário da requisição.

```sh
NYXHUD_MARKETS=off ./start.sh
```

## Modelo de segurança

- publicação atômica: temporário no diretório de destino, seguido de
  `rename()`
- diretórios privados em `0700` e `umask 077` em todos os componentes
- remoção de caracteres de controle na publicação e novamente na
  leitura
- recusa de links simbólicos nos diretórios de execução e `O_NOFOLLOW`
  na leitura dos blocos
- instância única por lock directory, com recuperação de lock obsoleto
- `timeout` por coletor: um módulo travado não interrompe os demais
- renderizador e coletores isolados, sem interface além dos arquivos

## Criando um módulo

Um coletor é um executável que escreve um bloco e termina. A primeira
linha é o título.

```sh
#!/bin/sh

INTERVAL=5

set -u
set -f
LC_ALL=C
export LC_ALL
umask 077

NAME=battery

: "${NYXHUD_RENDER_DIR:?}"

publish() {
    tmp=$(mktemp "$NYXHUD_RENDER_DIR/.$NAME.XXXXXX") || exit 1

    trap 'rm -f -- "$tmp"' EXIT INT TERM

    if tr -d '\000-\010\013-\037\177' > "$tmp"; then
        mv -- "$tmp" "$NYXHUD_RENDER_DIR/$NAME.render"
    fi
}

read -r LEVEL < /sys/class/power_supply/BAT0/capacity

{
    printf 'BATTERY\n'
    printf 'Level       %s%%\n' "$LEVEL"
} | publish
```

Salve como `main/collectors/NN_nome.sh` e dê permissão de execução. O
supervisor detecta arquivos criados, removidos, renumerados ou com a
permissão alterada no ciclo seguinte — não há registro e não é preciso
reiniciar. Alterar o `INTERVAL` de um módulo já carregado é a única
mudança que exige reinício.

Trate o `.render` publicado como imutável: nunca edite o arquivo no
lugar, sempre escreva um novo temporário e substitua o anterior com
`rename()`.

Convenções dos módulos oficiais:

- publique com `mktemp` no diretório de destino e `mv` sobre o alvo;
- remova caracteres de controle antes de publicar;
- valide inteiros antes da expansão aritmética — sob `dash`, `$(( ))`
  com operando não numérico aborta o script;
- use `/proc/uptime` para cálculo de taxa, nunca `date +%s`;
- nunca escreva no arquivo publicado por outro coletor.

## Estrutura

```text
.
├── main
│   ├── collectors
│   │   ├── 01_system.sh
│   │   ├── 02_gpu.sh
│   │   ├── 03_network.sh
│   │   ├── 04_wireguard.sh
│   │   ├── 05_sandbox.sh
│   │   ├── 06_markets.sh
│   │   └── 07_diskio.sh
│   ├── nyx-collectord.sh
│   └── nyx-renderer.py
└── start.sh
```

## Limitações

Exige um compositor com `wlr-layer-shell`; GNOME Shell e ambientes sem
o protocolo não são suportados, assim como renderização remota. O
projeto também assume um sistema de arquivos em que `rename()` dentro
do mesmo diretório é atômico.

O campo de maior consumo de CPU exibe `idle` na primeira leitura após
a inicialização, por depender de duas amostras.

O coletor de GPU cobre apenas adaptadores NVIDIA e reporta somente o
primeiro adaptador retornado por `nvidia-smi`; o de WireGuard, apenas a
primeira interface detectada. As taxas de rede e de disco são exibidas
em bytes por segundo, e o campo `busy` do disco é a fração do tempo em
que o dispositivo teve E/S em voo, não a utilização da sua capacidade.

`NYXHUD_TIMEOUT` só é aplicado quando `timeout(1)` está instalado; sem
ele os coletores executam sem limite e o supervisor avisa na
inicialização. `NYXHUD_OUTPUT` depende de como o compositor identifica
o monitor, o que varia entre implementações. O parser do
`05_sandbox.sh` acompanha o formato textual de `firejail --list`, que
já mudou entre versões.

## Licença

GPL-3.0-or-later. Consulte `LICENSE`.