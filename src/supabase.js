import { createClient } from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL;
const key=import.meta.env.VITE_SUPABASE_ANON_KEY;
export const hasBackend=Boolean(url&&key&&!url.includes('YOUR_PROJECT')&&!key.includes('YOUR_SUPABASE'));
export const supabase=hasBackend?createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true},realtime:{params:{eventsPerSecond:10}}}):null;
export function getClientId(){const key='gc-client-id';let id=localStorage.getItem(key);if(!id){id=crypto.randomUUID();localStorage.setItem(key,id)}return id}
export function randomRoomCode(){const chars='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';let out='';for(let i=0;i<6;i++)out+=chars[Math.floor(Math.random()*chars.length)];return out}
