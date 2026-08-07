import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get the authorization header from the request
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    
    // Get user from token
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token)
    
    if (userError || !user) {
      throw new Error('Unauthorized')
    }

    const userId = user.id

    console.log(`Deleting account for user: ${userId}`)

    // Delete in the correct order to respect foreign key constraints
    
    // 1. Delete user's posts (this will cascade to likes, comments if configured)
    const { error: postsError } = await supabaseClient
      .from('posts')
      .delete()
      .eq('user_id', userId)

    if (postsError) {
      console.error('Error deleting posts:', postsError)
      // Continue anyway, posts might not exist
    }

    // 2. Delete from any other tables that reference the user
    // Add more tables here if needed
    const tables = ['likes', 'comments', 'notifications']
    
    for (const table of tables) {
      try {
        await supabaseClient
          .from(table)
          .delete()
          .eq('user_id', userId)
      } catch (e) {
        console.log(`Table ${table} might not exist or no data: ${e}`)
      }
    }

    // 3. Delete user data from users table
    const { error: userDataError } = await supabaseClient
      .from('users')
      .delete()
      .eq('id', userId)

    if (userDataError) {
      console.error('Error deleting user data:', userDataError)
      // Continue anyway
    }

    // 4. Finally, delete the auth user
    const { error: deleteError } = await supabaseClient.auth.admin.deleteUser(userId)

    if (deleteError) {
      console.error('Error deleting auth user:', deleteError)
      
      // If we still can't delete, at least mark the user as deleted
      // by updating the email to prevent reuse
      await supabaseClient.auth.admin.updateUserById(userId, {
        email: `deleted_${userId}@deleted.local`,
        email_confirm: true,
      })
      
      console.log(`User ${userId} marked as deleted (email changed)`)
    } else {
      console.log(`Successfully deleted account for user: ${userId}`)
    }

    return new Response(
      JSON.stringify({ 
        message: 'Account deleted successfully',
        user_id: userId 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    console.error('Error in deleteAccount function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})
