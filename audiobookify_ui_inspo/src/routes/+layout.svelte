<script>
  import '../app.css';
  import BottomNav from '$lib/components/BottomNav.svelte';
</script>

<div class="min-h-screen bg-stone-50 text-stone-900 font-sans selection:bg-orange-200">
  <main class="pb-28 min-h-screen">
    <slot />
  </main>
  
  <BottomNav />
</div>
