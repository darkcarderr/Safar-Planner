/* Safar Planner shared configuration.
   Keep this public publishable key in the browser only with RLS enabled. */
window.SAFAR_CONFIG = window.SAFAR_CONFIG || {
  GOOGLE_MAPS_API_KEY: '' // Add a restricted Google Maps JavaScript API key if you use one.
};

const SUPABASE_URL = 'https://yadlkltklompfvytzcjq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_MN8Ug9nEiAhOUVIX7FNgNw_5fDhdVX-';

if (!window.supabase || !window.supabase.createClient) {
  console.error('Supabase library did not load. Check the CDN script before assets/config.js.');
} else {
  window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}
