# Revisão para repositório privado — 2026-11-06

Esta árvore inicia um novo histórico; o repositório original foi preservado.
A revisão abrangeu inventário dos 442 arquivos rastreados, varredura por padrões
de credenciais em 2.673 blobs alcançáveis nas refs locais (392 commits),
metadados Git, imagem de referência, documentação, helpers privilegiados e
receita/workflow de empacotamento. Não é uma auditoria exaustiva linha a linha.

## Resultados e alterações

- Nenhuma credencial detectada pelos padrões examinados (chaves privadas,
  tokens GitHub/AWS/Google/Slack, URLs autenticadas e atribuições de segredos).
  Os 34 alertas históricos eram a mesma expressão de máscara de senha na UI.
  Isso não garante ausência de segredos em formatos não reconhecidos.
- Excluída imagem com conversas, localização, identidade e redes pessoais.
- Caminhos pessoais em documentação substituídos por exemplos genéricos.
- Histórico anterior e e-mails dos commits não são incluídos no novo Git.
- Pacotes locais, caches, preferências e backups excluídos da cópia/ignore.
- Preservados avisos e licenças de Tabler e materialyoucolor.
- Corrigido empacotamento que exigia diretório power ausente no Git.
- Build local como padrão; nenhum hash do histórico antigo é necessário.
  Workflow usa checkout autenticado da tag para funcionar com fonte privada.

## Limitações para publicação

Ainda é necessário escolher uma licença para o código próprio. Não foi
atribuída uma licença em nome do autor. Instalação em Arch limpo e execução
integral do workflow no GitHub ainda precisam de validação. Nenhuma mudança
foi implantada no shell em execução; esta revisão não certifica estabilidade
visual ou de todas as integrações de hardware.
