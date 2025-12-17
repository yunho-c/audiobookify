<script lang="ts">
    import {
        Play,
        Pause,
        SkipBack,
        SkipForward,
        X,
        Volume2,
        Bookmark,
        Clock,
        Star,
    } from "lucide-svelte";
    import type { BookData } from "./types";

    interface Props {
        book: BookData | null;
        onClose: () => void;
    }

    let { book, onClose }: Props = $props();

    let playing = $state(false);
    let progress = $state(35);
</script>

{#if book}
    <div
        class="absolute inset-0 flex items-center justify-center pointer-events-none z-50"
    >
        <div class="w-full max-w-md p-8 pointer-events-auto animate-in">
            <!-- Glassmorphism Card -->
            <div class="glass-card rounded-3xl p-6 shadow-2xl text-white">
                <!-- Header -->
                <div class="flex justify-between items-start mb-8">
                    <button
                        onclick={onClose}
                        class="p-2 hover:bg-white/10 rounded-full transition-colors cursor-pointer"
                    >
                        <X class="w-5 h-5 text-white/70" />
                    </button>
                    <div class="flex gap-2">
                        <Bookmark
                            class="w-5 h-5 text-white/70 hover:text-white cursor-pointer"
                        />
                        <Star class="w-5 h-5 text-yellow-400 fill-yellow-400" />
                    </div>
                </div>

                <!-- Title Area -->
                <div class="text-center mb-8 space-y-2">
                    <h2 class="text-3xl font-serif tracking-wide">
                        {book.title}
                    </h2>
                    <p
                        class="text-white/60 font-medium tracking-widest text-xs uppercase"
                    >
                        {book.author}
                    </p>
                </div>

                <!-- Progress Viz -->
                <div class="mb-8">
                    <div
                        class="flex justify-between text-xs text-white/40 mb-2 font-mono"
                    >
                        <span>04:12:30</span>
                        <span>-{Math.floor(book.duration - 4)}:00:00</span>
                    </div>
                    <div
                        class="h-1.5 bg-white/10 rounded-full overflow-hidden cursor-pointer group"
                    >
                        <div
                            class="h-full bg-white rounded-full relative"
                            style="width: {progress}%"
                        >
                            <div
                                class="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 bg-white rounded-full opacity-0 group-hover:opacity-100 shadow-[0_0_10px_rgba(255,255,255,0.5)] transition-opacity"
                            />
                        </div>
                    </div>
                </div>

                <!-- Controls -->
                <div class="flex items-center justify-between mb-8">
                    <SkipBack
                        class="w-6 h-6 text-white/50 hover:text-white cursor-pointer transition-colors"
                    />
                    <button
                        onclick={() => (playing = !playing)}
                        class="w-16 h-16 bg-white text-black rounded-full flex items-center justify-center hover:scale-105 transition-transform active:scale-95 shadow-[0_0_20px_rgba(255,255,255,0.2)] cursor-pointer"
                    >
                        {#if playing}
                            <Pause class="w-6 h-6 fill-black" />
                        {:else}
                            <Play class="w-6 h-6 fill-black ml-1" />
                        {/if}
                    </button>
                    <SkipForward
                        class="w-6 h-6 text-white/50 hover:text-white cursor-pointer transition-colors"
                    />
                </div>

                <!-- Footer Metadata -->
                <div
                    class="flex justify-between items-center text-xs text-white/30 font-mono border-t border-white/5 pt-4"
                >
                    <div class="flex items-center gap-1">
                        <Clock class="w-3 h-3" />
                        <span>{book.duration} HRS</span>
                    </div>
                    <div class="flex items-center gap-1">
                        <Volume2 class="w-3 h-3" />
                        <span>CHAPTER 4</span>
                    </div>
                </div>
            </div>

            <!-- Blurb Card -->
            <div
                class="mt-4 p-6 glass-card-light rounded-2xl text-white/80 text-sm leading-relaxed font-light shadow-xl"
            >
                <p>"{book.description}"</p>
            </div>
        </div>
    </div>
{/if}
