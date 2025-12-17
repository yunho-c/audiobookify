<script lang="ts">
  import { House, Plus, Settings } from 'lucide-svelte';
  import { page } from '$app/stores';
</script>

<nav class="fixed bottom-0 left-0 right-0 z-50 px-6 py-4">
  <div class="absolute inset-0 bg-white/80 backdrop-blur-lg border-t border-white/20 shadow-lg"></div>
  
  <div class="relative flex justify-around items-center max-w-md mx-auto h-16">
    <a 
      href="/" 
      class="p-3 rounded-full transition-colors duration-200 {$page.url.pathname === '/' ? 'text-orange-600 bg-orange-50' : 'text-gray-500 hover:text-gray-900'}"
    >
      <House size={24} />
      <span class="sr-only">Home</span>
    </a>

    <a 
      href="/create" 
      class="p-4 -mt-8 bg-orange-600 text-white rounded-full shadow-lg shadow-orange-600/30 hover:bg-orange-700 transition-transform duration-200 hover:scale-105 active:scale-95"
    >
      <Plus size={28} strokeWidth={3} />
      <span class="sr-only">Create</span>
    </a>

    <a 
      href="/settings" 
      class="p-3 rounded-full transition-colors duration-200 {$page.url.pathname === '/settings' ? 'text-orange-600 bg-orange-50' : 'text-gray-500 hover:text-gray-900'}"
    >
      <Settings size={24} />
      <span class="sr-only">Settings</span>
    </a>
  </div>
</nav>
