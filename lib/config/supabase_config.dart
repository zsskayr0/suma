/// Supabase project connection details. The anon/publishable key is safe to
/// ship in client code by design - every table it can touch is protected by
/// the row-level security policies in `supabase/schema.sql`, not by keeping
/// this key secret.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://oqfqbpjgyxdinwaiqqzp.supabase.co';
  static const String anonKey = 'sb_publishable_JX4TGYeLHug7RJcJ-eV7CA_uSYId6QK';
}
