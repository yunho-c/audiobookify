<script lang="ts">
  import { User, Bell, Shield, HelpCircle, LogOut, ChevronRight } from 'lucide-svelte';
</script>

<div class="p-6 pt-12 min-h-screen bg-stone-50">
  <header class="mb-8">
    <h1 class="text-3xl font-serif font-bold text-stone-800">Settings</h1>
  </header>

  <div class="space-y-6 max-w-md mx-auto">
    <!-- Profile Section -->
    <div class="bg-white rounded-2xl p-4 shadow-sm flex items-center gap-4 mb-6">
      <div class="w-16 h-16 rounded-full bg-stone-200 overflow-hidden">
        <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Felix" alt="Avatar" class="w-full h-full" />
      </div>
      <div class="flex-1">
        <h3 class="font-bold text-stone-800">John Doe</h3>
        <p class="text-sm text-stone-500">Premium Member</p>
      </div>
      <button class="text-orange-600 font-medium text-sm">Edit</button>
    </div>

    <!-- Menu Items -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <button class="w-full p-4 flex items-center justify-between hover:bg-stone-50 transition-colors border-b border-stone-100">
        <div class="flex items-center gap-3">
          <User size={20} class="text-stone-400" />
          <span class="text-stone-700 font-medium">Account</span>
        </div>
        <ChevronRight size={18} class="text-stone-300" />
      </button>
      
      <button class="w-full p-4 flex items-center justify-between hover:bg-stone-50 transition-colors border-b border-stone-100">
        <div class="flex items-center gap-3">
          <Bell size={20} class="text-stone-400" />
          <span class="text-stone-700 font-medium">Notifications</span>
        </div>
        <ChevronRight size={18} class="text-stone-300" />
      </button>

      <button class="w-full p-4 flex items-center justify-between hover:bg-stone-50 transition-colors">
        <div class="flex items-center gap-3">
          <Shield size={20} class="text-stone-400" />
          <span class="text-stone-700 font-medium">Privacy & Security</span>
        </div>
        <ChevronRight size={18} class="text-stone-300" />
      </button>
    </div>

    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <button class="w-full p-4 flex items-center justify-between hover:bg-stone-50 transition-colors border-b border-stone-100">
        <div class="flex items-center gap-3">
          <HelpCircle size={20} class="text-stone-400" />
          <span class="text-stone-700 font-medium">Help & Support</span>
        </div>
        <ChevronRight size={18} class="text-stone-300" />
      </button>
      
      <button class="w-full p-4 flex items-center justify-between hover:bg-red-50 transition-colors">
        <div class="flex items-center gap-3">
          <LogOut size={20} class="text-red-400" />
          <span class="text-red-600 font-medium">Log Out</span>
        </div>
      </button>
    </div>
    
    <p class="text-center text-xs text-stone-400 mt-8">Version 1.0.0</p>
  </div>
</div>
