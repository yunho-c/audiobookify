<script lang="ts">
  import BookCard from '$lib/components/BookCard.svelte';

  const books = [
    { id: '1', title: 'Adventures of Robinson Crusoe', author: 'Daniel Defoe', color: 'bg-emerald-700', progress: 45 },
    { id: '2', title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', color: 'bg-indigo-700', progress: 0 },
    { id: '3', title: 'Moby Dick', author: 'Herman Melville', color: 'bg-slate-700', progress: 12 },
    { id: '4', title: 'Pride and Prejudice', author: 'Jane Austen', color: 'bg-rose-700', progress: 0 },
    { id: '5', title: '1984', author: 'George Orwell', color: 'bg-amber-800', progress: 88 },
    { id: '6', title: 'To Kill a Mockingbird', author: 'Harper Lee', color: 'bg-sky-700', progress: 0 },
  ];
</script>

<div class="p-6 pt-12">
  <header class="mb-8">
    <h1 class="text-3xl font-serif font-bold text-stone-800 tracking-tight">Audiobookify</h1>
    <p class="text-stone-500 mt-1">Continue listening</p>
  </header>

  <section class="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
    {#each books as book}
      <BookCard {...book} />
    {/each}
    
    <!-- Add New Placeholder -->
    <a href="/create" class="aspect-[2/3] rounded-xl border-2 border-dashed border-stone-300 flex flex-col items-center justify-center text-stone-400 hover:border-orange-400 hover:text-orange-500 transition-colors group">
      <div class="w-12 h-12 rounded-full bg-stone-100 group-hover:bg-orange-50 flex items-center justify-center mb-2 transition-colors">
        <span class="text-2xl font-light">+</span>
      </div>
      <span class="text-sm font-medium">Add Book</span>
    </a>
  </section>
</div>
