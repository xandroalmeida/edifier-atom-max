# Atom Control

<img src="Resources/AtomControl-icon.png" width="128" alt="Ícone do Atom Control: fone prateado com onda sonora ciano">

Controle de ANC do **EDIFIER Atom Max** na barra de menus do macOS. Swift, AppKit e CoreBluetooth, sem dependências externas. O menu é desenhado pelo próprio sistema: acompanha aparência clara/escura, tipografia, seleção, teclado e acessibilidade do macOS.

## Abrir

Compile o projeto seguindo as instruções abaixo e abra **dist/Atom Control.app** pelo Finder. O app aparece como um ícone de fone na barra superior, sem janela principal e sem ícone no Dock. Os executáveis e caches de compilação não fazem parte do repositório.

1. Ligue o Atom Max e mantenha o Bluetooth do Mac ativado.
2. Permita o acesso ao Bluetooth solicitado pelo Atom Control.
3. Clique no ícone de fone e escolha **ANC forte**, **ANC fraco**, **Som ambiente** ou **Desativado**.

O marcador de seleção representa o estado informado pelo firmware. Após uma alteração, o app faz uma consulta independente antes de marcar a opção. O app não altera o ANC ao iniciar ou ao encerrar. A conexão de áudio continua sendo gerenciada nos ajustes de Bluetooth/Som do Mac.

Use **Iniciar com o Mac** no menu para ativar ou desativar a abertura na sessão. O app usa `SMAppService.mainApp`, o mecanismo nativo do macOS 13 ou posterior. Se o sistema exigir autorização, a opção fica com um traço e aparece um atalho para **Itens de Início**. A seleção reflete o estado do sistema, inclusive mudanças feitas nos Ajustes. Mantenha o app em um local fixo, preferencialmente Aplicativos, antes de ativar.

## Ícone e informações

O símbolo na barra acompanha o modo confirmado: forma de onda cortada para ANC forte, traço de onda para ANC fraco, orelha para som ambiente e fone para controle desativado. Durante uma mudança ainda não confirmada, aparece uma reticência. Um fone esmaecido indica desconexão; uma interrogação indica um modo que o app não reconheceu. O texto ao passar o cursor e a descrição do VoiceOver informam o estado por extenso.

O submenu **Sobre o fone** mostra modelo, estado da conexão de controle, modo, bateria, firmware e versão do app. A versão de firmware é consultada pelo comando de leitura C6 na primeira abertura do submenu em cada conexão. Se não houver resposta em cinco segundos ou o formato for desconhecido, aparece **Não informado** e o ANC continua disponível. O app não apresenta a versão histórica da investigação como se fosse uma leitura atual.

O ícone do aplicativo foi criado com o gerador de imagens integrado e está em `Resources/AtomControl-icon.png`; a versão para Finder e outros elementos do sistema é `Resources/AtomControl.icns`. O build gera os dez tamanhos padrão do macOS com `sips` e `iconutil`. A origem e o prompt estão em [docs/icone.md](docs/icone.md). A barra de menus usa os símbolos nativos de estado, preservando legibilidade em tamanhos pequenos.

## Compilar e testar

Requer macOS 13 ou posterior e Xcode Command Line Tools com Swift. O script compila para a arquitetura do Mac atual, otimiza o executável e assina o bundle localmente.

```sh
zsh scripts/test.sh
zsh scripts/build.sh
open "dist/Atom Control.app"
```

Não há instalação de serviços, downloads de dependências ou necessidade de privilégios de administrador. A compilação usa `.build/` como cache local. `dist/` contém o app pronto.

## Gerar um instalador

```sh
zsh scripts/package.sh
```

Gera `dist/Atom-Control-<versão>-<arquitetura>.pkg` e um checksum SHA-256. O pacote instala o app em **/Applications/Atom Control.app**, sem scripts de instalação ou ativação automática de itens de início. O build é específico para a arquitetura do Mac que o gerou; `arm64` atende aos Macs com chips Apple M1 ou posteriores. Requer macOS 13 ou posterior.

Para instalar, encerre qualquer versão aberta do Atom Control, abra o `.pkg` no Finder e siga o instalador do macOS. Depois abra **Atom Control** em Aplicativos e permita Bluetooth se solicitado. A opção **Iniciar com o Mac** deve ser ativada a partir dessa cópia instalada. O instalador pode solicitar autenticação de administrador para gravar em Aplicativos.

Este é um pacote para instalação local, sem assinatura Developer ID nem notarização da Apple; o app tem assinatura ad hoc. A geração extrai o payload final, verifica o caminho de instalação, a assinatura do app e a igualdade do executável com o build original.

## Comportamento e consumo

- Um único processo nativo, sem WebView, Electron ou SwiftUI.
- Sem rede, telemetria ou consultas periódicas ao fone.
- Varredura BLE limitada a 12 segundos; conexão/descoberta limitada a 15 segundos.
- Atualização ao abrir o menu, limitada a uma consulta a cada 5 segundos, e por notificações do fone quando disponíveis.
- Comandos serializados, com pelo menos 350 ms entre envios e tempo limite de resposta de 5 segundos.
- Conexão de controle mantida enquanto disponível; liberada no repouso e retomada ao despertar.
- Reconexão automática após falhas, com intervalos de 5, 15, 30, 60, 120 e depois 300 segundos entre as tentativas. Só há uma tentativa agendada; não há varredura contínua. O menu informa o horário da próxima tentativa.
- As tentativas param com Bluetooth desligado, permissão negada, repouso ou encerramento do app. Acordar o Mac, reativar o Bluetooth ou conectar manualmente reinicia o intervalo. Uma conexão completa bem-sucedida também reinicia o intervalo.
- Só o identificador BLE de um Atom Max validado é salvo nas preferências locais para acelerar a próxima conexão.
- Nenhum serviço ou item de início é instalado automaticamente.

## Solução de problemas

**Permissão negada:** abra **Ajustes do Sistema → Privacidade e Segurança → Bluetooth** e permita Atom Control. O menu oferece um atalho quando a permissão está negada.

**Fone não encontrado ou sem resposta:** feche o Edifier ConneX no Mac/celular para liberar uma possível conexão de controle, aproxime o fone e use **Conectar ao fone** novamente. Se necessário, desligue e religue o fone. Uma tentativa com identificador antigo que falhar permite nova descoberta na próxima tentativa.

**USB:** o manual informa que o Atom Max desativa o Bluetooth no uso com cabo USB-C. Este aplicativo usa BLE e precisa da função Bluetooth do fone disponível.

**Outro modo ativo:** se o fone informar um código diferente dos quatro modos implementados, nenhuma opção é marcada. O app sempre compara o estado retornado pelo fone com o modo escolhido e informa se a mudança não foi confirmada.

Os eventos de conexão e mensagens de estado aparecem no Console do macOS, no subsistema `br.com.local.AtomControl`.

## Protocolo e validação

A implementação usa os frames e UUIDs registrados em [investigacao-edifier-atom-max.md](investigacao-edifier-atom-max.md). Antes de qualquer alteração, confirma o nome `EDIFIER Atom Max`. Valida checksum, comprimento, fragmentação e comando de cada resposta. Os testes usam as capturas reais documentadas nessa investigação.

Os testes automatizados verificam a codificação dos comandos, a leitura de respostas fragmentadas/concatenadas, a rejeição de checksum incorreto, a recuperação após dados inválidos e o tratamento de estados desconhecidos. Eles não substituem a validação da conexão e da interface no Mac com o fone.

Também verificam o limite e reinício dos intervalos de reconexão, a suspensão das tentativas, ícones distintos e ausência de modos antigos após desconexão, além dos formatos de firmware. O comando opcional C6 e a apresentação de três bytes como versão hexadecimal seguem [mEDIFIER](https://github.com/wh201906/mEDIFIER/blob/master/Qt/devices/basedevice.cpp); sua resposta neste Atom Max ainda depende de validação física. O cadastro real de início de sessão depende da autorização do macOS e de uma assinatura aceita pelo sistema; falhas são exibidas, sem marcar a opção como ativada.

O firmware do Atom Max não tem uma API pública documentada. As capturas locais do firmware 2.4.0 confirmam ANC ligado (`0x01`), desligado (`0x05`), consulta de nome e bateria. Os modos adicionais seguem a [documentação do protocolo BES/ANC16 do HyperEars](https://github.com/silverpoetry/HyperEars/blob/main/docs/edifier-bes-protocol.md): forte `0x01`, confortável/fraco `0x02`, ambiente `0x04`, desligado `0x05`. A correspondência de fraco e ambiente é uma inferência da mesma família de protocolo; ainda precisa de validação física neste Atom Max. O app preserva o transporte em texto claro e o grupo `0x10` confirmados localmente, e exige consulta independente após toda seleção. Não envia comandos de atualização, redefinição ou mudança de pareamento.
