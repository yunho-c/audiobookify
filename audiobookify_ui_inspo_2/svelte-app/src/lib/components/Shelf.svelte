<script lang="ts">
    import { T } from "@threlte/core";
</script>

<T.Group position={[0, -0.65, 0]}>
    <!-- Wood plank -->
    <T.Mesh receiveShadow>
        <T.BoxGeometry args={[10, 0.1, 3]} />
        <T.MeshStandardMaterial color="#5d4037" roughness={0.8} />
    </T.Mesh>

    <!-- Back wall -->
    <T.Mesh position={[0, 2, -1.5]}>
        <T.PlaneGeometry args={[20, 10]} />
        <T.MeshStandardMaterial color="#1a1a1a" />
    </T.Mesh>
</T.Group>
