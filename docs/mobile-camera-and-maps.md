# Câmera, mapas e veículos do MVP

## Câmera no iPhone

O check-in e o checkout usam a câmera do aparelho para registrar as quatro
faces do veículo. O iOS declara `NSCameraUsageDescription` e
`NSPhotoLibraryUsageDescription`; a aplicação trata cancelamento, permissão
negada e arquivos acima de 30 MB com feedback centralizado. Fotos HEIC são
aceitas pelo endpoint de fotos e permanecem sujeitas à política de retenção do
MVP.

## Mapas

O MVP usa tiles públicos do OpenStreetMap para a prévia e links externos para
Google Maps, Waze e OpenStreetMap. Nenhuma chave é embutida no código. Quando
um provedor comercial for ativado, a chave deverá ser fornecida por
`--dart-define=MAPS_API_KEY=...` (ou variável segura do CI), restringida por
aplicativo/domínio e nunca versionada. Marcadores próprios do ParkHere usam os
assets da marca; ícones de terceiros não são copiados.

## Tipos de veículo

O cadastro suporta carro, motocicleta e bicicleta. Carros e motos informam
marca/modelo; bicicletas usam número de identificação e podem registrar peças
ou características. O comprovante de compra/documento continua sendo um PDF.
O campo `vehicle_type` é extensível e mantém `car` como padrão para dados
existentes.

O número de identificação da bicicleta segue a referência de número de série
gravado no quadro e associado à nota fiscal, conforme orientação técnica do
[FNDE](https://www.gov.br/fnde/pt-br/acesso-a-informacao/acoes-e-programas/acoes/compras-governamentais/compras-nacionais/carta-consulta-e-comunicados/2025/bicicletas-e-capacetes-escolares/carta-consulta-de-bicicletas-e-capacetes-escolares.pdf).
