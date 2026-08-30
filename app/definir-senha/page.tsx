"use client";

import {useEffect,useState} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";

export default function DefinirSenha(){
 const router=useRouter();
 const [password,setPassword]=useState("");
 const [confirmPassword,setConfirmPassword]=useState("");
 const [ready,setReady]=useState(false);
 const [saving,setSaving]=useState(false);
 const [message,setMessage]=useState("Validando seu convite…");

 useEffect(()=>{
  const sb=createClient();
  let active=true;
  async function checkSession(){
   const {data,error}=await sb.auth.getSession();
   if(!active)return;
   if(error||!data.session){
    setReady(false);
    setMessage("Este convite é inválido ou expirou. Peça ao administrador para enviar um novo convite.");
    return;
   }
   setReady(true);
   setMessage("");
  }
  void checkSession();
  const {data:{subscription}}=sb.auth.onAuthStateChange((_event,session)=>{
   if(!active)return;
   setReady(Boolean(session));
   if(session)setMessage("");
  });
  return()=>{active=false;subscription.unsubscribe()};
 },[]);

 async function submit(){
  if(password.length<8){setMessage("A senha precisa ter pelo menos 8 caracteres.");return}
  if(password!==confirmPassword){setMessage("As senhas não coincidem.");return}
  setSaving(true);setMessage("");
  const sb=createClient();
  const {error}=await sb.auth.updateUser({password});
  if(error){setMessage(error.message);setSaving(false);return}
  setMessage("Senha criada. Entrando no aplicativo…");
  router.replace("/");router.refresh();
 }

 return <main className="grid min-h-screen place-items-center bg-ink p-4"><section className="w-full max-w-md rounded-[2rem] bg-white p-7"><p className="label">Orçamento da Família</p><h1 className="mt-2 text-3xl font-black">Crie sua senha</h1><p className="mt-2 text-sm text-ink/60">Conclua o convite para acessar o orçamento da família.</p>{ready&&<><label className="mt-6 block"><span className="label">Nova senha</span><input autoComplete="new-password" className="tap mt-1 w-full rounded-xl border px-4" type="password" value={password} onChange={e=>setPassword(e.target.value)}/></label><label className="mt-4 block"><span className="label">Confirme a senha</span><input autoComplete="new-password" className="tap mt-1 w-full rounded-xl border px-4" type="password" value={confirmPassword} onChange={e=>setConfirmPassword(e.target.value)} onKeyDown={e=>{if(e.key==="Enter")void submit()}}/></label><button disabled={saving} onClick={()=>void submit()} className="tap mt-6 w-full rounded-xl bg-ink font-black text-white disabled:opacity-60">{saving?"Salvando…":"Criar senha e entrar"}</button></>}{message&&<p role="status" className="mt-5 rounded-xl bg-mint p-3 text-sm">{message}</p>}</section></main>
}
