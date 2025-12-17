<script lang="ts">
    import { Canvas } from "@threlte/core";
    import Scene from "$lib/components/Scene.svelte";
    import HeaderUI from "$lib/components/HeaderUI.svelte";
    import PlayerUI from "$lib/components/PlayerUI.svelte";
    import { BOOKS } from "$lib/components/types";
    import "../app.css";

    let activeBookId: number | null = $state(null);

    const activeBook = $derived(
        BOOKS.find((b) => b.id === activeBookId) || null,
    );

    function handleSelectBook(id: number) {
        activeBookId = id;
    }

    function handleClosePlayer() {
        activeBookId = null;
    }
</script>

<svelte:head>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link
        rel="preconnect"
        href="https://fonts.gstatic.com"
        crossorigin="anonymous"
    />
    <link
        href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&family=Playfair+Display:wght@400;500;600&family=JetBrains+Mono:wght@400&display=swap"
        rel="stylesheet"
    />
</svelte:head>

<div
    class="w-full h-screen bg-[#111] relative overflow-hidden font-sans selection:bg-white/30"
>
    <!-- 3D Scene -->
    <Canvas shadows>
        <Scene {activeBookId} onSelectBook={handleSelectBook} />
    </Canvas>

    <!-- 2D UI Layers -->
    <HeaderUI {activeBookId} />

    <PlayerUI book={activeBook} onClose={handleClosePlayer} />

    <!-- Vignette Overlay -->
    <div class="absolute inset-0 pointer-events-none vignette" />
</div>
