# Portal A2M — a2mLOG

Portal interno para reunir os painéis de operação com identidade visual consistente baseada na primeira versão pública do [repositório a2mLOG](https://github.com/yannlisboaa/a2mLOG).

## Arquivos

- `index.html`: entrada com login Supabase Auth.
- `portal.html`: central de módulos após o login.
- `conciliacao-estoque.html`: painel de conciliação de estoque.
- `kpis-estoque.html`: KPIs de estoque por produto, fabricante, giro, segmento e armazém.
- `shelf-life.html`: acompanhamento de vencimentos e relatório de conferência por período.
- `assets/sistema.css`: identidade visual compartilhada.
- `assets/supabase-config.js`: URL e chave pública do projeto Supabase.
- `supabase/schema.sql`: tabelas e políticas de acesso iniciais.

## Preparação do Supabase

1. Acesse o projeto Supabase configurado em `assets/supabase-config.js` e confira se ele continua ativo.
2. Abra o SQL Editor desse projeto, cole todo o conteúdo da versão atual de `supabase/schema.sql` e execute. O script pode ser executado novamente para aplicar permissões atualizadas. Se o erro de schema cache continuar, rode `NOTIFY pgrst, 'reload schema';` no SQL Editor e aguarde alguns segundos.
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

Publique a pasta inteira `publicacao-netlify`, incluindo `assets/` e `supabase/`. A primeira visita exige internet para carregar Supabase Auth e a biblioteca de leitura de Excel.





