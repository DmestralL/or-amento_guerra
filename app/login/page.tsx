"use client";

import {useState} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";

export default function Login(){
 const router=useRouter();
 const [email,setEmail]=useState("");
 const [password,setPassword]=useState("");
 const [message,setMessage]=useState("");
 const [sending,setSending]=useState(false);

 async function submit(){
  try{
   const sb=createClient();
   const {error}=await sb.auth.signInWithPassword({email,password});
   if(error)throw error;
   setMessage("Acesso realizado. Redirecionando…");
   router.push("/");
  }catch(e){setMessage(e instanceof Error?e.message:"Não foi possível continuar.")}
 }

 async function recover(){
  if(!email){setMessage("Digite seu e-mail primeiro.");return}
  setSending(true);setMessage("");
  const sb=createClient();
  const {error}=await sb.auth.resetPasswordForEmail(email,{redirectTo:`${window.location.origin}/definir-senha`});
  setSending(false);
  if(error){setMessage(error.message);return}
  setMessage("Enviamos um e-mail para você criar ou recuperar sua senha.");
 }

 return <main className="grid min-h-screen place-items-center bg-ink p-4"><section className="w-full max-w-md rounded-[2rem] bg-white p-7"><p className="label">Orçamento da Família</p><h1 className="mt-2 text-3xl font-black">Entre na sua família</h1><p className="mt-2 text-sm text-ink/60">Acesso exclusivo para membros convidados da família.</p><label className="mt-6 block"><span className="label">E-mail</span><input autoComplete="email" className="tap mt-1 w-full rounded-xl border px-4" type="email" value={email} onChange={e=>setEmail(e.target.value)}/></label><label className="mt-4 block"><span className="label">Senha</span><input autoComplete="current-password" className="tap mt-1 w-full rounded-xl border px-4" type="password" value={password} onChange={e=>setPassword(e.target.value)} onKeyDown={e=>{if(e.key==="Enter")void submit()}}/></label><button onClick={()=>void submit()} className="tap mt-6 w-full rounded-xl bg-ink font-black text-white">Entrar</button><button disabled={sending} onClick={()=>void recover()} className="tap mt-3 w-full rounded-xl border border-ink/20 font-black text-ink disabled:opacity-60">{sending?"Enviando…":"Criar ou recuperar senha"}</button><p className="mt-4 text-center text-xs text-ink/55">Não possui acesso? Solicite um convite ao administrador da família.</p>{message&&<p role="status" className="mt-4 rounded-xl bg-mint p-3 text-sm">{message}</p>}</section></main>
}
