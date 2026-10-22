-- A2M Portal: promover uma conta específica a administradora.
-- Troque pelo e-mail exato cadastrado em Supabase Auth e execute no SQL Editor.
DO $$
DECLARE
  target_email text := lower('SEU_EMAIL_AQUI');
  auth_user_id uuid;
  auth_user_name text;
BEGIN
  IF target_email = 'seu_email_aqui' OR position('@' in target_email) = 0 THEN
    RAISE EXCEPTION 'Informe o e-mail exato usado no login do portal em target_email.';
  END IF;

  SELECT u.id,
         coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1))
    INTO auth_user_id, auth_user_name
  FROM auth.users AS u
  WHERE lower(u.email) = target_email
  LIMIT 1;

  IF auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Não encontrei esse e-mail em Authentication > Users. Confira o e-mail ou crie a conta no Supabase Auth antes de executar novamente.';
  END IF;

  INSERT INTO public.profiles (id, full_name, role)
  VALUES (auth_user_id, auth_user_name, 'admin')
  ON CONFLICT (id) DO UPDATE SET role = 'admin';
END
$$;
