<script lang="ts">
    interface Props {
        activeBookId: number | null;
    }

    let { activeBookId }: Props = $props();
</script>

<div
    class="absolute top-0 left-0 w-full p-8 flex justify-between items-start pointer-events-none transition-opacity duration-500"
    class:opacity-0={activeBookId !== null}
    class:opacity-100={activeBookId === null}
>
    <div>
        <h1 class="text-4xl font-serif text-white tracking-tight">Library</h1>
        <p
            class="text-white/40 text-sm mt-1 font-light tracking-widest uppercase"
        >
            8 Books • 120 Hours Left
        </p>
    </div>
    <div class="pointer-events-auto">
        <button
            class="w-10 h-10 rounded-full border border-white/20 flex items-center justify-center text-white/60 hover:bg-white/10 hover:text-white transition-all cursor-pointer"
        >
            <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
            >
                <circle cx="11" cy="11" r="8"></circle>
                <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            </svg>
        </button>
    </div>
</div>
