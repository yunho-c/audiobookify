<script lang="ts">
  import { Play, Pause, SkipBack, SkipForward, Repeat, Shuffle } from 'lucide-svelte';

  export let isPlaying: boolean = false;
  export let progress: number = 0;
  export let duration: string = "23:56";
  export let currentTime: string = "17:06";
</script>

<div class="bg-stone-100/90 backdrop-blur-xl border-t border-stone-200 p-6 pb-8 rounded-t-3xl shadow-[0_-10px_40px_rgba(0,0,0,0.1)]">
  <!-- Progress Bar -->
  <div class="mb-6">
    <div class="flex justify-between text-xs font-mono text-stone-500 mb-2">
      <span>{currentTime}</span>
      <span>{duration}</span>
    </div>
    <div class="h-1.5 bg-stone-300 rounded-full overflow-hidden relative group cursor-pointer">
      <div class="absolute inset-y-0 left-0 bg-orange-600 rounded-full" style="width: {progress}%"></div>
      <!-- Thumb -->
      <div class="absolute top-1/2 -mt-1.5 w-3 h-3 bg-white border-2 border-orange-600 rounded-full shadow-md opacity-0 group-hover:opacity-100 transition-opacity" style="left: {progress}%"></div>
    </div>
  </div>

  <!-- Controls -->
  <div class="flex items-center justify-between px-4">
    <button class="text-stone-400 hover:text-orange-600 transition-colors">
      <Shuffle size={20} />
    </button>
    
    <button class="text-stone-600 hover:text-stone-900 transition-colors active:scale-95">
      <SkipBack size={28} fill="currentColor" class="text-stone-600" />
    </button>

    <button 
      class="w-16 h-16 bg-stone-800 text-white rounded-2xl flex items-center justify-center shadow-lg hover:bg-black transition-all active:scale-95"
      on:click={() => isPlaying = !isPlaying}
    >
      {#if isPlaying}
        <Pause size={32} fill="currentColor" />
      {:else}
        <Play size={32} fill="currentColor" class="ml-1" />
      {/if}
    </button>

    <button class="text-stone-600 hover:text-stone-900 transition-colors active:scale-95">
      <SkipForward size={28} fill="currentColor" class="text-stone-600" />
    </button>

    <button class="text-stone-400 hover:text-orange-600 transition-colors">
      <Repeat size={20} />
    </button>
  </div>
</div>
