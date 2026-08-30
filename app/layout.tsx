import type { Metadata, Viewport } from "next";
import "./globals.css";
export const metadata: Metadata={title:"Orçamento da Família",description:"Finanças do casal, simples e compartilhadas.",manifest:"/manifest.webmanifest",appleWebApp:{capable:true,title:"Orçamento"}};
export const viewport: Viewport={themeColor:"#17352e",width:"device-width",initialScale:1,viewportFit:"cover"};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="pt-BR"><body>{children}<script dangerouslySetInnerHTML={{__html:`if('serviceWorker' in navigator){addEventListener('load',()=>navigator.serviceWorker.register('/sw.js'))}`}}/></body></html>}
