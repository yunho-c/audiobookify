<script lang="ts">
    import { T, useThrelte, useTask } from "@threlte/core";
    import * as THREE from "three";
    import Book from "./Book.svelte";
    import Shelf from "./Shelf.svelte";
    import Lights from "./Lights.svelte";
    import { BOOKS } from "./types";

    interface Props {
        activeBookId: number | null;
        onSelectBook: (id: number) => void;
    }

    let { activeBookId, onSelectBook }: Props = $props();

    const { camera } = useThrelte();

    let mouseX = 0;
    let mouseY = 0;

    // Track mouse position for parallax
    if (typeof window !== "undefined") {
        window.addEventListener("mousemove", (e) => {
            mouseX = (e.clientX / window.innerWidth) * 2 - 1;
            mouseY = (e.clientY / window.innerHeight) * 2 - 1;
        });
    }

    const targetCameraPos = new THREE.Vector3();

    useTask(() => {
        if (!$camera) return;

        if (!activeBookId) {
            // Parallax effect when browsing
            targetCameraPos.set(mouseX * 0.5, mouseY * 0.2 + 1, 6);
            $camera.lookAt(0, 0, 0);
        } else {
            // Fixed position when reading
            targetCameraPos.set(0, 0.5, 6.5);
            $camera.lookAt(0, 0.5, 0);
        }

        $camera.position.lerp(targetCameraPos, 0.05);
    });
</script>

<T.PerspectiveCamera makeDefault position={[0, 1, 6]} fov={45} />
<T.Fog args={["#111", 5, 15]} attach="fog" />

<Lights />

<T.Group position={[0, -0.5, 0]}>
    {#each BOOKS as book, i (book.id)}
        <Book
            data={book}
            index={i}
            totalBooks={BOOKS.length}
            {activeBookId}
            onSelect={onSelectBook}
        />
    {/each}
    <Shelf />
</T.Group>
