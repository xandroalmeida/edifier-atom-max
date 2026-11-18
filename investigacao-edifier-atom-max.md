# Investigação do EDIFIER Atom Max no macOS

Data: 18/11/2026

## Resultado confirmado

Foi possível consultar, desligar e religar o cancelamento ativo de ruído (ANC) do EDIFIER Atom Max diretamente pelo Mac, usando Bluetooth Low Energy (BLE). Cada alteração bem-sucedida foi confirmada por uma consulta independente ao fone. O estado final confirmado foi ANC ligado, igual ao estado inicial.

A confirmação é do estado informado pelo firmware; não foi realizada medição acústica.

## Identificação do equipamento

- Nome USB e Bluetooth: EDIFIER Atom Max.
- Fabricante USB: EDIFIER Technology.
- Número de série USB: omitido da versão pública.
- VID/PID USB: 0x2D99 / 0xE064.
- Revisão USB do produto: 0x0100; não equivale à versão do firmware.
- Velocidade USB observada: 12 Mb/s.
- Firmware informado pelo macOS na conexão Bluetooth: 2.4.0.
- Endereço Bluetooth clássico: omitido da versão pública.
- Endpoint de controle BLE anunciado: EDIFIER BLE.
- Identificador CoreBluetooth: específico de cada Mac; deve ser descoberto localmente, sem endereço fixo no código.
- Serviço de controle BLE: 48091f01-1a48-11e9-ab14-d663bd873d93.
- Característica de notificações: 48090001-1a48-11e9-ab14-d663bd873d93 (READ | NOTIFY).
- Característica de escrita: 48090002-1a48-11e9-ab14-d663bd873d93 (WRITE | WRITE_WITHOUT_RESPONSE).

O Mac reconheceu os perfis HFP, AVRCP, A2DP e HID. O fone estava selecionado como entrada e saída padrão, com saída estéreo a 44.100 Hz e entrada mono a 16.000 Hz no momento da consulta. Isso não significa que esses formatos permaneçam simultaneamente ativos em todos os cenários de uso.

## Projetos analisados

1. https://github.com/estevao-tarifa/edifier-macos
   - A ferramenta foi compilada localmente com Cargo, sem instalar aplicativo ou serviço de inicialização.
   - Os oito testes do pacote edifier-proto passaram.
   - O transporte BLE encontrou e conectou o endpoint, mas o protocolo original do projeto (AA | tamanho de 1 byte | comando | checksum de 2 bytes com base 0x2019) não recebeu respostas às consultas CC e C9 no Atom Max.
   - O projeto original não foi confirmado como compatível com o Atom Max sem adaptação.
2. https://github.com/wh201906/mEDIFIER
   - Consultado como fonte do transporte e protocolo que deram origem ao projeto anterior.
3. https://github.com/silverpoetry/HyperEars
   - A documentação docs/edifier-bes-protocol.md descreve uma variante mais recente da família Edifier/BES, usada como base para adaptar a comunicação.
   - A documentação cita modelos diferentes. Os resultados abaixo foram confirmados especificamente neste Atom Max; não presumir compatibilidade integral com outros aparelhos.

## Protocolo confirmado no Atom Max

Formato enviado:

    AA EC CMD LEN_H LEN_L PAYLOAD... CHECKSUM

Formato recebido nos testes:

    BB EC CMD LEN_H LEN_L PAYLOAD... CHECKSUM

- LEN é o tamanho do payload, em dois bytes big-endian; não inclui CMD nem checksum.
- CHECKSUM é a soma de todos os bytes anteriores do frame, módulo 256.
- Os payloads observados neste Atom Max estavam em texto/bytes claros. Não aplicar XOR 0xA5, embora outras variantes descritas pelo HyperEars usem essa transformação.
- Habilitar notificações na característica de leitura antes de enviar consultas pela característica de escrita.
- A adaptação usou escrita com resposta.
- Acumular notificações até completar LEN + 6 bytes e validar o checksum antes de interpretar.
- Manter somente uma transação em andamento e espaçar os pedidos. Após um timeout na primeira tentativa de restauração, foi introduzido intervalo de 350 ms antes dos pedidos; a nova tentativa confirmou a restauração. Não foi comprovado que o intervalo fosse a causa da diferença.

### Consultar nome (CMD C9)

    TX: AA EC C9 00 00 5F
    RX: BB EC C9 00 10 45 44 49 46 49 45 52 20 41 74 6F 6D 20 4D 61 78 6F

O payload de 16 bytes é EDIFIER Atom Max. A ferramenta adaptada exigia essa identificação antes de permitir alterações.

### Consultar ANC (CMD CC)

    TX: AA EC CC 00 00 62
    RX com ANC ligado:    BB EC CC 00 03 10 01 07 8E
    RX com ANC desligado: BB EC CC 00 03 10 05 07 92

Payload observado: 10 MODE 07.

- 0x10 identifica o grupo/slot de ANC nesta variante.
- 0x01 foi usado para ANC ligado.
- 0x05 foi usado para ANC desligado.
- O terceiro byte permaneceu 0x07; seu significado não foi confirmado.
- Outros níveis, modo ambiente e seus códigos não foram testados neste Atom Max.

### Desligar ANC (CMD C1)

    TX: AA EC C1 00 02 10 05 6E
    RX: BB EC C1 00 03 10 05 07 87

Uma consulta CC posterior confirmou 10 05 07.

### Ligar ANC (CMD C1)

    TX: AA EC C1 00 02 10 01 6A
    RX: BB EC C1 00 03 10 01 07 83

Uma consulta CC posterior confirmou 10 01 07.

### Outras consultas que receberam resposta

Bateria (CMD D0):

    TX: AA EC D0 00 00 66
    RX: BB EC D0 00 01 35 AD

Payload 0x35, consistente com 53% sob a interpretação percentual direta; não houve comparação com o aplicativo oficial.

Capacidades (CMD D8):

    TX: AA EC D8 00 00 6E
    RX: BB EC D8 00 15 01 01 01 05 01 01 01 01 00 01 01 01 20 18 01 00 2A 70 00 10 00 86

O bitmap não foi decodificado nem usado para prometer suporte a outros ajustes.

## Sequência real do teste

1. Consultado o nome e confirmado EDIFIER Atom Max.
2. Consultado ANC: 10 01 07.
3. Enviado desligamento e confirmado por resposta C1 e nova consulta CC: 10 05 07.
4. A primeira tentativa de religar expirou sem resposta. Nova conexão e consulta mostraram que o modo ainda era 10 05 07.
5. Reenviado o comando de ligar em nova conexão, com espaçamento entre pedidos.
6. Recebida resposta C1 e confirmada por nova consulta CC: 10 01 07.
7. Encerrado o canal de controle; o último estado confirmado foi ANC ligado.

## Como reproduzir futuramente

Implementar um cliente BLE que descubra EDIFIER BLE e o serviço 48091f01, conecte, assine as notificações e envie os frames acima. O projeto edifier-macos pode fornecer o transporte, mas seu encoder/decoder original deve ser adaptado para este formato. O exemplo temporário criado na investigação oferecia status, on, off e test, validava nome/checksum, consultava o estado após escrever e tentava restaurar o original em caso de erro.

Apenas o arquivo deste relatório será preservado; o código adaptado e os executáveis temporários serão removidos conforme solicitado. Os frames e detalhes necessários para reconstruir o cliente estão documentados aqui.

## USB e controles comuns

Por USB, foram observadas interfaces de áudio e comandos multimídia, sem um comando de ANC identificado nessa interface. Isso não prova impossibilidade absoluta de controlar ANC via USB.

O manual informa que o cabo USB-C permite áudio e carregamento, desativando o Bluetooth no uso cabeado. Referências oficiais:

- https://edifierbr.com.br/wp-content/uploads/2025/01/Atom_Max_Manual.pdf
- https://edifier.com.br/fone-com-cancelamento-de-ruido-e-hi-res-atom-max-edifier.html

## Arquivos e limpeza

O trabalho foi realizado em três diretórios temporários, removidos ao encerrar:

- /private/tmp/edifier-macos-investigation
- /private/tmp/hyperears-investigation
- /private/tmp/medifier-investigation

Não foram alterados outros projetos durante a investigação. Não foram instalados aplicativos, itens de login ou ferramentas no PATH. Cargo baixou dependências para seu cache habitual; caches compartilhados não fazem parte das pastas da investigação e não foram removidos.
