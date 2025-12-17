<script lang="ts">
  import { Upload, Mic, FileText, ArrowRight } from 'lucide-svelte';
</script>

<div class="p-6 pt-12 min-h-screen bg-stone-50">
  <header class="mb-12 text-center">
    <h1 class="text-3xl font-serif font-bold text-stone-800 mb-2">Create Audiobook</h1>
    <p class="text-stone-500">Turn your text into lifelike speech</p>
  </header>

  <div class="max-w-md mx-auto space-y-6">
    <!-- Main Action Card -->
    <button class="w-full aspect-square rounded-3xl bg-white border-2 border-dashed border-stone-200 hover:border-orange-400 hover:bg-orange-50/50 transition-all group relative flex flex-col items-center justify-center p-8 shadow-sm hover:shadow-md">
      <div class="w-20 h-20 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
        <Upload size={32} />
      </div>
      <h3 class="text-xl font-bold text-stone-800 mb-2">Upload Text</h3>
      <p class="text-stone-500 text-center text-sm">Drag & drop PDF, EPUB, or TXT files here</p>
    </button>

    <!-- Options -->
    <div class="grid grid-cols-2 gap-4">
      <button class="p-6 rounded-2xl bg-white shadow-sm hover:shadow-md transition-all text-left group">
        <div class="w-10 h-10 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
          <FileText size={20} />
        </div>
        <span class="font-bold text-stone-700 block">Paste Text</span>
      </button>

      <button class="p-6 rounded-2xl bg-white shadow-sm hover:shadow-md transition-all text-left group">
        <div class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
          <Mic size={20} />
        </div>
        <span class="font-bold text-stone-700 block">Record Voice</span>
      </button>
    </div>

    <!-- Recent Drafts -->
    <div class="mt-8">
      <h3 class="font-bold text-stone-800 mb-4 ml-1">Recent Drafts</h3>
      <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
        <div class="p-4 border-b border-stone-100 flex items-center justify-between hover:bg-stone-50 transition-colors cursor-pointer">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-lg bg-stone-100 flex items-center justify-center text-stone-400">
              <FileText size={18} />
            </div>
            <div>
              <div class="font-medium text-stone-800">My Biography</div>
              <div class="text-xs text-stone-400">Edited 2h ago</div>
            </div>
          </div>
          <ArrowRight size={18} class="text-stone-300" />
        </div>
      </div>
    </div>
  </div>
</div>
