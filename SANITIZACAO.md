# Sanitização desta versão pública

Cópia sanitizada de um projeto em uso real. Nada aqui é dado de cliente ou de terceiro: o que aparece como exemplo é inventado. Detalhe completo da sanitização: relatório interno da autora.

## O que foi removido

Registros e contratos de projetos reais, credenciais e caminhos da máquina.

## O que foi trocado

Programa, parceiro, órgãos → genéricos; URLs de repositórios privados → nome público (`ai-project-os`) ou texto genérico; caminhos locais → exemplo.

## O que é fictício

Os contratos em `registry/projects/exemplo-*.yaml` e os testes usam projetos fictícios em Temp.

## Como verificar

```bat
py -3.13 -m unittest discover -s eos/tests -t .     # ~25 min
```

Varreduras (2026-11-19): gitleaks `dir` só com falsos positivos justificados; busca por caminho local, e-mail, nomes do cliente e links privados sem ocorrências reais.
