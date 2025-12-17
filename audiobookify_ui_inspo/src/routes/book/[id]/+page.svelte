<script lang="ts">
  import { page } from '$app/stores';
  import { ArrowLeft, Clock, BookOpen, PlayCircle, CheckCircle2, Circle } from 'lucide-svelte';

  const { id } = $page.params;

  // Mock data based on ID (simplified)
  const book = {
    id,
    title: 'Adventures of Robinson Crusoe',
    author: 'Daniel Defoe',
    color: 'bg-emerald-700',
    pages: 296,
    minutes: 372,
    chapters: [
      { id: 1, title: 'Fisherman', completed: true },
      { id: 2, title: 'Fireman', completed: true },
      { id: 3, title: 'Chef', completed: false },
      { id: 4, title: 'Alice', completed: false },
      { id: 5, title: 'Sendless', completed: false },
      { id: 6, title: 'Walrusay', completed: false },
    ]
  };
</script>

<div class="min-h-screen bg-stone-100 pb-24 relative">
  <!-- Header Image / Background -->
  <div class="h-64 {book.color} relative overflow-hidden">
    <div class="absolute inset-0 bg-gradient-to-b from-black/30 to-stone-100"></div>
    
    <!-- Back Button -->
    <a href="/" class="absolute top-6 left-6 p-2 bg-white/20 backdrop-blur-md rounded-full text-white hover:bg-white/30 transition-colors z-20">
      <ArrowLeft size={24} />
    </a>
  </div>

  <!-- Content Container -->
  <div class="px-6 -mt-32 relative z-10">
    <!-- Book Cover 3D Effect -->
    <div class="aspect-[2/3] w-48 mx-auto rounded-lg shadow-2xl {book.color} relative transform rotate-y-12 mb-8 group">
      <div class="absolute inset-0 bg-gradient-to-br from-white/20 to-black/10 rounded-lg"></div>
      <!-- Spine -->
      <div class="absolute left-0 top-0 bottom-0 w-2 bg-black/20 z-10 rounded-l-lg"></div>
      <div class="absolute left-2 top-0 bottom-0 w-px bg-white/30 z-10"></div>
      
      <div class="p-6 flex flex-col h-full justify-between relative z-20 text-center">
        <div>
          <h1 class="text-white font-serif text-2xl font-bold leading-tight drop-shadow-md">{book.title}</h1>
          <p class="text-white/80 text-sm mt-2 font-medium">{book.author}</p>
        </div>
        <div class="text-white/60 text-xs font-mono tracking-widest uppercase">
          {book.id} // {book.pages}pgs
        </div>
      </div>
    </div>

    <!-- Stats -->
    <div class="flex justify-center gap-8 mb-8 text-stone-600">
      <div class="flex flex-col items-center">
        <BookOpen size={20} class="mb-1 text-stone-400" />
        <span class="font-bold text-lg">{book.pages}</span>
        <span class="text-xs uppercase tracking-wider">Pages</span>
      </div>
      <div class="w-px bg-stone-300"></div>
      <div class="flex flex-col items-center">
        <Clock size={20} class="mb-1 text-stone-400" />
        <span class="font-bold text-lg">{book.minutes}</span>
        <span class="text-xs uppercase tracking-wider">Est. Mins</span>
      </div>
    </div>

    <!-- Chapter List -->
    <div class="bg-white rounded-2xl shadow-sm p-6 mb-8">
      <h2 class="text-lg font-bold text-stone-800 mb-4 font-serif">Chapters</h2>
      <div class="space-y-4">
        {#each book.chapters as chapter}
          <a href="/player/{book.id}?chapter={chapter.id}" class="flex items-center justify-between group p-2 -mx-2 rounded-lg hover:bg-stone-50 transition-colors">
            <div class="flex items-center gap-4">
              <span class="text-stone-300 font-mono text-sm w-4">{chapter.id}.</span>
              <span class="text-stone-700 font-medium group-hover:text-orange-700 transition-colors">{chapter.title}</span>
            </div>
            {#if chapter.completed}
              <CheckCircle2 size={20} class="text-emerald-500" />
            {:else}
              <Circle size={20} class="text-stone-300 group-hover:text-orange-300" />
            {/if}
          </a>
        {/each}
      </div>
    </div>
  </div>

  <!-- Floating Action Button -->
  <div class="fixed bottom-24 right-6 z-40">
    <a href="/player/{book.id}" class="flex items-center gap-2 bg-stone-800 text-white pl-5 pr-6 py-3 rounded-full shadow-xl hover:bg-black transition-colors hover:scale-105 active:scale-95">
      <PlayCircle size={24} />
      <span class="font-bold">Resume</span>
    </a>
  </div>
</div>
