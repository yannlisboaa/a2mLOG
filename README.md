# Portal A2M — a2mLOG

Portal interno para reunir os painéis de operação com identidade visual consistente baseada na primeira versão pública do [repositório a2mLOG](https://github.com/yannlisboaa/a2mLOG).

## Arquivos

- `index.html`: entrada com login Supabase Auth.
- `portal.html`: central de módulos após o login.
- `conciliacao-estoque.html`: painel de conciliação de estoque.
- `shelf-life.html`: acompanhamento de vencimentos e relatório de conferência por período.
- `assets/sistema.css`: identidade visual compartilhada.
- `assets/supabase-config.js`: URL e chave pública do projeto Supabase.
- `supabase/schema.sql`: tabelas e políticas de acesso iniciais.

## Preparação do Supabase

1. Acesse o projeto Supabase configurado em `assets/supabase-config.js` e confira se ele continua ativo.
2. Execute `supabase/schema.sql` no SQL Editor.
3. Mantenha o cadastro público desativado e crie as contas operacionais pelo Supabase Auth.
4. Promova um usuário a administrador com `update public.profiles set role = 'admin' where id = (select id from auth.users where email = 'email@empresa.com.br');`.
5. Importe as bases de Conciliação e Shelf-Life com uma conta administradora. As cargas são mantidas privadas pelo Supabase e só aparecem depois de concluídas. As conferências e justificativas de Conciliação são compartilhadas entre os usuários autenticados.

A chave anon/publishable é pública por definição e já está no portal original. Nunca use a chave `service_role` no navegador ou no repositório.

## Publicação

Publique a pasta inteira `publicacao-netlify`, incluindo `assets/` e `supabase/`. A primeira visita exige internet para carregar Supabase Auth e a biblioteca de leitura de Excel.


