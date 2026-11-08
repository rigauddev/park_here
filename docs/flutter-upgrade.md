# Atualização do Flutter

## Estado verificado em 18/09/2026

A documentação oficial lista o Flutter 3.47.2 como a versão estável atual. O
projeto já usa Material 3, `ColorScheme.fromSeed`, `NavigationBar`,
`FilledButton`, `WidgetState` e temas específicos para componentes. Esses são
os componentes recomendados pelo Material 3 e não exigem a migração opcional
para os pacotes independentes `material_ui` e `cupertino_ui` neste ciclo.

O container usa `ghcr.io/cirruslabs/flutter:stable`. O registry disponível no
ambiente ainda entrega Flutter 3.44.0 e não publica tags 3.47.x. O Dockerfile
aceita a imagem explicitamente quando ela estiver disponível:

```bash
docker compose build --build-arg FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:3.47.2 web
```

Como o `docker-compose.yml` repassa esse argumento automaticamente, também é
possível selecionar a imagem sem editar arquivos:

```bash
FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:3.47.2 docker compose build web
```

Não usar `flutter upgrade --force` no SDK local enquanto houver alterações
locais fora do repositório. A atualização deve ocorrer pelo container ou por um
SDK separado, preservando o SDK de desenvolvimento existente.

## Mudanças aplicadas agora

- tema Material 3 com chips usando `outline`/bordas suaves;
- `SearchBarTheme` consistente com os campos do app;
- `SnackBar` flutuante com fechamento explícito;
- cartões sem tonalidade automática de elevação, mantendo a leitura em telas
  pequenas e na Web;
- Dockerfile parametrizado para fixar a imagem estável quando a tag 3.47.2
  estiver publicada.

## Validação

```bash
docker compose exec -T web flutter analyze
docker compose exec -T web flutter test --no-pub
```

O SDK deve ser atualizado somente depois de confirmar a imagem/tag disponível e
rodar novamente análise, testes, build Web e build Android de homologação.
