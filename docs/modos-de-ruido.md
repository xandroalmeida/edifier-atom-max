# Modos de ruído — Atom Control 0.2.0

O app oferece quatro opções exclusivas no menu nativo:

| Opção | Payload de C1 | Frame enviado |
| --- | --- | --- |
| ANC forte | `10 01` | `AA EC C1 00 02 10 01 6A` |
| ANC fraco | `10 02` | `AA EC C1 00 02 10 02 6B` |
| Som ambiente | `10 04` | `AA EC C1 00 02 10 04 6D` |
| Desativado | `10 05` | `AA EC C1 00 02 10 05 6E` |

## Evidência

A investigação anterior nesta pasta confirmou no Atom Max o grupo ANC `0x10`, os códigos `1`/`5` e o protocolo em texto claro. A documentação [Edifier BES do HyperEars](https://github.com/silverpoetry/HyperEars/blob/main/docs/edifier-bes-protocol.md), consultada em 18/11/2026, registra para o W860NB PRO o mesmo grupo com `1=Deep NC`, `2=Comfort NC`, `3=Wind`, `4=Ambient`, `5=Off`.

A inclusão de `2` e `4` no Atom Max é uma inferência dessa tabela, compatível com a informação do usuário de que seu fone tem ANC forte, fraco e ambiente. Ainda não há captura física desses dois códigos neste Atom Max. O código `3` não é usado como ANC fraco: a fonte o identifica como redução de vento, que não foi solicitada. A variante `0x1B`, com outros códigos, não é aplicada.

## Confirmação

Após C1, o app aguarda a resposta e envia CC (`AA EC CC 00 00 62`). Apenas o modo devolvido por CC é selecionado no menu. Se o firmware responder outro modo, o app mostra o modo efetivo e uma mensagem de alteração não confirmada. Se não houver resposta, o estado fica desconhecido e é necessário reconectar; não há repetição cega da escrita.

Os testes de fraco/ambiente usam frames derivados da tabela e checksums calculados; não são capturas de hardware. A confirmação de intensidade e de transparência requer ouvir o fone e comparar com o aplicativo oficial no celular.
