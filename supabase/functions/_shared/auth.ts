import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Extracts the JWT from the Authorization header and returns the authenticated user.
 * Throws a 401 Response if the token is missing or invalid.
 */
export async function getAuthenticatedUser(req: Request, supabaseAdminClient: SupabaseClient) {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Response(JSON.stringify({ error: 'Missing or invalid Authorization header' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const jwt = authHeader.replace('Bearer ', '')
  const { data: { user }, error } = await supabaseAdminClient.auth.getUser(jwt)

  if (error || !user) {
    throw new Response(JSON.stringify({ error: 'Invalid or expired token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return user
}

/**
 * Fetches the profile row for the given userId.
 * Throws a 404 Response if no profile is found.
 */
export async function getUserProfile(supabaseAdminClient: SupabaseClient, userId: string) {
  const { data: profile, error } = await supabaseAdminClient
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single()

  if (error || !profile) {
    throw new Response(JSON.stringify({ error: 'User profile not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return profile
}

/**
 * Throws a 403 Response if the profile's role is not in the allowedRoles array.
 */
export function requireRole(profile: { role: string }, allowedRoles: string[]) {
  if (!allowedRoles.includes(profile.role)) {
    throw new Response(
      JSON.stringify({ error: `Access denied. Required role(s): ${allowedRoles.join(', ')}` }),
      { status: 403, headers: { 'Content-Type': 'application/json' } }
    )
  }
}
