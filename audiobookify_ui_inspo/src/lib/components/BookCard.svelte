<script lang="ts">
  import { Play, BookOpen } from 'lucide-svelte';

  export let id: string;
  export let title: string;
  export let author: string;
  export let color: string = 'bg-amber-700';
  export let progress: number = 0;
</script>

<a href="/book/{id}" class="group relative block aspect-[2/3] rounded-xl overflow-hidden shadow-md hover:shadow-xl transition-all duration-300 hover:-translate-y-1">
  <!-- Cover -->
  <div class="absolute inset-0 {color} p-4 flex flex-col justify-between">
    <div class="absolute inset-0 bg-gradient-to-br from-white/20 to-black/10"></div>
    
    <!-- Spine effect -->
    <div class="absolute left-0 top-0 bottom-0 w-1.5 bg-black/20 z-10"></div>
    <div class="absolute left-1.5 top-0 bottom-0 w-px bg-white/30 z-10"></div>

    <div class="relative z-10">
      <h3 class="text-white font-serif text-lg font-bold leading-tight drop-shadow-sm line-clamp-3">{title}</h3>
      <p class="text-white/80 text-xs mt-1 font-medium">{author}</p>
    </div>

    <!-- Progress or Icon -->
    <div class="relative z-10 flex justify-end">
      {#if progress > 0}
        <div class="w-8 h-8 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white">
          <span class="text-xs font-bold">{progress}%</span>
        </div>
      {:else}
        <div class="w-8 h-8 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white opacity-0 group-hover:opacity-100 transition-opacity">
          <BookOpen size={14} />
        </div>
      {/if}
    </div>
  </div>

  <!-- Progress Bar at bottom -->
  {#if progress > 0}
    <div class="absolute bottom-0 left-0 right-0 h-1 bg-black/30">
      <div class="h-full bg-orange-400" style="width: {progress}%"></div>
    </div>
  {/if}
</a>
