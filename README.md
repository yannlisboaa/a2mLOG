# Portal A2M — a2mLOG

Portal interno para reunir os painéis de operação com identidade visual consistente baseada na primeira versão pública do [repositório a2mLOG](https://github.com/yannlisboaa/a2mLOG).

## Arquivos

- `index.html`: entrada com login Supabase Auth.
- `portal.html`: central de módulos após o login.
- `conciliacao-estoque.html`: painel de conciliação de estoque.
- `kpis-estoque.html`: KPIs de estoque por produto, fabricante, giro, segmento e armazém.
- `shelf-life.html`: acompanhamento de vencimentos e relatório de conferência por período.
- `assets/sistema.css`: identidade visual compartilhada.
- `assets/PADRONAGEM - BRANCA.png`: padronagem A2M usada no cabeçalho, no login e nos cards de acesso da página inicial.
- `assets/supabase-config.js`: URL e chave pública do projeto Supabase.
- `supabase/schema.sql`: tabelas e políticas de acesso iniciais.
- `supabase/otimizacao-kpis-estoque.sql`: atualização incremental para otimizar as cargas do painel de KPIs.
- `supabase/rollback-deltaze-kpi-sync.sql`: remove os metadados da API Deltaze caso a migração anterior já tenha sido aplicada.

## Preparação do Supabase

1. Acesse o projeto Supabase configurado em `assets/supabase-config.js` e confira se ele continua ativo.
2. Para otimizar uma instalação existente, abra o SQL Editor do Supabase e execute `supabase/otimizacao-kpis-estoque.sql`. Em uma instalação nova, aplique `supabase/schema.sql`, que já inclui as mesmas otimizações. A atualização é repetível. Se o erro de schema cache continuar, rode `NOTIFY pgrst, 'reload schema';` no SQL Editor e aguarde alguns segundos.
   Se `supabase/deltaze-kpi-sync.sql` já tiver sido executado no banco, rode `supabase/rollback-deltaze-kpi-sync.sql` para restaurar a estrutura anterior dos KPIs. Não execute o rollback se a migração não tiver sido aplicada.
3. Mantenha o cadastro público desativado e crie as contas operacionais pelo Supabase Auth.
4. Substitua `SEU_EMAIL_AQUI` pelo e-mail do administrador em `supabase/promover-admin.sql` e execute o script no SQL Editor.
5. Com o schema aplicado e a conta com perfil `admin`, abra KPIs de Estoque e selecione a planilha KPI Giro de Estoque atualizada (abas `Estoque Geral` e `Valor Armazenado`). A nova versão fica disponível após o envio completo.
6. Importe as bases de Conciliação e Shelf-Life com uma conta administradora. As cargas são mantidas privadas pelo Supabase e só aparecem depois de concluídas. As conferências e justificativas de Conciliação são compartilhadas entre os usuários autenticados.

### Como a Conciliação é compartilhada

- Um administrador publica o Excel pelo painel. O Supabase mantém a carga anterior e marca a nova como disponível somente depois que todos os itens forem gravados.
- Cada usuário autenticado abre a última carga concluída, inclusive em outro dispositivo. Contagens físicas e justificativas são gravadas no Supabase e ficam visíveis para os demais usuários ao recarregar a tela.
- O acesso atual é compartilhado entre todos os logins autenticados; ainda não há restrição de leitura ou edição por filial. Operadores só podem alterar campos de contagem e justificativa; a publicação de uma nova base exige perfil `admin`.
- Depois de atualizar `supabase/schema.sql`, execute o arquivo completo no SQL Editor do projeto para aplicar as tabelas, políticas e permissões.

A chave anon/publishable é pública por definição e já está no portal original. Nunca use a chave `service_role` no navegador ou no repositório.

## Publicação

Publique a raiz deste repositório no GitHub Pages ou use a raiz como diretório de publicação no Netlify. Mantenha juntos `index.html`, os módulos, `assets/` e `supabase/`. A primeira visita exige internet para carregar Supabase Auth e a biblioteca de leitura de Excel.

## Fluxo de atualização

As mudanças são preparadas e revisadas na cópia local primeiro. A versão pública do GitHub permanece ativa durante essa revisão; o envio para `main` acontece depois da aprovação da versão final.







## Operação TMS

- `tms.html`: painel integrado ao menu A2M, com filtros, produtividade, ranking de entregadores e fila de tratamento de exceções.
- `supabase/tms.sql`: migração para criar tabelas privadas de cargas, pedidos e exceções, usando o controle de acesso por perfil já existente. Execute no SQL Editor antes de usar o módulo.
- A aba `Pedidos` do Excel é importada por um administrador. O painel grava somente identificador e dados operacionais; nome e endereço do cliente não são gravados. Operadores autenticados podem consultar e tratar as exceções; somente administradores publicam ou substituem a base.
- A publicação mantém a carga mais recente concluída. As bibliotecas SheetJS e Chart.js são carregadas por CDN.
- SLA considera somente entregas com flag `No Prazo` ou `Em Atraso`. O ranking considera entregas concluídas com flag, ordena por taxa no prazo e desempata por volume. Casos com menos de 10 entregas classificadas são identificados como amostra pequena.
- A fila de exceções sinaliza atraso, urgência/emergência pendente, entrega concluída sem flag, CD ausente e entrega concluída sem entregador ou horário final. O responsável e o status do tratamento podem ser atualizados no painel. Evite inserir dados pessoais de clientes nas observações.
- A coluna `Nota Informada (Entregador)` do arquivo não é importada: contém textos e números de referência, não uma nota numérica validada para avaliação.

## Melhorias futuras

1. Validar metas de SLA por prioridade e CD com a operação.
2. Acompanhar mediana e percentil 90 dos tempos inclusão → saída → finalização, por faixa horária e CD.
3. Normalizar produtividade por escala/turno e carga de rota, para comparações justas entre entregadores.
4. Monitorar completude dos campos, reentregas/cancelamentos e motivos de atraso quando o TMS disponibilizar esses dados.
5. Integrar `Resumo Diário Incentivos` para auditoria de incentivos por entregador/dia, conforme as regras de elegibilidade.
6. Avaliar mapa agregado por bairro/município sem expor nomes ou endereços.


### Solução de problemas de acesso

- Se o arquivo estiver bloqueado, entre com uma conta cujo perfil em `public.profiles` seja `admin`; usuários `operador` consultam e atualizam o tratamento das exceções, mas não publicam cargas.
- Para promover o administrador inicial, substitua `SEU_EMAIL_AQUI` em `supabase/promover-admin.sql` pelo e-mail exato da conta no Supabase Auth e execute o script no SQL Editor. Depois, encerre e inicie a sessão no portal.
- Se a página avisar que a estrutura está ausente, execute `supabase/tms.sql` no SQL Editor do projeto configurado no portal.
