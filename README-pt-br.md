# NyxHud

HUD minimalista para ambientes Linux/X11.

![NyxHud](screenshots/desktop.png)

## Recursos

* Leve
* Coletores modulares
* Pipeline de telemetria baseado em shell
* Renderizador em Python
* Sem telemetria
* Sem serviços em nuvem
* Baixo consumo de recursos

## Arquitetura

```text
Coletores
    ↓
nyx-collectord.sh
    ↓
Renderizador
    ↓
Overlay X11
```

## Fonte

O NyxHud foi projetado em torno da **Iosevka Term**, priorizando espaçamento compacto, alta legibilidade e renderização orientada para terminais.

Recomendado:

```text
Iosevka Term 12
```

Recursos oficiais:

* https://typeof.net/Iosevka/
* https://github.com/be5invis/Iosevka

## Transparência

O NyxHud oferece suporte à transparência através de compositores X11, como o **picom**.

Para evitar sombras na janela do HUD, adicione a seguinte regra ao seu `picom.conf`:

```conf
shadow-exclude = [
    "name = 'nyxhud'"
];
```
```sh
sudo pacman -S picom
```

Inicie o compositor:

```sh
picom --backend glx &
```

## Dependências

Arch Linux:

```sh
sudo pacman -S \
    bash \
    coreutils \
    gawk \
    grep \
    sed \
    procps-ng \
    iproute2 \
    curl \
    jq \
    python \
    python-gobject \
    gtk3
```

Opcionais:

```sh
sudo pacman -S \
    picom \
    lm_sensors \
    wireguard-tools \
    nvidia-utils \
    firejail
```

## Instalação

```sh
git clone https://github.com/fm4lloc/nyxhud.git
cd nyxhud

find src -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
```

## Execução

```sh
./src/start.sh
```

## Licença

GPL-3.0-or-later

## Autor

Fernando Magalhães
