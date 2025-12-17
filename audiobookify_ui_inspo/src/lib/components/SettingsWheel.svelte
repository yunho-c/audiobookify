<script lang="ts">
  import { X, Gauge, Mic2, Languages, Music } from 'lucide-svelte';
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();
  
  export let isOpen: boolean = false;

  const settings = [
    { id: 'speed', label: 'Speed', icon: Gauge, value: '1.0x', color: 'bg-rose-100 text-rose-600' },
    { id: 'pitch', label: 'Pitch', icon: Music, value: 'Deep', color: 'bg-amber-100 text-amber-600' },
    { id: 'style', label: 'Style', icon: Mic2, value: 'Sample', color: 'bg-blue-100 text-blue-600' },
    { id: 'accent', label: 'Accent', icon: Languages, value: 'British', color: 'bg-emerald-100 text-emerald-600' },
  ];
</script>

{#if isOpen}
  <div role="button" tabindex="0" class="fixed inset-0 z-50 flex items-center justify-center p-6 bg-black/20 backdrop-blur-sm cursor-default w-full border-none outline-none" on:click={() => dispatch('close')} on:keydown={(e) => e.key === 'Escape' && dispatch('close')}>
    <div role="dialog" aria-modal="true" class="bg-white rounded-3xl shadow-2xl w-full max-w-xs p-6 relative animate-in zoom-in-95 duration-200 cursor-auto" on:click|stopPropagation on:keydown|stopPropagation>
      <button class="absolute top-4 right-4 text-stone-400 hover:text-stone-900" on:click={() => dispatch('close')}>
        <X size={20} />
      </button>

      <h3 class="text-center font-bold text-stone-800 mb-6 font-serif text-lg">Audio Settings</h3>

      <div class="grid grid-cols-2 gap-4">
        {#each settings as setting}
          <button class="aspect-square rounded-2xl {setting.color} flex flex-col items-center justify-center gap-2 hover:brightness-95 transition-all active:scale-95">
            <svelte:component this={setting.icon} size={24} />
            <div class="text-center">
              <div class="text-xs font-bold uppercase opacity-60">{setting.label}</div>
              <div class="font-bold">{setting.value}</div>
            </div>
          </button>
        {/each}
      </div>
      
      <!-- Wheel Graphic Representation (Decorative based on sketch) -->
      <div class="mt-6 flex justify-center">
        <div class="w-16 h-16 rounded-full border-4 border-stone-100 flex items-center justify-center relative">
          <div class="absolute inset-0 rounded-full border-t-4 border-rose-400 rotate-45"></div>
          <div class="absolute inset-0 rounded-full border-r-4 border-amber-400 rotate-45"></div>
          <div class="absolute inset-0 rounded-full border-b-4 border-blue-400 rotate-45"></div>
          <div class="absolute inset-0 rounded-full border-l-4 border-emerald-400 rotate-45"></div>
          <div class="w-4 h-4 bg-stone-800 rounded-full"></div>
        </div>
      </div>
    </div>
  </div>
{/if}
