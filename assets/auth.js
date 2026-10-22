(() => {
  const config = window.A2M_SUPABASE_CONFIG || {};
  const configured = /^https:\/\/.+\.supabase\.co$/.test(config.url || "") && !!config.publishableKey && !String(config.publishableKey).includes("SUA_CHAVE");
  const page = document.body;
  const isLogin = page.dataset.page === "login";
  const required = page.dataset.auth === "required";
  let client = null;
  if (configured && window.supabase?.createClient) client = window.supabase.createClient(config.url, config.publishableKey);
  window.A2M_SUPABASE_CLIENT = client;

  const showNotice = (message, kind = "error") => {
    const node = document.querySelector("[data-auth-notice]");
    if (!node) return;
    node.textContent = message;
    node.dataset.kind = kind;
    node.hidden = false;
  };
  const blockPage = (message) => {
    const layer = document.createElement("div");
    layer.className = "auth-blocker";
    layer.innerHTML = `<section><strong>Acesso protegido</strong><p>${message}</p><a href="./index.html">Ir para o login</a></section>`;
    document.body.append(layer);
    document.documentElement.classList.remove("auth-pending");
  };

  if (isLogin) {
    const form = document.querySelector("#loginForm");
    if (!client) showNotice("Configure a URL e a chave publishable do Supabase em assets/supabase-config.js para ativar o login.", "setup");
    if (client) client.auth.getSession().then(({ data }) => { if (data.session) location.replace("./portal.html"); });
    form?.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!client) return showNotice("O Supabase ainda não foi configurado.", "setup");
      const button = form.querySelector("button[type=submit]"); button.disabled = true; button.textContent = "Entrando…";
      const email = form.email.value.trim();
      const password = form.password.value;
      const { error } = await client.auth.signInWithPassword({ email, password });
      if (error) { showNotice("E-mail ou senha inválidos, ou usuário ainda não cadastrado."); button.disabled = false; button.textContent = "Entrar"; return; }
      const next = new URLSearchParams(location.search).get("next");
      const safeNext = next && /^[a-z0-9-]+\.html$/i.test(next) ? next : "portal.html";
      location.replace(`./${safeNext}`);
    });
    document.querySelector("[data-reset-password]")?.addEventListener("click", async (event) => {
      event.preventDefault();
      const email = form?.email?.value?.trim();
      if (!client) return showNotice("Configure o Supabase para habilitar a recuperação de senha.", "setup");
      if (!email) return showNotice("Informe seu e-mail para receber o link de recuperação.", "setup");
      const { error } = await client.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname });
      showNotice(error ? "Não foi possível enviar o link. Confira o e-mail e a configuração do Supabase." : "Se o e-mail estiver cadastrado, você receberá as instruções de recuperação.", error ? "error" : "success");
    });
  }

  if (required) {
    if (!client) { blockPage("A autenticação ainda não está configurada. Informe a URL e a chave publishable do seu projeto Supabase."); return; }
    window.A2M_AUTH_READY = client.auth.getSession().then(({ data, error }) => {
      if (error || !data.session) {
        const next = encodeURIComponent(location.pathname.split("/").pop() || "portal.html");
        location.replace(`./index.html?next=${next}`);
        return null;
      }
      document.documentElement.classList.remove("auth-pending");
      return data.session;
    });
  }
  document.querySelectorAll("[data-signout]").forEach(button => button.addEventListener("click", async () => {
    if (client) await client.auth.signOut();
    location.replace("./index.html");
  }));
})();
