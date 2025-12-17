<script lang="ts">
  import { page } from '$app/stores';
  import { ArrowLeft, Settings2, BookOpen } from 'lucide-svelte';
  import PlayerControls from '$lib/components/PlayerControls.svelte';
  import SettingsWheel from '$lib/components/SettingsWheel.svelte';

  const { id } = $page.params;
  let showSettings = false;
  let isPlaying = true;

  // Mock text content
  const content = [
    "I was born in the year 1632, in the city of York, of a good family, though not of that country, my father being a foreigner of Bremen, who settled first at Hull.",
    "He got a good estate by merchandise, and leaving off his trade, lived afterwards at York, from whence he had married my mother, whose relations were named Robinson, a very good family in that country, and from whom I was called Robinson Kreutznaer; but, by the usual corruption of words in England, we are now called - nay we call ourselves and write our name - Crusoe; and so my companions always called me.",
    "I had two elder brothers, one of whom was lieutenant-colonel to an English regiment of foot in Flanders, formerly commanded by the famous Col. Lockhart, and was killed at the battle near Dunkirk against the Spaniards.",
    "What became of my second brother I never knew, any more than my father or mother knew what became of me."
  ];
</script>

<div class="min-h-screen bg-orange-50/50 flex flex-col relative">
  <!-- Header -->
  <header class="px-6 pt-6 pb-4 flex items-center justify-between sticky top-0 bg-orange-50/95 backdrop-blur-sm z-10">
    <a href="/book/{id}" class="p-2 -ml-2 text-stone-600 hover:text-stone-900 transition-colors">
      <ArrowLeft size={24} />
    </a>
    <div class="text-center">
      <h1 class="font-serif font-bold text-stone-800">2. Fireman</h1>
      <p class="text-xs text-stone-500 uppercase tracking-wider">Chapter 2</p>
    </div>
    <button 
      class="p-2 -mr-2 text-stone-600 hover:text-stone-900 transition-colors"
      on:click={() => showSettings = true}
    >
      <Settings2 size={24} />
    </button>
  </header>

  <!-- Content -->
  <main class="flex-1 px-8 py-4 overflow-y-auto pb-48">
    <div class="prose prose-stone prose-lg leading-loose mx-auto">
      {#each content as paragraph, i}
        <p class={i === 1 ? "bg-orange-200/50 px-2 -mx-2 rounded-lg transition-colors duration-500" : "text-stone-600 transition-colors duration-500"}>
          {paragraph}
        </p>
      {/each}
    </div>
  </main>

  <!-- Controls -->
  <div class="fixed bottom-0 left-0 right-0 z-20">
    <PlayerControls bind:isPlaying progress={72} />
  </div>

  <!-- Settings Modal -->
  <SettingsWheel isOpen={showSettings} on:close={() => showSettings = false} />
</div>
